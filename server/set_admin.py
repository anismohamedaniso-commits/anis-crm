#!/usr/bin/env python3
"""Set admin role on existing user and verify setup.

Requires these env vars (loaded from server/.env via dotenv or exported):
  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_EMAIL, ADMIN_PASSWORD
"""
import os, sys
from pathlib import Path
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / '.env')
except ImportError:
    pass  # dotenv not installed — rely on env vars being set

from supabase import create_client

URL = os.environ.get('SUPABASE_URL', '')
KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
EMAIL = os.environ.get('ADMIN_EMAIL', 'anis@tickandtalk.com')
PASSWORD = os.environ.get('ADMIN_PASSWORD', '')

if not URL or not KEY or not PASSWORD:
    print('ERROR: Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and ADMIN_PASSWORD in server/.env')
    sys.exit(1)

client = create_client(URL, KEY)

# List users to find the target
users = client.auth.admin.list_users()
target = None
for u in users:
    if u.email == EMAIL:
        target = u
        break

if not target:
    print(f"User {EMAIL} not found — creating...")
    res = client.auth.admin.create_user({
        "email": EMAIL,
        "password": PASSWORD,
        "email_confirm": True,
        "user_metadata": {"name": "Anis Arafa", "role": "account_executive"},
    })
    print(f"Created: {res.user.id}")
else:
    uid = str(target.id)
    meta = getattr(target, 'user_metadata', {}) or {}
    print(f"Found user {EMAIL} (id={uid})")
    print(f"  Current metadata: {meta}")
    
    # Update metadata to set role=account_executive and name
    client.auth.admin.update_user_by_id(uid, {
        "user_metadata": {"name": "Anis Arafa", "role": "account_executive"},
        "password": PASSWORD,
    })
    
    # Verify
    updated = client.auth.admin.get_user_by_id(uid)
    new_meta = getattr(updated.user, 'user_metadata', {}) or {}
    print(f"  Updated metadata: {new_meta}")
    print(f"  Password updated.")

print("\nDone! You can now log in with:")
print(f"  Email:    {EMAIL}")
print(f"  Password: (value from ADMIN_PASSWORD env var)")
