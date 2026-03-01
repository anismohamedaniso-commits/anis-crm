#!/usr/bin/env python3
"""Restore leads from the most recent CSV export with correct status mapping."""
import csv, json, uuid
from datetime import datetime
from pathlib import Path
from collections import Counter

CSV_PATH = "/Users/anisarafa/Downloads/leads_export_1772034268808.csv"
DATA_DIR = Path(__file__).parent / "data"
LEADS_FILE = DATA_DIR / "leads.json"
BACKUP_FILE = DATA_DIR / "leads.backup.json"

# Map CSV status values to what the Flutter app expects (camelCase)
STATUS_MAP = {
    "fresh": "fresh",
    "interested": "interested",
    "no answer": "noAnswer",
    "follow up": "followUp",
    "not interested": "notInterested",
    "converted": "converted",
    "closed": "closed",
    "new": "fresh",
}

leads = []
with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        raw_status = row.get("Status", "Fresh").strip().lower()
        status = STATUS_MAP.get(raw_status, "fresh")
        source = row.get("Source", "").strip().lower() or "imported"

        lead = {
            "id": str(uuid.uuid4()),
            "name": row.get("Name", "").strip(),
            "phone": row.get("Phone", "").strip(),
            "email": row.get("Email", "").strip(),
            "status": status,
            "source": source,
            "campaign": row.get("Campaign", "").strip(),
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
        }
        created = row.get("Created", "").strip()
        if created:
            try:
                dt = datetime.strptime(created, "%m/%d/%Y %I:%M%p")
                lead["created_at"] = dt.isoformat()
            except Exception:
                pass
        last_contacted = row.get("Last Contacted", "").strip()
        if last_contacted:
            try:
                dt = datetime.strptime(last_contacted, "%m/%d/%Y %I:%M%p")
                lead["last_contacted"] = dt.isoformat()
                lead["updated_at"] = dt.isoformat()
            except Exception:
                pass
        leads.append(lead)

LEADS_FILE.write_text(json.dumps(leads, indent=2))
BACKUP_FILE.write_text(json.dumps(leads, indent=2))

statuses = Counter(l["status"] for l in leads)
print(f"Restored {len(leads)} leads")
print(f"Status breakdown: {dict(statuses)}")
print(f"First: {leads[0]['name']}")
print(f"Last:  {leads[-1]['name']}")
