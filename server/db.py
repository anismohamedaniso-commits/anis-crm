"""
Database abstraction layer for Anis CRM server.

Uses Supabase/Postgres when available, falls back to JSON files for dev.
Toggle storage via the USE_SUPABASE_DB env var (default: true when
SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are set).
"""
from __future__ import annotations

import json
import logging
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from supabase import Client as SupabaseClient

# ── Paths for JSON fallback ──────────────────────────────────────────────────
DATA_DIR = Path(__file__).parent / 'data'
DATA_DIR.mkdir(exist_ok=True)

LEADS_FILE = DATA_DIR / 'leads.json'
NOTES_FILE = DATA_DIR / 'notes.json'
TASKS_FILE = DATA_DIR / 'tasks.json'
TEAM_ACTIVITIES_FILE = DATA_DIR / 'team_activities.json'
NOTIFICATIONS_FILE = DATA_DIR / 'notifications.json'
CHAT_CHANNELS_FILE = DATA_DIR / 'chat_channels.json'
CHAT_MESSAGES_FILE = DATA_DIR / 'chat_messages.json'


# ── JSON helpers (legacy) ────────────────────────────────────────────────────
def _load_json(p: Path) -> list:
    try:
        if not p.exists():
            return []
        with p.open('r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return []


def _save_json(p: Path, data: Any) -> None:
    with p.open('w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def _now_iso() -> str:
    return datetime.utcnow().isoformat() + 'Z'


# ═════════════════════════════════════════════════════════════════════════════
# Database class — unified interface
# ═════════════════════════════════════════════════════════════════════════════
class CrmDatabase:
    """Unified CRM data layer. Calls Supabase when available, else JSON."""

    def __init__(self, supabase_admin: Optional[SupabaseClient] = None):
        self._sb = supabase_admin
        # Allow explicit override ("0" or "false" → disable)
        env_flag = os.environ.get('USE_SUPABASE_DB', '').lower()
        if env_flag in ('0', 'false', 'no'):
            self._use_db = False
        else:
            self._use_db = self._sb is not None
        # Auto-detect: probe Supabase to see if core tables actually exist
        if self._use_db:
            try:
                self._sb.table('leads').select('id').limit(1).execute()
                logging.info('CrmDatabase: Supabase tables verified — using Supabase/Postgres storage')
            except Exception as e:
                logging.warning(f'CrmDatabase: Supabase tables not found ({e}) — falling back to JSON files')
                self._use_db = False
        if not self._use_db:
            logging.info('CrmDatabase: using JSON file storage')

    @property
    def using_db(self) -> bool:
        return self._use_db

    # ─── HELPERS ──────────────────────────────────────────────────────────
    def _sb_select(self, table: str, filters: dict | None = None,
                   order_col: str | None = None, ascending: bool = False,
                   limit: int = 0, offset: int = 0) -> list[dict]:
        """Generic Supabase select with optional filters, ordering, pagination."""
        q = self._sb.table(table).select('*')
        if filters:
            for k, v in filters.items():
                q = q.eq(k, v)
        if order_col:
            q = q.order(order_col, desc=not ascending)
        if limit > 0:
            q = q.range(offset, offset + limit - 1)
        return q.execute().data or []

    def _sb_insert(self, table: str, row: dict) -> dict:
        return self._sb.table(table).insert(row).execute().data[0]

    def _sb_update(self, table: str, row_id: str, fields: dict) -> dict | None:
        res = self._sb.table(table).update(fields).eq('id', row_id).execute()
        return res.data[0] if res.data else None

    def _sb_delete(self, table: str, row_id: str) -> bool:
        self._sb.table(table).delete().eq('id', row_id).execute()
        return True

    # ─── LEADS ────────────────────────────────────────────────────────────
    def get_leads(self, limit: int = 0, offset: int = 0) -> list[dict]:
        if self._use_db:
            return self._sb_select('leads', order_col='created_at',
                                   limit=limit, offset=offset)
        leads = _load_json(LEADS_FILE)
        leads.sort(key=lambda l: l.get('created_at', ''), reverse=True)
        if limit > 0:
            return leads[offset:offset + limit]
        return leads

    def get_leads_count(self) -> int:
        if self._use_db:
            res = self._sb.table('leads').select('id', count='exact').execute()
            return res.count or 0
        return len(_load_json(LEADS_FILE))

    def get_lead(self, lead_id: str) -> dict | None:
        if self._use_db:
            res = self._sb.table('leads').select('*').eq('id', lead_id).execute()
            return res.data[0] if res.data else None
        leads = _load_json(LEADS_FILE)
        return next((l for l in leads if l['id'] == lead_id), None)

    def create_lead(self, lead: dict) -> dict:
        now = _now_iso()
        lead.setdefault('id', f"lead_{uuid.uuid4().hex[:8]}")
        lead.setdefault('created_at', now)
        lead.setdefault('updated_at', now)
        lead.setdefault('status', 'new')
        if self._use_db:
            # Convert tags from list if needed
            return self._sb_insert('leads', lead)
        leads = _load_json(LEADS_FILE)
        leads.insert(0, lead)
        _save_json(LEADS_FILE, leads)
        return lead

    def update_lead(self, lead_id: str, fields: dict) -> dict | None:
        fields['updated_at'] = _now_iso()
        if self._use_db:
            return self._sb_update('leads', lead_id, fields)
        leads = _load_json(LEADS_FILE)
        for l in leads:
            if l['id'] == lead_id:
                l.update(fields)
                _save_json(LEADS_FILE, leads)
                return l
        return None

    def delete_lead(self, lead_id: str) -> bool:
        if self._use_db:
            return self._sb_delete('leads', lead_id)
        leads = _load_json(LEADS_FILE)
        # Auto-backup before first delete (once per session)
        backup_path = LEADS_FILE.with_suffix('.backup.json')
        if not backup_path.exists() or len(leads) > 10:
            _save_json(backup_path, leads)
        leads = [l for l in leads if l['id'] != lead_id]
        _save_json(LEADS_FILE, leads)
        return True

    def import_leads(self, rows: list[dict]) -> int:
        count = 0
        for row in rows:
            try:
                self.create_lead(row)
                count += 1
            except Exception as e:
                logging.warning(f'Import lead failed: {e}')
        return count

    def assign_lead(self, lead_id: str, assigned_to: str,
                    assigned_to_name: str) -> dict | None:
        return self.update_lead(lead_id, {
            'assigned_to': assigned_to,
            'assigned_to_name': assigned_to_name,
        })

    # ─── ACTIVITIES / NOTES ───────────────────────────────────────────────
    def get_activities(self, lead_id: str) -> list[dict]:
        if self._use_db:
            return self._sb_select('activities', filters={'lead_id': lead_id},
                                   order_col='ts')
        notes = _load_json(NOTES_FILE)
        lead_notes = [n for n in notes if n.get('lead_id') == lead_id]
        lead_notes.sort(key=lambda n: n.get('ts', ''), reverse=True)
        return lead_notes

    def get_all_activities(self) -> dict[str, list[dict]]:
        if self._use_db:
            all_acts = self._sb_select('activities', order_col='ts')
        else:
            all_acts = _load_json(NOTES_FILE)
        grouped: dict[str, list[dict]] = {}
        for n in all_acts:
            lid = n.get('lead_id', '__none__')
            grouped.setdefault(lid, []).append(n)
        for lid in grouped:
            grouped[lid].sort(key=lambda n: n.get('ts', ''), reverse=True)
        return grouped

    def create_activity(self, activity: dict) -> dict:
        activity.setdefault('id', f"note_{uuid.uuid4().hex[:8]}")
        activity.setdefault('ts', _now_iso())
        if self._use_db:
            return self._sb_insert('activities', activity)
        notes = _load_json(NOTES_FILE)
        notes.append(activity)
        _save_json(NOTES_FILE, notes)
        return activity

    def get_team_notes(self, lead_id: str) -> list[dict]:
        if self._use_db:
            return self._sb_select('activities',
                                   filters={'lead_id': lead_id, 'type': 'team_note'},
                                   order_col='ts')
        notes = _load_json(NOTES_FILE)
        team = [n for n in notes if n.get('lead_id') == lead_id
                and n.get('type') == 'team_note']
        team.sort(key=lambda n: n.get('ts', ''), reverse=True)
        return team

    # ─── TASKS ────────────────────────────────────────────────────────────
    def get_tasks(self, assigned_to: str = '', status: str = '',
                  limit: int = 0, offset: int = 0) -> list[dict]:
        if self._use_db:
            filters = {}
            if assigned_to:
                filters['assigned_to'] = assigned_to
            if status:
                filters['status'] = status
            return self._sb_select('tasks', filters=filters,
                                   order_col='created_at',
                                   limit=limit, offset=offset)
        tasks = _load_json(TASKS_FILE)
        if assigned_to:
            tasks = [t for t in tasks if t.get('assigned_to') == assigned_to]
        if status:
            tasks = [t for t in tasks if t.get('status') == status]
        tasks.sort(key=lambda t: t.get('created_at', ''), reverse=True)
        if limit > 0:
            return tasks[offset:offset + limit]
        return tasks

    def create_task(self, task: dict) -> dict:
        now = _now_iso()
        task.setdefault('id', f"task_{uuid.uuid4().hex[:8]}")
        task.setdefault('created_at', now)
        task.setdefault('updated_at', now)
        task.setdefault('status', 'todo')
        task.setdefault('priority', 'medium')
        if self._use_db:
            return self._sb_insert('tasks', task)
        tasks = _load_json(TASKS_FILE)
        tasks.insert(0, task)
        _save_json(TASKS_FILE, tasks)
        return task

    def update_task(self, task_id: str, fields: dict) -> dict | None:
        fields['updated_at'] = _now_iso()
        if self._use_db:
            return self._sb_update('tasks', task_id, fields)
        tasks = _load_json(TASKS_FILE)
        for t in tasks:
            if t['id'] == task_id:
                old_status = t.get('status')
                t.update(fields)
                _save_json(TASKS_FILE, tasks)
                t['_old_status'] = old_status
                return t
        return None

    def delete_task(self, task_id: str) -> dict | None:
        if self._use_db:
            res = self._sb.table('tasks').select('*').eq('id', task_id).execute()
            task = res.data[0] if res.data else None
            self._sb_delete('tasks', task_id)
            return task
        tasks = _load_json(TASKS_FILE)
        task = next((t for t in tasks if t['id'] == task_id), None)
        tasks = [t for t in tasks if t['id'] != task_id]
        _save_json(TASKS_FILE, tasks)
        return task

    # ─── TEAM ACTIVITIES ──────────────────────────────────────────────────
    def post_team_activity(self, user: dict, action: str, target_type: str,
                           target_id: str = '', target_name: str = '',
                           detail: str = '') -> dict:
        entry = {
            'id': f"ta_{uuid.uuid4().hex[:10]}",
            'user_id': user.get('id', ''),
            'user_name': user.get('name', 'Unknown'),
            'action': action,
            'target_type': target_type,
            'target_id': target_id,
            'target_name': target_name,
            'detail': detail,
            'ts': _now_iso(),
        }
        if self._use_db:
            return self._sb_insert('team_activities', entry)
        activities = _load_json(TEAM_ACTIVITIES_FILE)
        activities.insert(0, entry)
        if len(activities) > 500:
            activities = activities[:500]
        _save_json(TEAM_ACTIVITIES_FILE, activities)
        return entry

    def get_team_activities(self, limit: int = 50, offset: int = 0) -> tuple[list[dict], int]:
        if self._use_db:
            count_res = self._sb.table('team_activities').select('id', count='exact').execute()
            total = count_res.count or 0
            data = self._sb_select('team_activities', order_col='ts',
                                   limit=limit, offset=offset)
            return data, total
        activities = _load_json(TEAM_ACTIVITIES_FILE)
        total = len(activities)
        return activities[offset:offset + limit], total

    # ─── NOTIFICATIONS ────────────────────────────────────────────────────
    def create_notification(self, user_id: str, notif_type: str, title: str,
                            body: str = '', action_url: str = '',
                            from_user_id: str = '',
                            from_user_name: str = '') -> dict:
        entry = {
            'id': f"n_{uuid.uuid4().hex[:10]}",
            'user_id': user_id,
            'type': notif_type,
            'title': title,
            'body': body,
            'action_url': action_url,
            'from_user_id': from_user_id or None,
            'from_user_name': from_user_name,
            'read': False,
            'ts': _now_iso(),
        }
        if self._use_db:
            return self._sb_insert('notifications', entry)
        notifs = _load_json(NOTIFICATIONS_FILE)
        notifs.insert(0, entry)
        if len(notifs) > 1000:
            notifs = notifs[:1000]
        _save_json(NOTIFICATIONS_FILE, notifs)
        return entry

    def get_notifications(self, user_id: str, limit: int = 50) -> tuple[list[dict], int]:
        if self._use_db:
            mine = self._sb_select('notifications',
                                   filters={'user_id': user_id},
                                   order_col='ts', limit=limit)
            unread_res = (self._sb.table('notifications')
                          .select('id', count='exact')
                          .eq('user_id', user_id)
                          .eq('read', False)
                          .execute())
            unread = unread_res.count or 0
            return mine, unread
        all_notifs = _load_json(NOTIFICATIONS_FILE)
        mine = [n for n in all_notifs if n.get('user_id') == user_id]
        unread = sum(1 for n in mine if not n.get('read', False))
        return mine[:limit], unread

    def mark_notification_read(self, notif_id: str, user_id: str) -> bool:
        if self._use_db:
            self._sb.table('notifications').update({'read': True}).eq(
                'id', notif_id).eq('user_id', user_id).execute()
            return True
        notifs = _load_json(NOTIFICATIONS_FILE)
        for n in notifs:
            if n['id'] == notif_id and n.get('user_id') == user_id:
                n['read'] = True
                break
        _save_json(NOTIFICATIONS_FILE, notifs)
        return True

    def mark_all_notifications_read(self, user_id: str) -> bool:
        if self._use_db:
            self._sb.table('notifications').update({'read': True}).eq(
                'user_id', user_id).eq('read', False).execute()
            return True
        notifs = _load_json(NOTIFICATIONS_FILE)
        for n in notifs:
            if n.get('user_id') == user_id:
                n['read'] = True
        _save_json(NOTIFICATIONS_FILE, notifs)
        return True

    # ─── CHAT CHANNELS ────────────────────────────────────────────────────
    def get_chat_channels(self, user_id: str) -> list[dict]:
        if self._use_db:
            # RLS handles filtering; fetch all channels user can see
            channels = self._sb_select('chat_channels', order_col='created_at')
            # Enrich with latest message info
            for ch in channels:
                msgs = (self._sb.table('chat_messages')
                        .select('*')
                        .eq('channel_id', ch['id'])
                        .order('ts', desc=True)
                        .limit(1)
                        .execute().data or [])
                msg_count = (self._sb.table('chat_messages')
                             .select('id', count='exact')
                             .eq('channel_id', ch['id'])
                             .execute())
                ch['message_count'] = msg_count.count or 0
                if msgs:
                    ch['last_message'] = (msgs[0].get('text', '') or '')[:60]
                    ch['last_message_at'] = msgs[0].get('ts', '')
                    ch['last_message_by'] = msgs[0].get('sender_name', '')
                else:
                    ch['last_message'] = ''
                    ch['last_message_at'] = ''
                    ch['last_message_by'] = ''
            channels.sort(key=lambda c: c.get('last_message_at',
                                               c.get('created_at', '')),
                          reverse=True)
            return channels
        # JSON fallback
        channels = _load_json(CHAT_CHANNELS_FILE)
        my_channels = [c for c in channels
                       if user_id in c.get('member_ids', [])
                       or c.get('type') == 'general']
        messages = _load_json(CHAT_MESSAGES_FILE)
        for ch in my_channels:
            ch_msgs = [m for m in messages if m.get('channel_id') == ch['id']]
            ch['message_count'] = len(ch_msgs)
            if ch_msgs:
                ch['last_message'] = ch_msgs[-1].get('text', '')[:60]
                ch['last_message_at'] = ch_msgs[-1].get('ts', '')
                ch['last_message_by'] = ch_msgs[-1].get('sender_name', '')
        my_channels.sort(
            key=lambda c: c.get('last_message_at', c.get('created_at', '')),
            reverse=True)
        return my_channels

    def create_chat_channel(self, channel: dict,
                            user_id: str) -> dict:
        ch_type = channel.get('type', 'direct')
        member_ids = channel.get('member_ids', [])
        if user_id not in member_ids:
            member_ids.append(user_id)
        channel['member_ids'] = member_ids

        if self._use_db:
            # Check for existing DM
            if ch_type == 'direct' and len(member_ids) == 2:
                existing = self._sb_select('chat_channels',
                                           filters={'type': 'direct'})
                for ex in existing:
                    if set(ex.get('member_ids', [])) == set(member_ids):
                        return ex
            channel.setdefault('id', f"ch_{uuid.uuid4().hex[:8]}")
            channel.setdefault('created_at', _now_iso())
            return self._sb_insert('chat_channels', channel)

        # JSON fallback
        channels = _load_json(CHAT_CHANNELS_FILE)
        if ch_type == 'direct' and len(member_ids) == 2:
            existing = next(
                (c for c in channels
                 if c.get('type') == 'direct'
                 and set(c.get('member_ids', [])) == set(member_ids)), None)
            if existing:
                return existing
        channel.setdefault('id', f"ch_{uuid.uuid4().hex[:8]}")
        channel.setdefault('created_at', _now_iso())
        channels.append(channel)
        _save_json(CHAT_CHANNELS_FILE, channels)
        return channel

    def get_chat_messages(self, channel_id: str,
                          limit: int = 100) -> list[dict]:
        if self._use_db:
            return self._sb_select('chat_messages',
                                   filters={'channel_id': channel_id},
                                   order_col='ts', ascending=True,
                                   limit=limit)
        messages = _load_json(CHAT_MESSAGES_FILE)
        ch_msgs = [m for m in messages if m.get('channel_id') == channel_id]
        ch_msgs.sort(key=lambda m: m.get('ts', ''))
        return ch_msgs[-limit:]

    def send_chat_message(self, channel_id: str, sender_id: str,
                          sender_name: str, text: str) -> dict:
        msg = {
            'id': f"msg_{uuid.uuid4().hex[:8]}",
            'channel_id': channel_id,
            'sender_id': sender_id,
            'sender_name': sender_name,
            'text': text,
            'ts': _now_iso(),
        }
        if self._use_db:
            return self._sb_insert('chat_messages', msg)
        messages = _load_json(CHAT_MESSAGES_FILE)
        messages.append(msg)
        _save_json(CHAT_MESSAGES_FILE, messages)
        return msg

    def get_chat_channel(self, channel_id: str) -> dict | None:
        if self._use_db:
            res = self._sb.table('chat_channels').select('*').eq(
                'id', channel_id).execute()
            return res.data[0] if res.data else None
        channels = _load_json(CHAT_CHANNELS_FILE)
        return next((c for c in channels if c['id'] == channel_id), None)

    def ensure_general_channel(self) -> None:
        if self._use_db:
            res = self._sb.table('chat_channels').select('id').eq(
                'type', 'general').execute()
            if not res.data:
                self._sb_insert('chat_channels', {
                    'id': 'ch_general',
                    'name': 'General',
                    'type': 'general',
                    'member_ids': [],
                    'member_names': [],
                    'created_by': 'system',
                    'created_at': _now_iso(),
                })
            return
        channels = _load_json(CHAT_CHANNELS_FILE)
        has_general = any(c.get('type') == 'general' for c in channels)
        if not has_general:
            channels.append({
                'id': 'ch_general',
                'name': 'General',
                'type': 'general',
                'member_ids': [],
                'member_names': [],
                'created_by': 'system',
                'created_at': _now_iso(),
            })
            _save_json(CHAT_CHANNELS_FILE, channels)

    # ─── CRM SUMMARY (for AI context) ────────────────────────────────────
    def crm_summary(self, max_leads: int = 0) -> str:
        leads = self.get_leads()
        activities = []
        if self._use_db:
            activities = self._sb_select('activities', order_col='ts')
        else:
            activities = _load_json(NOTES_FILE)
        total = len(leads)
        by_status: dict[str, int] = {}
        for l in leads:
            s = l.get('status', 'new')
            by_status[s] = by_status.get(s, 0) + 1
        parts = [f"CRM has {total} leads."]
        for s, c in sorted(by_status.items()):
            parts.append(f"  {s}: {c}")
        if max_leads:
            leads = leads[:max_leads]
        for l in leads:
            lid = l.get('id', '?')
            name = l.get('name', 'Unknown')
            status = l.get('status', '?')
            phone = l.get('phone', '')
            email_addr = l.get('email', '')
            src = l.get('source', '')
            lead_acts = [a for a in activities if a.get('lead_id') == lid]
            act_count = len(lead_acts)
            parts.append(
                f"- [{lid}] {name} | {status} | {phone} | {email_addr}"
                f" | src={src} | activities={act_count}"
            )
        return '\n'.join(parts)

    # ─── DEALS / REVENUE PIPELINE ────────────────────────────────────────
    DEALS_FILE = DATA_DIR / 'deals.json'

    def get_deals(self, limit: int = 0, offset: int = 0) -> list[dict]:
        if self._use_db:
            try:
                return self._sb_select('deals', order_col='created_at',
                                       limit=limit, offset=offset)
            except Exception as e:
                logging.error(f'Supabase deals select failed: {e}')
                # Fall through to JSON storage
        deals = _load_json(self.DEALS_FILE)
        deals.sort(key=lambda d: d.get('created_at', ''), reverse=True)
        if limit > 0:
            return deals[offset:offset + limit]
        return deals

    def create_deal(self, deal: dict) -> dict:
        now = _now_iso()
        deal.setdefault('id', f"deal_{uuid.uuid4().hex[:8]}")
        deal.setdefault('created_at', now)
        deal.setdefault('updated_at', now)
        deal.setdefault('stage', 'unfinished')
        if self._use_db:
            try:
                return self._sb_insert('deals', deal)
            except Exception as e:
                logging.error(f'Supabase deals insert failed: {e}')
                logging.info('Falling back to JSON file storage for deals')
                # Fall through to JSON storage
        deals = _load_json(self.DEALS_FILE)
        deals.insert(0, deal)
        _save_json(self.DEALS_FILE, deals)
        return deal

    def update_deal(self, deal_id: str, fields: dict) -> dict | None:
        fields['updated_at'] = _now_iso()
        if self._use_db:
            try:
                return self._sb_update('deals', deal_id, fields)
            except Exception as e:
                logging.error(f'Supabase deals update failed: {e}')
                # Fall through to JSON storage
        deals = _load_json(self.DEALS_FILE)
        for d in deals:
            if d['id'] == deal_id:
                d.update(fields)
                _save_json(self.DEALS_FILE, deals)
                return d
        return None

    def delete_deal(self, deal_id: str) -> bool:
        if self._use_db:
            try:
                return self._sb_delete('deals', deal_id)
            except Exception as e:
                logging.error(f'Supabase deals delete failed: {e}')
                # Fall through to JSON storage
        deals = _load_json(self.DEALS_FILE)
        deals = [d for d in deals if d['id'] != deal_id]
        _save_json(self.DEALS_FILE, deals)
        return True

    def get_revenue_forecast(self) -> dict:
        deals = self.get_deals()
        total_pipeline = 0.0
        done_revenue = 0.0
        by_stage: dict[str, float] = {}
        for d in deals:
            val = float(d.get('value', 0) or 0)
            stage = d.get('stage', 'unfinished')
            by_stage[stage] = by_stage.get(stage, 0) + val
            if stage == 'done':
                done_revenue += val
            else:
                total_pipeline += val
        return {
            'total_pipeline': total_pipeline,
            'done_revenue': done_revenue,
            'by_stage': by_stage,
            'deal_count': len(deals),
        }

    # ─── AUTOMATION RULES ─────────────────────────────────────────────────
    AUTOMATION_RULES_FILE = DATA_DIR / 'automation_rules.json'

    def get_automation_rules(self) -> list[dict]:
        if self._use_db:
            return self._sb_select('automation_rules', order_col='created_at')
        return _load_json(self.AUTOMATION_RULES_FILE)

    def create_automation_rule(self, rule: dict) -> dict:
        now = _now_iso()
        rule.setdefault('id', f"rule_{uuid.uuid4().hex[:8]}")
        rule.setdefault('created_at', now)
        rule.setdefault('updated_at', now)
        rule.setdefault('enabled', True)
        if self._use_db:
            return self._sb_insert('automation_rules', rule)
        rules = _load_json(self.AUTOMATION_RULES_FILE)
        rules.insert(0, rule)
        _save_json(self.AUTOMATION_RULES_FILE, rules)
        return rule

    def update_automation_rule(self, rule_id: str, fields: dict) -> dict | None:
        fields['updated_at'] = _now_iso()
        if self._use_db:
            return self._sb_update('automation_rules', rule_id, fields)
        rules = _load_json(self.AUTOMATION_RULES_FILE)
        for r in rules:
            if r['id'] == rule_id:
                r.update(fields)
                _save_json(self.AUTOMATION_RULES_FILE, rules)
                return r
        return None

    def delete_automation_rule(self, rule_id: str) -> bool:
        if self._use_db:
            return self._sb_delete('automation_rules', rule_id)
        rules = _load_json(self.AUTOMATION_RULES_FILE)
        rules = [r for r in rules if r['id'] != rule_id]
        _save_json(self.AUTOMATION_RULES_FILE, rules)
        return True

    # ─── CUSTOM FIELDS ────────────────────────────────────────────────────
    CUSTOM_FIELDS_FILE = DATA_DIR / 'custom_fields.json'

    def get_custom_fields(self) -> list[dict]:
        if self._use_db:
            return self._sb_select('custom_fields', order_col='created_at')
        return _load_json(self.CUSTOM_FIELDS_FILE)

    def create_custom_field(self, field: dict) -> dict:
        now = _now_iso()
        field.setdefault('id', f"cf_{uuid.uuid4().hex[:8]}")
        field.setdefault('created_at', now)
        if self._use_db:
            return self._sb_insert('custom_fields', field)
        fields = _load_json(self.CUSTOM_FIELDS_FILE)
        fields.append(field)
        _save_json(self.CUSTOM_FIELDS_FILE, fields)
        return field

    def delete_custom_field(self, field_id: str) -> bool:
        if self._use_db:
            return self._sb_delete('custom_fields', field_id)
        fields = _load_json(self.CUSTOM_FIELDS_FILE)
        fields = [f for f in fields if f['id'] != field_id]
        _save_json(self.CUSTOM_FIELDS_FILE, fields)
        return True

    # ─── GLOBAL SEARCH ────────────────────────────────────────────────────
    def search(self, query: str) -> dict:
        """Search leads, tasks, deals, and activities matching query."""
        q = query.lower()
        results: dict[str, list[dict]] = {
            'leads': [],
            'tasks': [],
            'deals': [],
            'activities': [],
        }
        # Leads
        for l in self.get_leads():
            text = f"{l.get('name','')} {l.get('email','')} {l.get('phone','')} {l.get('source','')}".lower()
            if q in text:
                results['leads'].append(l)
        # Tasks
        for t in self.get_tasks():
            text = f"{t.get('title','')} {t.get('description','')}".lower()
            if q in text:
                results['tasks'].append(t)
        # Deals
        for d in self.get_deals():
            text = f"{d.get('title','')} {d.get('lead_name','')} {d.get('owner_name','')}".lower()
            if q in text:
                results['deals'].append(d)
        # Activities
        all_acts = self.get_all_activities()
        for acts in all_acts.values():
            for a in acts:
                text = f"{a.get('content','')} {a.get('author','')}".lower()
                if q in text:
                    results['activities'].append(a)
        # Limit each category
        for k in results:
            results[k] = results[k][:20]
        return results

    # ─── REPORTS ──────────────────────────────────────────────────────────
    def get_report_data(self, report_type: str) -> dict:
        """Generate report data. Types: overview, leads, revenue."""
        leads = self.get_leads()
        tasks = self.get_tasks()
        deals = self.get_deals()

        if report_type == 'overview':
            total_leads = len(leads)
            converted = sum(1 for l in leads if l.get('status') == 'converted')
            conversion_rate = round(converted / total_leads * 100, 1) if total_leads else 0
            won = [d for d in deals if d.get('stage') == 'done']
            won_revenue = sum(float(d.get('value', 0) or 0) for d in won)
            pipeline = sum(float(d.get('value', 0) or 0) for d in deals if d.get('stage') != 'done')
            total_tasks = len(tasks)
            done_tasks = sum(1 for t in tasks if t.get('status') == 'done')
            return {
                'total_leads': total_leads,
                'conversion_rate': conversion_rate,
                'won_revenue': won_revenue,
                'pipeline_value': pipeline,
                'total_tasks': total_tasks,
                'done_tasks': done_tasks,
            }

        if report_type == 'leads':
            by_status: dict[str, int] = {}
            by_source: dict[str, int] = {}
            for l in leads:
                s = l.get('status', 'unknown')
                by_status[s] = by_status.get(s, 0) + 1
                src = l.get('source', 'Unknown')
                by_source[src] = by_source.get(src, 0) + 1
            return {'by_status': by_status, 'by_source': by_source, 'total': len(leads)}

        if report_type == 'revenue':
            by_stage: dict[str, dict] = {}
            for d in deals:
                stage = d.get('stage', 'unfinished')
                if stage not in by_stage:
                    by_stage[stage] = {'count': 0, 'value': 0.0}
                by_stage[stage]['count'] += 1
                by_stage[stage]['value'] += float(d.get('value', 0) or 0)
            return {'by_stage': by_stage, 'total_deals': len(deals)}

        return {}

    def sales_analytics(self) -> dict:
        leads = self.get_leads()
        total = len(leads)
        by_status: dict[str, int] = {}
        by_source: dict[str, int] = {}
        for l in leads:
            s = l.get('status', 'new')
            by_status[s] = by_status.get(s, 0) + 1
            src = l.get('source', 'Unknown')
            by_source[src] = by_source.get(src, 0) + 1
        converted = by_status.get('converted', 0)
        return {
            'total_leads': total,
            'by_status': by_status,
            'by_source': by_source,
            'conversion_rate': round(
                converted / total * 100, 1) if total else 0,
        }
