#!/usr/bin/env bash
# Anis CRM — Full Regression Test (v5 — correct endpoints)
set -euo pipefail

BASE="https://anis-crm-api-production.up.railway.app"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNocWVqZHNnZXZidnNhcWllanBzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MDM0OTMsImV4cCI6MjA4NjE3OTQ5M30.AOWRsIqwIDOYN29wHy1Lh_vXp5p5Dvt7TLq6Lfj-kWc"
SUPABASE="https://chqejdsgevbvsaqiejps.supabase.co"

PASS=0; FAIL=0; TOTAL=0
ok()   { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1 — $2"; }

RESP_CODE=0; RESP_BODY=""
parse() {
  local raw="$1"
  RESP_BODY="${raw%???}"
  RESP_CODE="${raw: -3}"
}
aapi() {
  local method="$1"; shift
  local url="$1"; shift
  curl -s -w "%{http_code}" --max-time 15 -X "$method" "$url" \
    -H "Authorization: Bearer $TOKEN" "$@"
}

echo ""
echo "=== STEP 1: LOGIN ==="
LOGIN_RESP=$(curl -s --max-time 15 -X POST \
  "$SUPABASE/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON" \
  -H "Content-Type: application/json" \
  -d '{"email":"testexec@tickandtalk.com","password":"TestExec2026!"}')

TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
if [ -n "$TOKEN" ] && [ ${#TOKEN} -gt 100 ]; then
  ok "Login -> token ${#TOKEN} chars"
else
  fail "Login" "no token"
  echo "FATAL: Cannot continue"; exit 1
fi

echo ""
echo "=== STEP 2: HEALTH CHECK ==="
parse "$(aapi GET "$BASE/api/health")"
[ "$RESP_CODE" = "200" ] && ok "Health -> 200" || fail "Health" "$RESP_CODE"

echo ""
echo "=== STEP 3: LEADS CRUD ==="
parse "$(aapi GET "$BASE/api/leads?limit=1")"
LEAD_COUNT=$(echo "$RESP_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "0")
[ "$RESP_CODE" = "200" ] && ok "GET leads -> 200 (total: $LEAD_COUNT)" || fail "GET leads" "$RESP_CODE"

# Create
LEAD_UUID="lead_test_$(python3 -c 'import uuid; print(uuid.uuid4().hex[:8])')"
LEAD_JSON="{\"id\":\"$LEAD_UUID\",\"name\":\"Test Lead\",\"email\":\"test@example.com\",\"phone\":\"+971501234567\",\"status\":\"new\",\"source\":\"api-test\"}"
parse "$(aapi POST "$BASE/api/leads" -H "Content-Type: application/json" -d "$LEAD_JSON")"
([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]) && ok "Create lead -> $RESP_CODE" || fail "Create lead" "$RESP_CODE: $RESP_BODY"
LEAD_ID="$LEAD_UUID"

# Read single
parse "$(aapi GET "$BASE/api/leads/$LEAD_ID")"
[ "$RESP_CODE" = "200" ] && ok "Get single lead -> 200" || fail "Get lead" "$RESP_CODE"

# Update status
parse "$(aapi PUT "$BASE/api/leads/$LEAD_ID" -H "Content-Type: application/json" -d '{"status":"interested"}')"
[ "$RESP_CODE" = "200" ] && ok "Update status -> 200" || fail "Update status" "$RESP_CODE"

# Set follow-up
parse "$(aapi PUT "$BASE/api/leads/$LEAD_ID" -H "Content-Type: application/json" -d '{"next_followup_at":"2026-04-01"}')"
[ "$RESP_CODE" = "200" ] && ok "Set follow-up -> 200" || fail "Set follow-up" "$RESP_CODE"

# Assign lead
parse "$(aapi PUT "$BASE/api/leads/$LEAD_ID" -H "Content-Type: application/json" -d '{"assigned_to":"44ec3f7d-1789-48de-a00d-a88b9be94eb0","assigned_to_name":"Test Exec"}')"
[ "$RESP_CODE" = "200" ] && ok "Assign lead -> 200" || fail "Assign lead" "$RESP_CODE"

# Convert to deal (update status + create deal)
parse "$(aapi PUT "$BASE/api/leads/$LEAD_ID" -H "Content-Type: application/json" -d '{"status":"converted"}')"
[ "$RESP_CODE" = "200" ] && ok "Convert lead status -> 200" || fail "Convert lead" "$RESP_CODE"

DEAL_JSON="{\"lead_id\":\"$LEAD_ID\",\"title\":\"Test Deal\",\"value\":5000,\"stage\":\"proposal\",\"contact_name\":\"Test Lead\",\"contact_email\":\"test@example.com\"}"
parse "$(aapi POST "$BASE/api/deals" -H "Content-Type: application/json" -d "$DEAL_JSON")"
([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]) && ok "Create deal -> $RESP_CODE" || fail "Create deal" "$RESP_CODE: $RESP_BODY"
DEAL_ID=$(echo "$RESP_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

echo ""
echo "=== STEP 4: PAGINATION & SEARCH ==="
parse "$(aapi GET "$BASE/api/leads?limit=5&offset=0")"
[ "$RESP_CODE" = "200" ] && ok "Pagination p1 -> 200" || fail "Pagination p1" "$RESP_CODE"

parse "$(aapi GET "$BASE/api/leads?limit=5&offset=5")"
[ "$RESP_CODE" = "200" ] && ok "Pagination p2 -> 200" || fail "Pagination p2" "$RESP_CODE"

parse "$(aapi GET "$BASE/api/leads?q=test")"
[ "$RESP_CODE" = "200" ] && ok "Global search -> 200" || fail "Search" "$RESP_CODE"

echo ""
echo "=== STEP 5: TASKS (JWT-protected) ==="
parse "$(aapi GET "$BASE/api/tasks")"
[ "$RESP_CODE" = "200" ] && ok "GET tasks -> 200" || fail "GET tasks" "$RESP_CODE"

TASK_JSON="{\"lead_id\":\"$LEAD_ID\",\"title\":\"Follow up with test lead\",\"due_date\":\"2026-03-01\",\"priority\":\"high\"}"
parse "$(aapi POST "$BASE/api/tasks" -H "Content-Type: application/json" -d "$TASK_JSON")"
([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]) && ok "Create task -> $RESP_CODE" || fail "Create task" "$RESP_CODE: $RESP_BODY"

echo ""
echo "=== STEP 6: DEALS ==="
parse "$(aapi GET "$BASE/api/deals")"
[ "$RESP_CODE" = "200" ] && ok "GET deals -> 200" || fail "GET deals" "$RESP_CODE"

# Deal forecast
parse "$(aapi GET "$BASE/api/deals/forecast")"
[ "$RESP_CODE" = "200" ] && ok "Deals forecast -> 200" || fail "Deals forecast" "$RESP_CODE"

echo ""
echo "=== STEP 7: ACTIVITIES ==="
parse "$(aapi GET "$BASE/api/activities")"
[ "$RESP_CODE" = "200" ] && ok "GET activities -> 200" || fail "GET activities" "$RESP_CODE"

ACT_JSON="{\"lead_id\":\"$LEAD_ID\",\"type\":\"call\",\"notes\":\"Discussed pricing options\"}"
parse "$(aapi POST "$BASE/api/activities" -H "Content-Type: application/json" -d "$ACT_JSON")"
([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "201" ]) && ok "Log activity -> $RESP_CODE" || fail "Log activity" "$RESP_CODE: $RESP_BODY"

echo ""
echo "=== STEP 8: NOTIFICATIONS (JWT-protected) ==="
parse "$(aapi GET "$BASE/api/notifications")"
[ "$RESP_CODE" = "200" ] && ok "Notifications -> 200" || fail "Notifications" "$RESP_CODE"

echo ""
echo "=== STEP 9: LEADERBOARD (JWT-protected) ==="
parse "$(aapi GET "$BASE/api/leaderboard")"
[ "$RESP_CODE" = "200" ] && ok "Leaderboard -> 200" || fail "Leaderboard" "$RESP_CODE"

echo ""
echo "=== STEP 10: USER MANAGEMENT (JWT-protected) ==="
parse "$(aapi GET "$BASE/api/auth/users")"
[ "$RESP_CODE" = "200" ] && ok "GET users -> 200" || fail "GET users" "$RESP_CODE"

echo ""
echo "=== STEP 11: CHAT CHANNELS (JWT-protected) ==="
parse "$(aapi GET "$BASE/api/chat/channels")"
[ "$RESP_CODE" = "200" ] && ok "Chat channels -> 200" || fail "Chat channels" "$RESP_CODE"

echo ""
echo "=== STEP 12: EMAIL & INTEGRATIONS ==="
parse "$(aapi GET "$BASE/api/email/config")"
[ "$RESP_CODE" = "200" ] && ok "Email config -> 200" || fail "Email config" "$RESP_CODE"

parse "$(aapi GET "$BASE/api/integrations/config")"
[ "$RESP_CODE" = "200" ] && ok "Integrations config -> 200" || fail "Integrations config" "$RESP_CODE"

parse "$(aapi GET "$BASE/api/integrations/status")"
[ "$RESP_CODE" = "200" ] && ok "Integrations status -> 200" || fail "Integrations status" "$RESP_CODE"

echo ""
echo "=== STEP 13: AI ENDPOINTS ==="
parse "$(aapi GET "$BASE/api/ai/models")"
[ "$RESP_CODE" = "200" ] && ok "AI models -> 200" || fail "AI models" "$RESP_CODE"

AI_JSON='{"message":"What are my top leads?","model":"gpt-4o-mini"}'
parse "$(aapi POST "$BASE/api/ai/chat" -H "Content-Type: application/json" -d "$AI_JSON")"
([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "503" ]) && ok "AI chat -> $RESP_CODE (expected)" || fail "AI chat" "$RESP_CODE"

echo ""
echo "=== STEP 14: BULK IMPORT ==="
IMPORT_JSON='{"leads":[{"name":"Import Test","email":"import@test.com","phone":"+971500000000","status":"new","source":"bulk-test"}]}'
parse "$(aapi POST "$BASE/api/leads/import" -H "Content-Type: application/json" -d "$IMPORT_JSON")"
[ "$RESP_CODE" = "200" ] && ok "Bulk import -> 200" || fail "Bulk import" "$RESP_CODE: $RESP_BODY"

echo ""
echo "=== STEP 15: WEBHOOKS ==="
parse "$(aapi GET "$BASE/api/webhooks")"
[ "$RESP_CODE" = "200" ] && ok "Webhooks -> 200" || fail "Webhooks" "$RESP_CODE"

echo ""
echo "=== STEP 16: CUSTOM FIELDS ==="
parse "$(aapi GET "$BASE/api/custom-fields")"
[ "$RESP_CODE" = "200" ] && ok "Custom fields -> 200" || fail "Custom fields" "$RESP_CODE"

echo ""
echo "=== STEP 17: ERROR HANDLING ==="
parse "$(aapi GET "$BASE/api/leads/nonexistent-lead-xyz")"
[ "$RESP_CODE" = "404" ] && ok "Non-existent lead -> 404" || fail "404 check" "$RESP_CODE"

NOAUTH=$(curl -s -w "%{http_code}" --max-time 10 -X GET "$BASE/api/tasks")
NOAUTH_CODE="${NOAUTH: -3}"
[ "$NOAUTH_CODE" = "401" ] && ok "No auth -> 401" || fail "No auth check" "$NOAUTH_CODE"

echo ""
echo "=== STEP 18: CLEANUP ==="
# Delete test lead
parse "$(aapi DELETE "$BASE/api/leads/$LEAD_ID")"
([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "204" ]) && ok "Delete test lead -> $RESP_CODE" || fail "Delete test lead" "$RESP_CODE"

# Delete deal
if [ -n "$DEAL_ID" ]; then
  parse "$(aapi DELETE "$BASE/api/deals/$DEAL_ID")"
  ([ "$RESP_CODE" = "200" ] || [ "$RESP_CODE" = "204" ]) && ok "Delete test deal -> $RESP_CODE" || fail "Delete test deal" "$RESP_CODE"
fi

# Delete imported lead
parse "$(aapi POST "$BASE/api/leads/bulk-delete" -H "Content-Type: application/json" -d '{"ids":["lead_test_bulk_001"]}')"
[ "$RESP_CODE" = "200" ] && ok "Bulk delete stale -> 200" || fail "Bulk delete" "$RESP_CODE"

# Find and delete the import test lead
IMPORT_LEADS=$(curl -s "$BASE/api/leads?q=import@test.com&limit=5" -H "Authorization: Bearer $TOKEN")
IMPORT_IDS=$(echo "$IMPORT_LEADS" | python3 -c "
import sys,json
data=json.load(sys.stdin)
ids=[l['id'] for l in data.get('leads',[]) if l.get('email')=='import@test.com']
print(json.dumps(ids))
" 2>/dev/null || echo "[]")
if [ "$IMPORT_IDS" != "[]" ]; then
  parse "$(aapi POST "$BASE/api/leads/bulk-delete" -H "Content-Type: application/json" -d "{\"ids\":$IMPORT_IDS}")"
  ([ "$RESP_CODE" = "200" ]) && ok "Cleanup imported lead -> 200" || fail "Cleanup import" "$RESP_CODE"
fi

# Verify lead count
parse "$(aapi GET "$BASE/api/leads?limit=1")"
FINAL_COUNT=$(echo "$RESP_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "?")
echo "    Final lead count: $FINAL_COUNT (should be $LEAD_COUNT)"
[ "$FINAL_COUNT" = "$LEAD_COUNT" ] && ok "Lead count unchanged ($FINAL_COUNT)" || fail "Lead count" "was $LEAD_COUNT, now $FINAL_COUNT"

echo ""
echo "============================================================"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ] && echo "  ALL TESTS PASSED!" || echo "  $FAIL test(s) need attention"
