#!/bin/bash
# ─────────────────────────────────────────────
#  Anis CRM — Start without VS Code
#  Usage: ./start.sh
#  Opens: http://localhost:8000
# ─────────────────────────────────────────────

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="$HOME/flutter/bin/flutter"
VENV="$DIR/server/.venv/bin/activate"

SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNocWVqZHNnZXZidnNhcWllanBzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MDM0OTMsImV4cCI6MjA4NjE3OTQ5M30.AOWRsIqwIDOYN29wHy1Lh_vXp5p5Dvt7TLq6Lfj-kWc"
API_URL="http://localhost:8000"

echo "======================================"
echo "  Anis CRM Launcher"
echo "======================================"

# Kill anything on port 8000
lsof -ti:8000 | xargs kill -9 2>/dev/null || true

# 1. Build Flutter web (only rebuilds if needed)
echo ""
echo "▶ Building Flutter web..."
cd "$DIR"
export PATH="$PATH:$HOME/flutter/bin"
"$FLUTTER" build web \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_KEY" \
  --dart-define=API_BASE_URL="$API_URL" \
  --release
echo "✓ Flutter build complete"

# 2. Start FastAPI server detached (survives terminal/VS Code closing)
echo ""
echo "▶ Starting server on http://localhost:8000 ..."
source "$VENV"
cd "$DIR/server"
nohup uvicorn main:app --host 0.0.0.0 --port 8000 > "$DIR/server/logs/server.log" 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > "$DIR/server/server.pid"

# 3. Wait for server to be ready
echo "  Waiting for server..."
for i in $(seq 1 10); do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 | grep -q "200"; then
    break
  fi
  sleep 1
done
echo "✓ Server running (PID $SERVER_PID) — logs: server/logs/server.log"

# 4. Open in Safari
echo ""
echo "▶ Opening in Safari..."
open -a Safari http://localhost:8000

echo ""
echo "======================================"
echo "  App running at http://localhost:8000"
echo "  Server stays running after this window closes."
echo "  To stop: kill \$(cat server/server.pid)"
echo "======================================"
