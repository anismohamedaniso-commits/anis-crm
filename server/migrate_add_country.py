#!/usr/bin/env python3
"""Migration: Add 'country' column to leads table, default to 'egypt'."""
import os
import sys

def main():
    url = os.environ.get('SUPABASE_URL', '')
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')

    # Try loading from .env files
    if not key or not url:
        for f in ['.env', '../.env']:
            if os.path.exists(f):
                for line in open(f):
                    line = line.strip()
                    if line.startswith('#') or '=' not in line:
                        continue
                    k, v = line.split('=', 1)
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    if k == 'SUPABASE_SERVICE_ROLE_KEY' and v and 'dummy' not in v:
                        key = v
                    if k == 'SUPABASE_URL' and v and 'dummy' not in v:
                        url = v

    print(f'URL: {url}')
    print(f'Key length: {len(key)}')

    if not key or not url:
        print('ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not found')
        sys.exit(1)

    from supabase import create_client
    sb = create_client(url, key)

    # Step 1: Check if column exists by trying to select it
    try:
        test = sb.table('leads').select('id,country').limit(1).execute()
        print(f'Column "country" already exists. Sample: {test.data}')
        # Check if any leads are missing the country value
        all_leads = sb.table('leads').select('id,country').execute()
        missing = [l for l in all_leads.data if not l.get('country')]
        if missing:
            print(f'Found {len(missing)} leads without country, setting to "egypt"...')
            for lead in missing:
                sb.table('leads').update({'country': 'egypt'}).eq('id', lead['id']).execute()
            print(f'Updated {len(missing)} leads to country=egypt')
        else:
            print('All leads already have a country value')
    except Exception as e:
        err_str = str(e)
        if 'column' in err_str.lower() or '42703' in err_str:
            print('Column "country" does not exist yet. Adding it...')
            # Use SQL via RPC to add column
            sql = "ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT 'egypt';"
            try:
                sb.rpc('exec_sql', {'query': sql}).execute()
                print('Column added via RPC')
            except Exception as rpc_err:
                print(f'RPC exec_sql not available: {rpc_err}')
                print('Please run this SQL manually in Supabase SQL Editor:')
                print(sql)
                print()
                print("Then run: UPDATE public.leads SET country = 'egypt' WHERE country IS NULL;")
        else:
            print(f'Unexpected error: {e}')

    # Verify
    try:
        count = sb.table('leads').select('id', count='exact').execute()
        egypt = sb.table('leads').select('id', count='exact').eq('country', 'egypt').execute()
        print(f'\nTotal leads: {count.count}')
        print(f'Egypt leads: {egypt.count}')
        sa = sb.table('leads').select('id', count='exact').eq('country', 'saudi_arabia').execute()
        print(f'Saudi leads: {sa.count}')
    except Exception as e:
        print(f'Verify step failed: {e}')

if __name__ == '__main__':
    main()
