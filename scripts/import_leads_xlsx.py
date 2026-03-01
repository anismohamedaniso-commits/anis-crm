#!/usr/bin/env python3
"""Import tick_talk_leads_20260228-2.xlsx into Supabase (or local DB)."""

import openpyxl
import json
import uuid
import os
import sys
import httpx
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

# ── Config ────────────────────────────────────────────────────────────────────
XLSX_PATH = Path.home() / "Downloads" / "tick_talk_leads_20260228-2.xlsx"
ENV_PATH  = Path(__file__).parent.parent / "server" / ".env"
load_dotenv(ENV_PATH)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SERVICE_KEY  = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

STATUS_MAP = {
    "Fresh":         "fresh",
    "Interested":    "interested",
    "Converted":     "converted",
    "Not Interested":"not_interested",
    "Lost":          "lost",
    "Follow Up":     "follow_up",
    "Follow-Up":     "follow_up",
}

# ── Parse Excel ───────────────────────────────────────────────────────────────
wb = openpyxl.load_workbook(XLSX_PATH)
ws = wb["All Leads"]

leads = []
for row in ws.iter_rows(min_row=2, values_only=True):
    num, name, status, source, campaign, phone, email, deal_val, assigned, created, last_contacted, next_followup = row
    if not name:
        continue

    # Clean phone — remove RTL marks and narrow no-break spaces
    clean_phone = None
    if phone:
        clean_phone = str(phone).replace("\u202a", "").replace("\u202c", "").replace("\xa0", "").strip()
        if not clean_phone:
            clean_phone = None

    # created_at must be a date string
    if created:
        created_str = str(created)[:10]  # take YYYY-MM-DD
    else:
        created_str = datetime.utcnow().strftime("%Y-%m-%d")

    # last_contacted and next_followup
    last_contacted_str = str(last_contacted)[:10] if last_contacted else None
    next_followup_str  = str(next_followup)[:10]  if next_followup  else None
    now_str = datetime.utcnow().isoformat()

    lead = {
        "id":                 str(uuid.uuid4()),
        "name":               str(name).strip(),
        "status":             STATUS_MAP.get(str(status).strip(), "fresh") if status else "fresh",
        "source":             str(source).strip().lower().replace(" ", "_") if source else "imported",
        "campaign":           str(campaign).strip() if campaign else None,
        "phone":              clean_phone,
        "email":              str(email).strip() if email else None,
        "deal_value":         float(deal_val) if deal_val else 0.0,
        "assigned_to":        str(assigned).strip() if assigned else None,
        "assigned_to_name":   str(assigned).strip() if assigned else None,
        "tags":               [],
        "created_at":         created_str,
        "updated_at":         now_str,
        "last_contacted_at":  last_contacted_str,
        "next_followup_at":   next_followup_str,
    }
    leads.append(lead)

print(f"Parsed {len(leads)} leads from Excel")

# ── Import to Supabase ────────────────────────────────────────────────────────
if not SUPABASE_URL or not SERVICE_KEY:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set")
    sys.exit(1)

headers_http = {
    "apikey":        SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type":  "application/json",
    "Prefer":        "resolution=merge-duplicates,return=minimal",
}

# Supabase REST API allows max ~500 rows per request; batch in chunks of 200
BATCH = 200
imported = 0
errors   = 0

for i in range(0, len(leads), BATCH):
    batch = leads[i:i+BATCH]
    resp = httpx.post(
        f"{SUPABASE_URL}/rest/v1/leads",
        headers=headers_http,
        json=batch,
        timeout=30,
    )
    if resp.status_code in (200, 201):
        imported += len(batch)
        print(f"  Batch {i//BATCH + 1}: {len(batch)} leads inserted ✓")
    else:
        errors += len(batch)
        print(f"  Batch {i//BATCH + 1} ERROR {resp.status_code}: {resp.text[:300]}")

print(f"\nDone — imported: {imported}, errors: {errors}")
