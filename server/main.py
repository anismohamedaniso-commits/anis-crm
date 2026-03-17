from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse, Response, FileResponse
import httpx
import os
import json
import uuid
import hashlib
import hmac
import html as _html
import time
from datetime import datetime
from typing import Optional, List
from pathlib import Path
from dotenv import load_dotenv
import logging
from pydantic import BaseModel, Field, field_validator
import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Database abstraction layer (Supabase or JSON fallback)
from db import CrmDatabase

load_dotenv()


# =============================================================================
# PYDANTIC INPUT MODELS — validate all mutation payloads
# =============================================================================

class LeadCreate(BaseModel):
    id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=200)
    email: Optional[str] = Field(None, max_length=254)
    phone: Optional[str] = Field(None, max_length=30)
    status: str = Field('new', max_length=30)
    source: Optional[str] = Field(None, max_length=100)
    campaign: Optional[str] = Field(None, max_length=200)
    deal_value: Optional[float] = Field(0, ge=0)
    assigned_to: Optional[str] = None
    assigned_to_name: Optional[str] = None
    tags: Optional[list] = None
    next_followup_at: Optional[str] = None
    notes: Optional[str] = None
    company: Optional[str] = None
    country: Optional[str] = Field('egypt', max_length=50)

class LeadUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=200)
    email: Optional[str] = Field(None, max_length=254)
    phone: Optional[str] = Field(None, max_length=30)
    status: Optional[str] = Field(None, max_length=30)
    source: Optional[str] = Field(None, max_length=100)
    campaign: Optional[str] = Field(None, max_length=200)
    deal_value: Optional[float] = Field(None, ge=0)
    assigned_to: Optional[str] = None
    assigned_to_name: Optional[str] = None
    tags: Optional[list] = None
    next_followup_at: Optional[str] = None
    notes: Optional[str] = None
    company: Optional[str] = None
    country: Optional[str] = Field(None, max_length=50)

class ActivityCreate(BaseModel):
    lead_id: str = Field(..., min_length=1, max_length=100)
    type: str = Field('note', max_length=30)
    notes: Optional[str] = Field(None, max_length=5000)
    body: Optional[str] = Field(None, max_length=5000)
    outcome: Optional[str] = Field(None, max_length=200)

class DealCreate(BaseModel):
    lead_id: Optional[str] = Field(None, max_length=100)
    title: str = Field(..., min_length=1, max_length=200)
    value: Optional[float] = Field(0, ge=0)
    stage: str = Field('discovery', max_length=50)
    contact_name: Optional[str] = Field(None, max_length=200)
    contact_email: Optional[str] = Field(None, max_length=254)
    expected_close: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=5000)

class CampaignCreate(BaseModel):
    id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field('', max_length=2000)
    market: str = Field('egypt', max_length=50)
    budget: Optional[float] = Field(0, ge=0)
    status: Optional[str] = Field('active', max_length=20)
    start_date: Optional[str] = None
    end_date: Optional[str] = None

class CampaignUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = Field(None, max_length=2000)
    market: Optional[str] = Field(None, max_length=50)
    budget: Optional[float] = Field(None, ge=0)
    status: Optional[str] = Field(None, max_length=20)
    start_date: Optional[str] = None
    end_date: Optional[str] = None


OLLAMA_URL = os.environ.get('OLLAMA_URL', 'http://127.0.0.1:11434')
API_KEY = os.environ.get('API_KEY')

# ── In-memory TTL cache for expensive AI context ──
_cache: dict[str, tuple[float, object]] = {}
_CACHE_TTL = 30  # seconds

def _cache_get(key: str):
    """Return cached value if still valid, else None."""
    entry = _cache.get(key)
    if entry and (time.time() - entry[0]) < _CACHE_TTL:
        return entry[1]
    return None

def _cache_set(key: str, value: object):
    _cache[key] = (time.time(), value)

# ── Email / SMTP config ──
SMTP_HOST = os.environ.get('SMTP_HOST', 'smtp.zoho.com')
SMTP_PORT = int(os.environ.get('SMTP_PORT', '587'))
SMTP_USER = os.environ.get('SMTP_USER', 'anis.arafa@tickandtalk.com')
SMTP_PASS = os.environ.get('SMTP_PASS', '')  # Zoho App-Specific Password
SMTP_FROM_NAME = os.environ.get('SMTP_FROM_NAME', 'Anis Arafa')

# ── Facebook / WhatsApp integration config ──
# These can be set via .env or the /api/integrations/config endpoint at runtime
FB_VERIFY_TOKEN = os.environ.get('FB_VERIFY_TOKEN', 'anis_crm_verify_token')
FB_PAGE_ACCESS_TOKEN = os.environ.get('FB_PAGE_ACCESS_TOKEN', '')
FB_APP_SECRET = os.environ.get('FB_APP_SECRET', '')  # For webhook signature verification
WA_VERIFY_TOKEN = os.environ.get('WA_VERIFY_TOKEN', 'anis_crm_wa_verify')
WA_PHONE_NUMBER_ID = os.environ.get('WA_PHONE_NUMBER_ID', '')
WA_ACCESS_TOKEN = os.environ.get('WA_ACCESS_TOKEN', '')

# ── Zapier integration config ──
ZAPIER_API_KEY = os.environ.get('ZAPIER_API_KEY', '')

# Allowed CORS origins — set CORS_ORIGINS env var in production
# (comma-separated list, e.g. "https://app.example.com,https://admin.example.com")
_cors_origins_raw = os.environ.get('CORS_ORIGINS', '')
# Always include the known production frontend domains
_PRODUCTION_ORIGINS = [
    'https://tickandtalkcrm.netlify.app',
    'https://aesthetic-entremet-ab9ef2.netlify.app',
]
_dev_origins = ['http://localhost:3000', 'http://127.0.0.1:3000',
                'http://localhost:8080', 'http://127.0.0.1:8080',
                'http://localhost:8000', 'http://127.0.0.1:8000']
if _cors_origins_raw:
    _env_origins = [o.strip() for o in _cors_origins_raw.split(',') if o.strip()]
else:
    _env_origins = _dev_origins
ALLOWED_ORIGINS = list(set(_env_origins + _PRODUCTION_ORIGINS))

# =============================================================================
# RATE LIMITER — in-memory sliding window per IP
# =============================================================================
from collections import defaultdict as _defaultdict

def _get_real_ip(request: Request) -> str:
    """Get real client IP behind reverse proxies (Railway, etc.)."""
    forwarded = request.headers.get('x-forwarded-for')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.client.host if request.client else '127.0.0.1'

# (method:path) → (max_requests, window_seconds)
_RATE_LIMITS: dict[str, tuple[int, int]] = {
    'POST:/api/ai/chat':           (20, 60),
    'POST:/api/ai/assistant':      (15, 60),
    'POST:/api/ai/embeddings':     (30, 60),
    'POST:/api/email/send':        (10, 60),
    'POST:/api/email/test':        (5,  60),
    'POST:/api/whatsapp/send':     (10, 60),
    'POST:/api/leads/import':      (5,  60),
    'POST:/api/leads/bulk-update': (10, 60),
    'POST:/api/leads/bulk-delete': (10, 60),
}
_rate_windows: dict[str, list[float]] = _defaultdict(list)

app = FastAPI(title="Ollama proxy for Anis CRM")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# RATE LIMIT + SECURITY HEADERS MIDDLEWARE
# =============================================================================
@app.middleware('http')
async def rate_limit_and_security_headers(request: Request, call_next):
    # ── Rate limiting ──
    route_key = f'{request.method}:{request.url.path}'
    limit_cfg = _RATE_LIMITS.get(route_key)
    if limit_cfg:
        max_reqs, window = limit_cfg
        ip = _get_real_ip(request)
        cache_key = f'{ip}:{route_key}'
        now = time.time()
        _rate_windows[cache_key] = [t for t in _rate_windows[cache_key] if now - t < window]
        if len(_rate_windows[cache_key]) >= max_reqs:
            return JSONResponse(
                status_code=429,
                content={'detail': f'Rate limit exceeded. Max {max_reqs} requests per {window}s.'},
                headers={'Retry-After': str(window)},
            )
        _rate_windows[cache_key].append(now)

    response = await call_next(request)

    # ── Security headers ──
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    host = request.headers.get('host', '')
    if not host.startswith('localhost') and not host.startswith('127.0.0.1'):
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    return response


def _check_auth(req: Request):
    """Check API key or JWT bearer token. Fails closed if neither is configured."""
    # Check API key first
    key = req.headers.get('x-api-key') or req.query_params.get('api_key')
    if API_KEY and key == API_KEY:
        return True
    # Fall back to JWT auth (any valid logged-in user)
    if _get_supabase_user(req):
        return True
    # If no API_KEY is configured and no JWT, only allow in explicit dev mode
    if not API_KEY and os.environ.get('DEV_MODE') == 'true':
        return True
    return False


# =============================================================================
# USER ACCOUNTS & ROLE-BASED AUTH (Supabase-backed)
# =============================================================================
from supabase import create_client
import jwt  # PyJWT — installed with supabase SDK

# Supabase config — read from environment, no hardcoded secrets
SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SUPABASE_ANON_KEY = os.environ.get('SUPABASE_ANON_KEY', '')
SUPABASE_SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
SUPABASE_JWT_SECRET = os.environ.get('SUPABASE_JWT_SECRET', '')

# JWKS client for ES256 token verification (Supabase now uses asymmetric keys)
_jwks_client = None
if SUPABASE_URL:
    try:
        from jwt import PyJWKClient
        _jwks_url = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"
        _jwks_client = PyJWKClient(_jwks_url, cache_keys=True, lifespan=3600)
        logging.info(f'JWKS client initialized: {_jwks_url}')
    except Exception as e:
        logging.warning(f'Failed to initialize JWKS client: {e}')

if not SUPABASE_URL:
    logging.warning('SUPABASE_URL not set — Supabase features disabled')
if not SUPABASE_JWT_SECRET and not _jwks_client:
    logging.warning('No JWT verification method available — set SUPABASE_URL or SUPABASE_JWT_SECRET!')

# Admin client (service_role) for creating/deleting users
_supabase_admin = None
if SUPABASE_SERVICE_KEY:
    _supabase_admin = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    logging.info('Supabase admin client initialized')
else:
    logging.warning('SUPABASE_SERVICE_ROLE_KEY not set — user management will be unavailable')

# Initialize CRM database layer (Supabase when available, else JSON files)
db = CrmDatabase(supabase_admin=_supabase_admin)

# Roles
ROLE_ACCOUNT_EXEC = 'account_executive'
ROLE_CAMPAIGN_EXEC = 'campaign_executive'


def _get_supabase_user(req: Request) -> Optional[dict]:
    """Verify Supabase JWT and return user info from the token's user_metadata."""
    auth = req.headers.get('authorization', '')
    if not auth.startswith('Bearer '):
        return None
    token = auth[7:]
    try:
        payload = None
        # Method 1: JWKS-based verification (ES256 — preferred for Supabase v2+)
        if _jwks_client:
            try:
                signing_key = _jwks_client.get_signing_key_from_jwt(token)
                payload = jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=['ES256'],
                    audience='authenticated',
                )
            except Exception as e:
                logging.debug(f'JWKS verification failed, trying HS256 fallback: {e}')

        # Method 2: HS256 fallback (legacy Supabase projects)
        if payload is None and SUPABASE_JWT_SECRET:
            try:
                payload = jwt.decode(
                    token,
                    SUPABASE_JWT_SECRET,
                    algorithms=['HS256'],
                    audience='authenticated',
                )
            except Exception as e:
                logging.debug(f'HS256 verification failed: {e}')

        # Method 3: Removed — never decode without verification in any environment

        if payload is None:
            return None

        user_id = payload.get('sub')
        if not user_id:
            return None
        meta = payload.get('user_metadata', {})
        email = payload.get('email', '')
        return {
            'id': user_id,
            'name': meta.get('name', email.split('@')[0] if email else ''),
            'email': email,
            'role': meta.get('role', ROLE_CAMPAIGN_EXEC),
            'user_metadata': meta,
        }
    except Exception as e:
        logging.debug(f'JWT verification failed: {e}')
        return None


def _require_user(req: Request) -> dict:
    """Require authentication (JWT preferred, API key fallback). Returns user context."""
    user = _get_supabase_user(req)
    if user:
        return user
    # API key fallback — returns system user with admin role
    key = req.headers.get('x-api-key') or req.query_params.get('api_key')
    if API_KEY and key == API_KEY:
        return {'id': 'system', 'name': 'API Key', 'email': '', 'role': ROLE_ACCOUNT_EXEC}
    raise HTTPException(status_code=401, detail='Not authenticated')


def _require_account_exec(req: Request) -> dict:
    """Require the current user to be an account_executive."""
    user = _require_user(req)
    if user.get('role') != ROLE_ACCOUNT_EXEC:
        raise HTTPException(status_code=403, detail='Insufficient permissions — admin only')
    return user


# Auth endpoints — user management via Supabase Admin API

@app.get('/api/auth/users')
async def list_users(req: Request):
    _require_account_exec(req)
    if not _supabase_admin:
        raise HTTPException(status_code=500, detail='Server not configured for user management')
    all_users = _supabase_admin.auth.admin.list_users()
    users = []
    for u in all_users:
        meta = getattr(u, 'user_metadata', {}) or {}
        users.append({
            'id': str(u.id),
            'name': meta.get('name', (u.email or '').split('@')[0]),
            'email': u.email or '',
            'role': meta.get('role', ROLE_CAMPAIGN_EXEC),
        })
    return JSONResponse(content={'users': users})


@app.post('/api/auth/users')
async def create_user(req: Request):
    _require_account_exec(req)
    if not _supabase_admin:
        raise HTTPException(status_code=500, detail='Server not configured for user management (missing SUPABASE_SERVICE_ROLE_KEY)')
    body = await req.json()
    name = (body.get('name') or '').strip()
    email = (body.get('email') or '').strip().lower()
    password = body.get('password') or ''
    role = body.get('role', ROLE_CAMPAIGN_EXEC)
    if not name or not email or not password:
        raise HTTPException(status_code=400, detail='Name, email, and password required')
    if role not in (ROLE_ACCOUNT_EXEC, ROLE_CAMPAIGN_EXEC):
        raise HTTPException(status_code=400, detail='Invalid role')
    try:
        # Create user in Supabase Auth
        res = _supabase_admin.auth.admin.create_user({
            'email': email,
            'password': password,
            'email_confirm': True,  # Auto-confirm so they can login immediately
            'user_metadata': {'name': name, 'role': role},
        })
        new_user_id = res.user.id
        return JSONResponse(content={'user': {'id': str(new_user_id), 'name': name, 'email': email, 'role': role}})
    except Exception as e:
        msg = str(e)
        if 'already been registered' in msg or 'duplicate' in msg.lower():
            raise HTTPException(status_code=409, detail='Email already exists')
        logging.error(f'Create user failed: {e}')
        raise HTTPException(status_code=500, detail=f'Failed to create user: {msg}')


@app.delete('/api/auth/users/{user_id}')
async def delete_user(req: Request, user_id: str):
    current = _require_account_exec(req)
    if current['id'] == user_id:
        raise HTTPException(status_code=400, detail='Cannot delete yourself')
    if not _supabase_admin:
        raise HTTPException(status_code=500, detail='Server not configured for user management')
    try:
        _supabase_admin.auth.admin.delete_user(user_id)
        return JSONResponse(content={'ok': True})
    except Exception as e:
        logging.error(f'Delete user failed: {e}')
        raise HTTPException(status_code=500, detail=f'Failed to delete user: {str(e)}')


@app.put('/api/auth/users/{user_id}')
async def update_user(req: Request, user_id: str):
    _require_account_exec(req)
    if not _supabase_admin:
        raise HTTPException(status_code=500, detail='Server not configured for user management')
    body = await req.json()
    try:
        # Build auth update payload
        auth_updates = {}
        meta_updates = {}
        if 'name' in body: meta_updates['name'] = body['name']
        if 'role' in body and body['role'] in (ROLE_ACCOUNT_EXEC, ROLE_CAMPAIGN_EXEC):
            meta_updates['role'] = body['role']
        if 'email' in body: auth_updates['email'] = body['email'].strip().lower()
        if body.get('password'): auth_updates['password'] = body['password']
        if meta_updates: auth_updates['user_metadata'] = meta_updates
        if auth_updates:
            _supabase_admin.auth.admin.update_user_by_id(user_id, auth_updates)
        # Fetch updated user
        updated = _supabase_admin.auth.admin.get_user_by_id(user_id)
        if updated and updated.user:
            u = updated.user
            meta = getattr(u, 'user_metadata', {}) or {}
            return JSONResponse(content={'user': {
                'id': str(u.id),
                'name': meta.get('name', (u.email or '').split('@')[0]),
                'email': u.email or '',
                'role': meta.get('role', ROLE_CAMPAIGN_EXEC),
            }})
        raise HTTPException(status_code=404, detail='User not found')
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f'Update user failed: {e}')
        raise HTTPException(status_code=500, detail=f'Failed to update user: {str(e)}')


# Remove old startup seed — users are now managed in Supabase


# =============================================================================
# STORAGE — ensure buckets exist
# =============================================================================

@app.post('/api/auth/storage/ensure-bucket')
async def ensure_storage_bucket(req: Request):
    """Create a Supabase Storage bucket if it doesn't already exist."""
    user = _require_user(req)
    body = await req.json()
    bucket_name = body.get('bucket', 'avatars')
    is_public = body.get('public', True)

    if not SUPABASE_SERVICE_KEY:
        raise HTTPException(status_code=500, detail='Service key not configured')

    # Use the Supabase Storage REST API directly with service_role key
    async with httpx.AsyncClient(timeout=15) as client:
        # Check if bucket exists
        check_resp = await client.get(
            f'{SUPABASE_URL}/storage/v1/bucket/{bucket_name}',
            headers={
                'apikey': SUPABASE_SERVICE_KEY,
                'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
            },
        )
        if check_resp.status_code == 200:
            logging.info(f'Storage bucket "{bucket_name}" already exists')
            return JSONResponse(content={'status': 'exists', 'bucket': bucket_name})

        # Create bucket
        create_resp = await client.post(
            f'{SUPABASE_URL}/storage/v1/bucket',
            headers={
                'apikey': SUPABASE_SERVICE_KEY,
                'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
                'Content-Type': 'application/json',
            },
            json={
                'id': bucket_name,
                'name': bucket_name,
                'public': is_public,
                'file_size_limit': 5242880,  # 5MB
                'allowed_mime_types': ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
            },
        )
        if create_resp.status_code in (200, 201):
            logging.info(f'Created storage bucket "{bucket_name}" (public={is_public})')
            return JSONResponse(content={'status': 'created', 'bucket': bucket_name})
        else:
            detail = create_resp.text
            logging.error(f'Failed to create bucket "{bucket_name}": {detail}')
            raise HTTPException(status_code=create_resp.status_code, detail=detail)


from fastapi import UploadFile, File, Form
import base64

@app.post('/api/auth/upload-avatar')
async def upload_avatar(req: Request):
    """Upload avatar via server using service_role key (bypasses RLS)."""
    if not SUPABASE_SERVICE_KEY:
        raise HTTPException(status_code=500, detail='Service key not configured')

    # Get user from JWT
    user = _require_user(req)

    body = await req.json()
    file_data_b64 = body.get('file_data')  # base64 encoded
    file_name = body.get('file_name', 'avatar.jpg')
    content_type = body.get('content_type', 'image/jpeg')

    if not file_data_b64:
        raise HTTPException(status_code=400, detail='No file data provided')

    try:
        file_bytes = base64.b64decode(file_data_b64)
    except Exception:
        raise HTTPException(status_code=400, detail='Invalid base64 file data')

    user_id = user['id']
    ext = file_name.rsplit('.', 1)[-1].lower() if '.' in file_name else 'jpg'
    storage_path = f'{user_id}.{ext}'
    bucket = 'avatars'

    # Ensure bucket exists
    async with httpx.AsyncClient(timeout=15) as client:
        check_resp = await client.get(
            f'{SUPABASE_URL}/storage/v1/bucket/{bucket}',
            headers={
                'apikey': SUPABASE_SERVICE_KEY,
                'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
            },
        )
        if check_resp.status_code != 200:
            await client.post(
                f'{SUPABASE_URL}/storage/v1/bucket',
                headers={
                    'apikey': SUPABASE_SERVICE_KEY,
                    'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
                    'Content-Type': 'application/json',
                },
                json={'id': bucket, 'name': bucket, 'public': True,
                      'file_size_limit': 5242880,
                      'allowed_mime_types': ['image/jpeg', 'image/png', 'image/gif', 'image/webp']},
            )

    # Upload file using service_role key (bypasses RLS)
    async with httpx.AsyncClient(timeout=30) as client:
        # Try upsert first (update existing), fall back to upload
        upload_resp = await client.post(
            f'{SUPABASE_URL}/storage/v1/object/{bucket}/{storage_path}',
            headers={
                'apikey': SUPABASE_SERVICE_KEY,
                'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
                'Content-Type': content_type,
                'x-upsert': 'true',
            },
            content=file_bytes,
        )
        if upload_resp.status_code not in (200, 201):
            detail = upload_resp.text
            logging.error(f'Avatar upload failed: {detail}')
            raise HTTPException(status_code=upload_resp.status_code, detail=f'Storage upload failed: {detail}')

    public_url = f'{SUPABASE_URL}/storage/v1/object/public/{bucket}/{storage_path}'

    # Update user metadata with avatar URL
    try:
        _supabase_admin.auth.admin.update_user_by_id(
            user_id,
            {'user_metadata': {**user.get('user_metadata', {}), 'avatar_url': public_url}}
        )
    except Exception as e:
        logging.error(f'Failed to update user metadata with avatar: {e}')

    logging.info(f'Avatar uploaded for user {user_id}: {public_url}')
    return JSONResponse(content={'url': public_url})


@app.get("/api/ai/models")
async def models(req: Request):
    _require_user(req)
    async with httpx.AsyncClient(timeout=30) as client:
        try:
            r = await client.get(f"{OLLAMA_URL}/api/tags")
            r.raise_for_status()
            return JSONResponse(status_code=r.status_code, content=r.json())
        except Exception:
            # Ollama not available — return empty model list gracefully
            return JSONResponse(content={"models": []})


@app.post("/api/ai/chat")
async def chat(req: Request):
    _require_user(req)
    payload = await req.json()
    model = payload.get('model', 'qwen2.5:7b')
    prompt = payload.get('prompt')
    messages = payload.get('messages')
    options = payload.get('options', {})

    # Build proper messages array for Ollama Chat API
    if isinstance(messages, list) and messages:
        chat_messages = messages
    elif prompt:
        chat_messages = [{"role": "user", "content": prompt}]
    else:
        chat_messages = []

    # Extract as_text flag before merging options into body
    as_text = (options or {}).pop('as_text', None)
    body = {'model': model, 'messages': chat_messages}
    if options:
        body['options'] = options

    async with httpx.AsyncClient(timeout=None) as client:
        try:
            # If client explicitly asked for a stream, proxy the upstream stream
            if payload.get('stream', False):
                body['stream'] = True
                upstream = client.stream("POST", f"{OLLAMA_URL}/api/chat", json=body, headers={"Content-Type": "application/json"})
                async with upstream as r:
                    ct = r.headers.get('content-type', '')
                    if r.status_code == 200 and (ct.startswith('text/event-stream') or 'ndjson' in ct or r.headers.get('transfer-encoding') == 'chunked'):
                        async def generator():
                            try:
                                async for chunk in r.aiter_bytes():
                                    if chunk:
                                        yield chunk
                            except httpx.StreamClosed:
                                logging.info('Upstream stream closed while proxying (chat-stream)')
                                return
                            except Exception as e:
                                logging.exception('Unexpected error while streaming from upstream (chat-stream): %s', e)
                                return
                        return StreamingResponse(generator(), media_type=ct or 'text/plain')
                    body_bytes = await r.aread()
                    text = body_bytes.decode('utf-8', errors='ignore')
                    try:
                        return JSONResponse(status_code=r.status_code, content=r.json())
                    except Exception:
                        return Response(content=text, status_code=r.status_code, media_type=ct or 'text/plain')

            # Non-streaming: tell Ollama not to stream so we get a single JSON response
            body['stream'] = False
            r = await client.post(f"{OLLAMA_URL}/api/chat", json=body)
            raw = r.text

            # Ollama /api/chat returns {"message": {"role": "assistant", "content": "..."}}
            try:
                ollama_json = json.loads(raw)
                msg = ollama_json.get('message', {})
                response_text = msg.get('content', '') if isinstance(msg, dict) else ollama_json.get('response', raw)
            except Exception:
                # Fallback: aggregate NDJSON lines
                lines = [l.strip() for l in raw.splitlines() if l.strip()]
                parts = []
                for ln in lines:
                    try:
                        js = json.loads(ln)
                        if isinstance(js, dict):
                            msg = js.get('message', {})
                            if isinstance(msg, dict) and 'content' in msg:
                                parts.append(str(msg['content']))
                            elif 'response' in js:
                                parts.append(str(js['response']))
                            else:
                                parts.append(ln)
                        else:
                            parts.append(ln)
                    except Exception:
                        parts.append(ln)
                response_text = ''.join(parts)

            return Response(content=response_text, status_code=r.status_code, media_type='text/plain')
        except Exception as e:
            return JSONResponse(status_code=503, content={"error": "AI service unavailable", "detail": str(e)})


@app.post("/api/ai/embeddings")
async def embeddings(req: Request):
    _require_user(req)
    payload = await req.json()
    model = payload.get('model', 'text-embedding-3-small')
    input_ = payload.get('input')
    body = {'model': model, 'input': input_}

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            r = await client.post(f"{OLLAMA_URL}/api/embeddings", json=body)
            r.raise_for_status()
            return JSONResponse(status_code=r.status_code, content=r.json())
        except Exception as e:
            return JSONResponse(status_code=503, content={"error": "AI service unavailable", "detail": str(e)})


@app.get('/api/health')
async def root():
    health = {
        "ok": True,
        "proxied_to": OLLAMA_URL,
        "supabase": bool(SUPABASE_URL),
        "db_mode": "supabase" if db.using_db else "json_files",
        "campaigns_db": db._campaigns_use_db() if db.using_db else False,
        "jwt_verification": "jwks" if _jwks_client else ("hs256" if SUPABASE_JWT_SECRET else "none"),
        "smtp_configured": bool(SMTP_PASS),
        "auth_mode": "api_key" if API_KEY else ("jwt_only" if _jwks_client else "dev_mode"),
    }
    return health


# --- Email sending ----------------------------------------------------------------

class EmailRecipient(BaseModel):
    name: str
    email: str

class SendEmailRequest(BaseModel):
    subject: str
    body: str
    recipients: List[EmailRecipient]
    campaign_name: Optional[str] = None

class SendEmailResponse(BaseModel):
    ok: bool
    sent: int = 0
    failed: int = 0
    errors: List[str] = []


@app.get('/api/email/config')
async def email_config(req: Request):
    """Return current SMTP config (without password) so the frontend knows if it's set up."""
    _require_user(req)
    return JSONResponse(content={
        "configured": bool(SMTP_PASS),
        "smtp_host": SMTP_HOST,
        "smtp_user": SMTP_USER,
        "from_name": SMTP_FROM_NAME,
    })


@app.post('/api/email/send')
async def send_email(req: Request):
    _require_user(req)

    if not SMTP_PASS:
        raise HTTPException(
            status_code=400,
            detail="SMTP not configured. Set SMTP_PASS env variable with your Zoho App-Specific Password."
        )

    payload = await req.json()
    try:
        data = SendEmailRequest(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=str(e))

    if not data.recipients:
        raise HTTPException(status_code=400, detail="No recipients provided.")

    sent_count = 0
    fail_count = 0
    errors = []

    for recip in data.recipients:
        # Personalise subject & body with {{name}} placeholder
        personalised_subject = data.subject.replace('{{name}}', recip.name).replace('{{company}}', SMTP_FROM_NAME).replace('{{sender}}', SMTP_FROM_NAME)
        personalised_body = data.body.replace('{{name}}', recip.name).replace('{{company}}', SMTP_FROM_NAME).replace('{{sender}}', SMTP_FROM_NAME)

        msg = MIMEMultipart('alternative')
        msg['From'] = f"{SMTP_FROM_NAME} <{SMTP_USER}>"
        msg['To'] = recip.email
        msg['Subject'] = personalised_subject

        # Plain text version
        msg.attach(MIMEText(personalised_body, 'plain', 'utf-8'))

        # Simple HTML version (preserves line breaks, XSS-safe)
        html_body = _html.escape(personalised_body).replace('\n', '<br>')
        html_content = f"""<html><body style="font-family: 'Inter', Arial, sans-serif; color: #333; line-height: 1.6;">{html_body}</body></html>"""
        msg.attach(MIMEText(html_content, 'html', 'utf-8'))

        try:
            await aiosmtplib.send(
                msg,
                hostname=SMTP_HOST,
                port=SMTP_PORT,
                start_tls=True,
                username=SMTP_USER,
                password=SMTP_PASS,
            )
            sent_count += 1
            _audit_log({
                'action': 'email_sent',
                'to': recip.email,
                'subject': personalised_subject,
                'campaign': data.campaign_name,
            })
            logging.info(f"Email sent to {recip.email}")
        except Exception as e:
            fail_count += 1
            error_msg = f"{recip.email}: {str(e)}"
            errors.append(error_msg)
            logging.error(f"Failed to send email to {recip.email}: {e}")

    return JSONResponse(content={
        "ok": fail_count == 0,
        "sent": sent_count,
        "failed": fail_count,
        "errors": errors,
    })


@app.post('/api/email/test')
async def send_test_email(req: Request):
    """Send a single test email to the sender's own address."""
    _require_user(req)

    if not SMTP_PASS:
        raise HTTPException(
            status_code=400,
            detail="SMTP not configured. Set SMTP_PASS env variable."
        )

    msg = MIMEMultipart('alternative')
    msg['From'] = f"{SMTP_FROM_NAME} <{SMTP_USER}>"
    msg['To'] = SMTP_USER
    msg['Subject'] = 'ANIS CRM — Test Email'

    body = "This is a test email from ANIS CRM.\n\nIf you received this, your email configuration is working correctly!"
    msg.attach(MIMEText(body, 'plain', 'utf-8'))
    msg.attach(MIMEText(f'<html><body style="font-family: Inter, sans-serif;">{body.replace(chr(10), "<br>")}</body></html>', 'html', 'utf-8'))

    try:
        await aiosmtplib.send(
            msg,
            hostname=SMTP_HOST,
            port=SMTP_PORT,
            start_tls=True,
            username=SMTP_USER,
            password=SMTP_PASS,
        )
        return JSONResponse(content={"ok": True, "message": f"Test email sent to {SMTP_USER}"})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send test email: {str(e)}")

# --- Data storage now uses db module (Supabase or JSON fallback) ------------------
# Legacy aliases kept for any remaining direct references
from db import _load_json, _save_json, LEADS_FILE, NOTES_FILE, TASKS_FILE, \
    TEAM_ACTIVITIES_FILE, NOTIFICATIONS_FILE, CHAT_CHANNELS_FILE, CHAT_MESSAGES_FILE, \
    DATA_DIR

# --- Audit log helper -----------------------------------------------------------
LOG_DIR = Path(__file__).parent / 'logs'
LOG_DIR.mkdir(exist_ok=True)
AUDIT_FILE = LOG_DIR / 'audit.log'

def _audit_log(entry: dict):
    try:
        entry.setdefault('ts', datetime.utcnow().isoformat() + 'Z')
        with AUDIT_FILE.open('a', encoding='utf-8') as f:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')
    except Exception:
        pass


def crm_summary(max_leads: int = 0) -> str:
    """Build a compact CRM context string for the AI.
    Focuses on actionable leads to keep prompt size manageable.
    Results are cached for _CACHE_TTL seconds."""
    cache_key = f'crm_summary:{max_leads}'
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached
    leads = db.get_leads()
    # Flatten all activities for recent-activity display
    all_acts = db.get_all_activities()
    notes = [a for acts in all_acts.values() for a in acts]
    total = len(leads)

    # Status breakdown
    status_counts: dict[str, int] = {}
    campaign_counts: dict[str, int] = {}
    for l in leads:
        st = l.get('status', 'unknown')
        status_counts[st] = status_counts.get(st, 0) + 1
        camp = l.get('campaign') or l.get('source') or 'unknown'
        campaign_counts[camp] = campaign_counts.get(camp, 0) + 1

    s = [f"Total leads: {total}"]
    s.append("Status breakdown: " + ", ".join(f"{k}: {v}" for k, v in sorted(status_counts.items(), key=lambda x: -x[1])))
    if len(campaign_counts) <= 10:
        s.append("By campaign/source: " + ", ".join(f"{k}: {v}" for k, v in sorted(campaign_counts.items(), key=lambda x: -x[1])))

    # Only include ACTIONABLE leads (not all 114) to keep prompt short
    actionable = [l for l in leads if l.get('status') in ('interested', 'followUp', 'noAnswer')]
    fresh_sample = [l for l in leads if l.get('status') == 'fresh'][:10]  # first 10 fresh
    converted = [l for l in leads if l.get('status') == 'converted']
    not_interested = [l for l in leads if l.get('status') == 'notInterested']

    def _lead_line(l):
        parts = [l.get('name', '?')]
        if l.get('status'):  parts.append(f"status={l['status']}")
        if l.get('phone'):   parts.append(f"phone={l['phone']}")
        if l.get('email'):   parts.append(f"email={l['email']}")
        if l.get('campaign') or l.get('source'):
            parts.append(f"source={l.get('campaign') or l.get('source')}")
        if l.get('last_contacted_at'): parts.append(f"last_contacted={l['last_contacted_at']}")
        if l.get('next_followup_at'): parts.append(f"next_followup={l['next_followup_at']}")
        return f"- {', '.join(parts)}"

    if actionable:
        s.append(f"\nHot/Active leads ({len(actionable)}):")
        for l in actionable:
            s.append(_lead_line(l))

    if converted:
        s.append(f"\nConverted leads ({len(converted)}):")
        for l in converted:
            s.append(_lead_line(l))

    if not_interested:
        s.append(f"\nLost leads ({len(not_interested)}):")
        for l in not_interested:
            s.append(_lead_line(l))

    if fresh_sample:
        total_fresh = len([l for l in leads if l.get('status') == 'fresh'])
        s.append(f"\nFresh leads (showing 10 of {total_fresh}):")
        for l in fresh_sample:
            s.append(_lead_line(l))

    if notes:
        recent_notes = notes[-5:]
        s.append(f"\nRecent activity (last {len(recent_notes)} of {len(notes)} total):")
        for n in recent_notes:
            s.append(f"- [{n.get('lead_id')}] {n.get('author')}: {n.get('content')}")
    result = "\n".join(s)
    _cache_set(cache_key, result)
    return result


def _sales_analytics() -> str:
    """Compute sales analytics for the AI coach. Cached for _CACHE_TTL seconds."""
    cached = _cache_get('sales_analytics')
    if cached is not None:
        return cached
    leads = db.get_leads()
    notes = []
    if not db.using_db:
        notes = _load_json(NOTES_FILE)
    total = len(leads)
    if total == 0:
        return "No leads in CRM yet."

    from datetime import datetime, timedelta
    now = datetime.utcnow()
    today_str = now.strftime('%Y-%m-%d')
    week_ago = (now - timedelta(days=7)).isoformat() + 'Z'
    month_ago = (now - timedelta(days=30)).isoformat() + 'Z'

    # Funnel
    status_map = {}
    for l in leads:
        st = l.get('status', 'unknown')
        status_map.setdefault(st, []).append(l)

    converted = len(status_map.get('converted', []))
    interested = len(status_map.get('interested', []))
    follow_up = len(status_map.get('followUp', []))
    no_answer = len(status_map.get('noAnswer', []))
    fresh = len(status_map.get('fresh', []))
    closed = len(status_map.get('closed', []))
    not_interested = len(status_map.get('notInterested', []))

    conversion_rate = (converted / total * 100) if total > 0 else 0

    # Leads created this week / month
    created_this_week = sum(1 for l in leads if (l.get('created_at') or '') >= week_ago)
    created_this_month = sum(1 for l in leads if (l.get('created_at') or '') >= month_ago)

    # Stale leads (no contact in 3+ days, not converted/closed)
    three_days_ago = (now - timedelta(days=3)).isoformat() + 'Z'
    stale = []
    for l in leads:
        if l.get('status') in ('converted', 'closed', 'notInterested'):
            continue
        last = l.get('last_contacted_at') or l.get('last_contact') or l.get('created_at') or ''
        if last < three_days_ago:
            stale.append(l)

    # Follow-ups due today or overdue
    overdue_followups = []
    for l in leads:
        nf = l.get('next_followup_at', '')
        if nf and nf[:10] <= today_str and l.get('status') not in ('converted', 'closed'):
            overdue_followups.append(l)

    lines = [
        "=== SALES ANALYTICS ===",
        f"Total leads: {total}",
        f"Conversion rate: {conversion_rate:.1f}% ({converted}/{total})",
        f"Funnel: Fresh({fresh}) → Interested({interested}) → Follow-up({follow_up}) → Converted({converted})",
        f"No Answer: {no_answer} | Not Interested: {not_interested} | Closed: {closed}",
        f"New leads this week: {created_this_week} | This month: {created_this_month}",
        f"Stale leads (no contact 3+ days): {len(stale)}",
        f"Overdue/today follow-ups: {len(overdue_followups)}",
    ]

    if stale:
        lines.append("\nStale leads needing contact:")
        for l in stale[:15]:
            last = l.get('last_contacted_at') or l.get('created_at') or 'never'
            lines.append(f"  - {l.get('name')} ({l.get('status')}, last contact: {last}, phone: {l.get('phone', 'N/A')})")

    if overdue_followups:
        lines.append("\nOverdue follow-ups:")
        for l in overdue_followups[:10]:
            lines.append(f"  - {l.get('name')} (due: {l.get('next_followup_at')}, phone: {l.get('phone', 'N/A')})")

    # Activity stats
    if notes:
        week_notes = [n for n in notes if (n.get('created_at') or n.get('timestamp') or '') >= week_ago]
        lines.append(f"\nActivities this week: {len(week_notes)} | Total: {len(notes)}")

    result = "\n".join(lines)
    _cache_set('sales_analytics', result)
    return result


@app.get('/api/crm/summary')
async def get_crm_summary(req: Request):
    _require_user(req)
    return JSONResponse(content={"summary": crm_summary()})


# --- Tools safe execution ---------------------------------------------------------
ALLOWED_TOOLS = {'create_lead', 'update_lead', 'add_note'}

async def _execute_tool(tool: str, args: dict, actor: Optional[str] = None):
    record = {'tool': tool, 'args': args, 'actor': actor}
    if tool not in ALLOWED_TOOLS:
        record['result'] = {'ok': False, 'error': f"tool '{tool}' not allowed"}
        _audit_log(record)
        return record['result']

    if tool == 'create_lead':
        lead = {
            'name': args.get('name'),
            'contact': args.get('contact'),
            'status': args.get('status', 'prospect'),
            'owner': args.get('owner'),
            'last_contact': args.get('last_contact') or datetime.utcnow().isoformat() + 'Z',
            'notes': []
        }
        created = db.create_lead(lead)
        record['result'] = {'ok': True, 'lead': created}
        _audit_log(record)
        return record['result']

    if tool == 'update_lead':
        lid = args.get('id')
        updated = db.update_lead(lid, args.get('fields', {}))
        if updated:
            record['result'] = {'ok': True, 'lead': updated}
        else:
            record['result'] = {'ok': False, 'error': 'lead not found'}
        _audit_log(record)
        return record['result']

    if tool == 'add_note':
        note = {
            'lead_id': args.get('lead_id'),
            'author': args.get('author'),
            'content': args.get('content'),
        }
        created = db.create_activity(note)
        record['result'] = {'ok': True, 'note': created}
        _audit_log(record)
        return record['result']


@app.post('/api/ai/tools/{tool_name}')
async def tool_endpoint(tool_name: str, req: Request):
    _require_user(req)
    body = await req.json()
    actor = req.headers.get('x-user') or req.headers.get('x-api-key') or 'unknown'
    res = await _execute_tool(tool_name, body, actor=actor)
    return JSONResponse(content=res)


# --- Assistant: uses CRM context and can request tool execution ------------------
import re

def _extract_first_json_block(text: str) -> Optional[dict]:
    # Look for a JSON object between ```json ... ``` or the first {...}
    m = re.search(r"```json\s*({[\s\S]*?})\s*```", text)
    if not m:
        m = re.search(r"({[\s\S]*})", text)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except Exception:
        return None


@app.post('/api/ai/assistant')
async def assistant(req: Request):
    _require_user(req)
    payload = await req.json()
    model = payload.get('model', 'qwen2.5:7b')
    user_message = payload.get('message') or payload.get('prompt') or ''
    stream = payload.get('stream', False)

    analytics = _sales_analytics()
    crm_ctx = crm_summary()

    system_prompt = f"""You are **Anis**, an elite AI Sales Assistant, Mentor & Coach built into this CRM.
You serve **Tick & Talk** and its AI SaaS product **Speekr.ai**. Your job is to help the sales team close more deals, faster.

## THE BUSINESS — TICK & TALK
**Tagline:** "You'll Present, They'll Applaud."
**Mission:** We help people deliver presentations that audiences remember.
**Founded:** Egypt | **HQ:** El Zeini Tower, Maadi, Cairo, Egypt
**Phone:** (+20) 114-865-6011 | **Email:** info@tickandtalk.com
**Website:** tickandtalk.com | **AI Product:** speekr.ai

### Track Record
- 9+ rating from 5,000+ attendees
- 90% of customers come through recommendations
- 9 countries worldwide
- Official Casting Partner for **Shark Tank Egypt** (3 consecutive seasons)
- Partners include: Dell, L'Oréal, Falak, Empwr, Digmo, Doctor Online, Elmodeeer

### Team
- **Omar Hamada** — Commercial Head
- **Khaled Shaaban** — Operations Head
- **Mohamed Deiab** — Technology Head
- **Eman Emara** — Senior Designer

### Services (Training Courses)
1. **Presentation Masterclass** — An extensive 3-month transformational journey that turns you into a confident, charismatic presenter. (Our flagship program)
2. **Corporate Accelerator** — A 2-day personalized training program that boosts your team's presentation skills significantly. (For companies)
3. **Online Masterclass** — Transform into a charismatic presenter from anywhere, anytime, at your own pace. Virtual. (online-masterclass.tickandtalk.com)
4. **Presentation Bundle** — End-to-end presentation delivery: we story-tell your project, write the content, and design the slides. (Service, not training)

### Key Selling Points for Training Courses
- Proven track record with 5000+ people trained
- Recommended by 90% of past clients
- Real business impact: our presentations have closed $XM in sales for clients
- Shark Tank Egypt partnership adds massive credibility
- Not just theory — practical, hands-on, real-world presentation skills
- Bilingual delivery (English & Arabic)

## THE AI PRODUCT — SPEEKR.AI
**What it is:** AI-powered communication & soft-skills training platform
**Tagline:** "Build Confident Communication & Soft Skills"
**Website:** speekr.ai | **App:** app.speekr.ai

### What Speekr Does
- AI-powered roleplay conversations (like practicing with a real person)
- Solo practice for presentations, pitches, speeches with detailed feedback
- Instant science-based feedback on voice, body language, word choice
- Custom scenario & persona builder
- Guided learning journeys designed by international coaches
- Supports **English and Arabic** (including dialects)

### Speekr Pricing
| Plan | Price | Audience | Key Features |
|------|-------|----------|-------------|
| Speekr Starter | $23/mo | Individuals | 3 learning journeys, 3 AI roleplay/week, instant feedback |
| Speekr Pro Unlimited | $29/mo | Individuals | Full access, unlimited roleplay |
| Speekr Teams | $48/user/mo | Teams 3-15 | 5 AI roleplay/user/month, dashboards |
| Speekr Enterprise | Custom | Large orgs | Unlimited, custom everything, account manager |

### Key Selling Points for Speekr
- 96% user satisfaction rate
- Case study: L'Oréal — 100% sign-up rate, 85% engaged in active roleplay, 2x faster communication fluency
- 1000+ hours of combined training expertise baked into the AI
- Train sales teams, customer care, presenters — anyone people-facing
- Practice budget objection handling, cold calls, job interviews, sales conversations
- Private — only you can see your practice sessions
- Free trial available

## YOUR PERSONALITY
- You are a sharp, energetic, and motivating sales coach — like a mix between a best friend and a top sales director.
- You speak in a **bilingual** style: primarily English but naturally mix in Arabic (Egyptian dialect) when it feels right. Use Arabic for greetings, encouragement, and emotional emphasis. Example: "يلا نشتغل!", "ممتاز!", "تمام خالص", "ركز معايا".
- You celebrate wins enthusiastically and push through losses with resilience.
- Be direct, concise, and action-oriented. No fluff.

## YOUR SALES METHODOLOGY
You follow a **High-Velocity Sales** approach:
- Speed to lead: Contact fresh leads within minutes, not hours.
- Short sales cycles: 1-3 touches max for training courses, 3-5 for AI SaaS.
- Multi-channel: WhatsApp, phone calls, email — whatever gets the response.
- Always be closing: Every interaction should move the lead forward.
- Follow-up relentlessly: "The fortune is in the follow-up."

## YOUR CAPABILITIES

### 1. Lead Prioritization & Scoring
When asked about leads or priorities, analyze the CRM data and rank leads by urgency:
- 🔴 HOT: Interested leads with no recent follow-up, or overdue follow-ups
- 🟡 WARM: Fresh leads needing first contact, or noAnswer leads worth retrying
- 🟢 NURTURE: Leads in pipeline that need scheduled touches
- ⚫ DEAD: notInterested or closed leads (suggest win-back only if promising)
Always explain WHY a lead is prioritized.

### 2. Objection Handling Scripts
When asked about objections, provide ready-to-use scripts for common objections:
- "It's too expensive" → Value justification: "5000+ people trained, 90% recommend us, Shark Tank Egypt trusts us. The ROI is clear."
- "I need to think about it" → Urgency: "Spots fill fast — our last Masterclass sold out in 3 days. Let me hold your spot."
- "I'll call you back" → Lock it: "Perfect, when exactly? I'll send you a calendar invite right now."
- "I'm not interested" → Uncover real objection: "Totally understand. What specifically are you looking for? Many of our clients initially felt the same way."
- "Send me info on WhatsApp" → "Absolutely! I'll send you the details now. Can we also schedule a 5-min call tomorrow to answer any questions?"
- "We already have internal training" → "Great! Many of our corporate clients like Dell and L'Oréal use us to complement their existing programs. We bring a completely different methodology."
- For Speekr: "We don't need AI training tools" → "L'Oréal saw 2x faster communication fluency with Speekr. It doesn't replace training — it supercharges your team between sessions."
Tailor scripts to the specific product (Masterclass, Corporate Accelerator, Online Masterclass, Speekr). Include Arabic versions when helpful.

### 3. Call & Message Templates
Provide ready-to-send WhatsApp messages and call scripts for each lead stage:
- **Fresh Lead**: Introduction + mention Tick & Talk credibility (Shark Tank, 5000+ trained) + ask what they're looking for
- **No Answer**: Multiple follow-up variations (1st, 2nd, 3rd attempt) — keep it brief and valuable
- **Interested**: Share specific product details (Masterclass 3-month journey, Corporate Accelerator 2-day, Online Masterclass, or Speekr pricing) + urgency + booking
- **Follow-Up**: Check-in + share a success story or testimonial + close attempt
- **Win-back** (notInterested): New angle — e.g., offer Speekr free trial, or mention a new upcoming training batch
Always personalize templates using the lead's actual name and context from the CRM.
When writing templates, include both English and Arabic versions.

### 4. Daily Coaching & Morning Briefing
When asked for a briefing or coaching:
- Start with a motivational opener (mix English/Arabic)
- Show today's priorities: overdue follow-ups, hot leads, new leads
- Key metrics: conversion rate, pipeline health, activity level
- One actionable coaching tip for the day
- End with energy: "يلا نكسر الدنيا النهاردة! 💪"

### 5. Win/Loss Analysis
When asked about wins or losses:
- Analyze converted leads: What worked? What was the source/campaign?
- Analyze notInterested/closed leads: What went wrong? Time to contact? Number of touches?
- Provide actionable insights: "Your best conversions come from [X campaign], double down there."

### 6. Performance Tracking & Motivation
- Track conversion rates, response times, activity volume
- Compare this week vs last week when data allows
- Celebrate milestones: "You hit 3 conversions this month! 🎉 ده شغل عظيم!"
- Push through slumps: "Every 'no' gets you closer to the next 'yes'. يلا كمّل!"

## RESPONSE RULES
- NEVER output JSON, code blocks, markdown code fences, or tool call syntax.
- Give clean, human-readable responses with clear formatting (use bold, bullets, emojis).
- Use numbered lists for action items.
- Keep responses focused and under 400 words unless the user asks for detail.
- When giving templates, make them copy-paste ready.
- Always end with a clear next action or question.
- If you don't know something, say so briefly and suggest what data would help.
- ALWAYS reference Tick & Talk products by name (Masterclass, Corporate Accelerator, Online Masterclass, Speekr) — never give generic advice.
- When writing WhatsApp messages, personalize with the lead's actual name from the CRM data below.

## LIVE SALES ANALYTICS  
{analytics}

## LIVE CRM DATA (Actionable Leads)
{crm_ctx}
"""

    # Build conversation messages with history
    history = payload.get('history', [])
    messages = [{"role": "system", "content": system_prompt}]
    for h in history[-20:]:  # Keep last 20 messages for context
        role = h.get('role', 'user')
        content = h.get('content', '')
        if role in ('user', 'assistant') and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": user_message})

    body = {"model": model, "messages": messages,
            "options": {"num_ctx": 16384}}
    body.update(payload.get('options', {}))

    # Streaming: forward the raw model stream (useful for quick UI streaming)
    if stream:
        body['stream'] = True

        async def stream_generator():
            """Stream from Ollama and yield bytes. Client & response are kept alive
            until iteration completes because they are created *inside* the generator."""
            client = httpx.AsyncClient(timeout=None)
            try:
                resp = await client.send(
                    client.build_request("POST", f"{OLLAMA_URL}/api/chat", json=body,
                                         headers={"Content-Type": "application/json"}),
                    stream=True,
                )
                try:
                    async for chunk in resp.aiter_bytes():
                        if chunk:
                            yield chunk
                except httpx.StreamClosed:
                    logging.info('Upstream stream closed while proxying (assistant stream)')
                finally:
                    await resp.aclose()
            except httpx.HTTPError as e:
                error_payload = json.dumps({"response": f"Error: {e}"}) + "\n"
                yield error_payload.encode()
            except Exception as e:
                logging.exception('Unexpected error while streaming from upstream (assistant): %s', e)
                error_payload = json.dumps({"response": f"Error: {e}"}) + "\n"
                yield error_payload.encode()
            finally:
                await client.aclose()

        return StreamingResponse(stream_generator(), media_type='application/x-ndjson')

    # Non-streaming: tell Ollama not to stream, get a single JSON response
    body['stream'] = False
    async with httpx.AsyncClient(timeout=120) as client:
        try:
            r = await client.post(f"{OLLAMA_URL}/api/chat", json=body)
            raw = r.text

            # Ollama /api/chat returns {"message": {"role": "assistant", "content": "..."}}
            try:
                ollama_json = json.loads(raw)
                msg = ollama_json.get('message', {})
                response_text = msg.get('content', '') if isinstance(msg, dict) else ollama_json.get('response', raw)
            except Exception:
                # Fallback: aggregate NDJSON lines
                lines = [l.strip() for l in raw.splitlines() if l.strip()]
                parts = []
                for ln in lines:
                    try:
                        js2 = json.loads(ln)
                        if isinstance(js2, dict):
                            msg2 = js2.get('message', {})
                            if isinstance(msg2, dict) and 'content' in msg2:
                                parts.append(str(msg2['content']))
                            elif 'response' in js2:
                                parts.append(str(js2['response']))
                            else:
                                parts.append(ln)
                        else:
                            parts.append(ln)
                    except Exception:
                        parts.append(ln)
                response_text = ''.join(parts)

            # Try to parse a tool call from the response text
            js = _extract_first_json_block(response_text)
            if js and isinstance(js, dict) and 'tool' in js:
                # Do NOT auto-execute tools. Return assistant text and the parsed tool to the client
                # so the client can ask for confirmation.
                clean_text = re.sub(r"```json\s*({[\s\S]*?})\s*```", '', response_text).strip()
                clean_text = re.sub(r"({[\s\S]*})", '', clean_text).strip()
                return JSONResponse(content={"assistant": clean_text, "tool": js})

            return JSONResponse(content={"assistant": response_text})
        except httpx.HTTPError as e:
            raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# FACEBOOK LEAD ADS WEBHOOK
# =============================================================================
# Setup in Meta Developer portal:
#   1. Go to https://developers.facebook.com → your app → Webhooks
#   2. Subscribe to "leadgen" under Page subscriptions
#   3. Callback URL: https://<your-domain>/api/webhooks/facebook
#   4. Verify Token: same as FB_VERIFY_TOKEN above
#   5. Generate a Page Access Token with "leads_retrieval" permission
# =============================================================================

@app.get('/api/webhooks')
async def list_webhooks(req: Request):
    """List configured webhook integrations and their status."""
    _require_user(req)
    webhooks = [
        {
            'id': 'facebook',
            'name': 'Facebook Lead Ads',
            'url': '/api/webhooks/facebook',
            'enabled': bool(os.environ.get('FB_PAGE_ACCESS_TOKEN')),
        },
        {
            'id': 'whatsapp',
            'name': 'WhatsApp Business',
            'url': '/api/webhooks/whatsapp',
            'enabled': bool(os.environ.get('WA_TOKEN')),
        },
        {
            'id': 'zapier',
            'name': 'Zapier (Leads)',
            'url': '/api/webhooks/zapier',
            'enabled': bool(ZAPIER_API_KEY),
        },
        {
            'id': 'zapier_campaign',
            'name': 'Zapier (Campaigns)',
            'url': '/api/webhooks/zapier/campaign',
            'enabled': bool(ZAPIER_API_KEY),
        },
    ]
    return JSONResponse(content={'webhooks': webhooks})

@app.get('/api/webhooks/facebook')
async def facebook_webhook_verify(req: Request):
    """Facebook webhook verification (hub.challenge handshake)."""
    mode = req.query_params.get('hub.mode')
    token = req.query_params.get('hub.verify_token')
    challenge = req.query_params.get('hub.challenge')

    if mode == 'subscribe' and token == FB_VERIFY_TOKEN:
        logging.info('Facebook webhook verified successfully')
        return Response(content=challenge, media_type='text/plain')
    raise HTTPException(status_code=403, detail='Verification failed')


@app.post('/api/webhooks/facebook')
async def facebook_webhook_receive(req: Request):
    """
    Receive Facebook Lead Ads webhook events.
    When someone fills out a Lead Ad form on Facebook, Meta sends
    a leadgen event here. We fetch the full lead data using the
    Graph API and create a lead in the CRM automatically.
    """
    # Verify Meta webhook signature (X-Hub-Signature-256)
    if FB_APP_SECRET:
        raw_body = await req.body()
        sig_header = req.headers.get('x-hub-signature-256', '')
        expected = 'sha256=' + hmac.new(
            FB_APP_SECRET.encode(), raw_body, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(sig_header, expected):
            logging.warning('Facebook webhook signature mismatch — rejecting')
            raise HTTPException(status_code=403, detail='Invalid signature')
        payload = json.loads(raw_body)
    else:
        payload = await req.json()
    logging.info(f"Facebook webhook received: {json.dumps(payload, indent=2)}")

    leads_created = []

    if payload.get('object') == 'page':
        for entry in payload.get('entry', []):
            for change in entry.get('changes', []):
                if change.get('field') == 'leadgen':
                    leadgen_id = change.get('value', {}).get('leadgen_id')
                    if leadgen_id:
                        lead = await _fetch_facebook_lead(leadgen_id)
                        if lead:
                            leads_created.append(lead)

    _audit_log({'action': 'facebook_webhook', 'leads_created': len(leads_created)})
    return JSONResponse(content={"ok": True, "leads_created": len(leads_created)})


async def _fetch_facebook_lead(leadgen_id: str) -> Optional[dict]:
    """Fetch lead data from Facebook Graph API and create a CRM lead."""
    if not FB_PAGE_ACCESS_TOKEN:
        logging.warning('FB_PAGE_ACCESS_TOKEN not set, cannot fetch lead data')
        return None

    try:
        url = f"https://graph.facebook.com/v19.0/{leadgen_id}"
        params = {'access_token': FB_PAGE_ACCESS_TOKEN}

        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.get(url, params=params)
            r.raise_for_status()
            data = r.json()

        # Parse field_data from Facebook Lead form
        fields = {}
        for fd in data.get('field_data', []):
            name = fd.get('name', '').lower()
            values = fd.get('values', [])
            fields[name] = values[0] if values else ''

        # Map Facebook fields to CRM lead
        name = fields.get('full_name') or fields.get('first_name', '') + ' ' + fields.get('last_name', '')
        name = name.strip() or 'Facebook Lead'
        email = fields.get('email', '')
        phone = fields.get('phone_number') or fields.get('phone', '')

        # Determine campaign from the form name
        form_id = data.get('form_id', '')
        ad_name = fields.get('ad_name') or fields.get('campaign_name') or f'FB Lead Ad ({form_id})'

        # Create lead in CRM
        lead = db.create_lead({
            'name': name,
            'email': email,
            'phone': phone,
            'status': 'interested',
            'source': 'facebook',
            'campaign': ad_name,
            'last_contacted_at': None,
            'next_followup_at': None,
            'meta': {
                'leadgen_id': leadgen_id,
                'form_id': form_id,
                'platform': 'facebook_lead_ads',
                'raw_fields': fields,
            },
        })

        _audit_log({
            'action': 'facebook_lead_created',
            'lead_id': lead['id'],
            'name': name,
            'leadgen_id': leadgen_id,
        })
        logging.info(f"Facebook lead created: {name} ({lead['id']})")
        return lead

    except Exception as e:
        logging.error(f"Failed to fetch Facebook lead {leadgen_id}: {e}")
        _audit_log({'action': 'facebook_lead_error', 'leadgen_id': leadgen_id, 'error': str(e)})
        return None


# =============================================================================
# WHATSAPP CLOUD API WEBHOOK
# =============================================================================
# Setup in Meta Developer portal:
#   1. Go to https://developers.facebook.com → your app → WhatsApp → Configuration
#   2. Callback URL: https://<your-domain>/api/webhooks/whatsapp
#   3. Verify Token: same as WA_VERIFY_TOKEN above
#   4. Subscribe to "messages" webhook field
#   5. Get your WhatsApp Business Phone Number ID and permanent access token
# =============================================================================

@app.get('/api/webhooks/whatsapp')
async def whatsapp_webhook_verify(req: Request):
    """WhatsApp webhook verification (hub.challenge handshake)."""
    mode = req.query_params.get('hub.mode')
    token = req.query_params.get('hub.verify_token')
    challenge = req.query_params.get('hub.challenge')

    if mode == 'subscribe' and token == WA_VERIFY_TOKEN:
        logging.info('WhatsApp webhook verified successfully')
        return Response(content=challenge, media_type='text/plain')
    raise HTTPException(status_code=403, detail='Verification failed')


@app.post('/api/webhooks/whatsapp')
async def whatsapp_webhook_receive(req: Request):
    """
    Receive WhatsApp Cloud API webhook events.
    When someone sends a message to your WhatsApp Business number,
    Meta sends a notification here. We extract the sender info and
    create/update a lead in the CRM automatically.
    """
    # Verify Meta webhook signature (X-Hub-Signature-256)
    if FB_APP_SECRET:
        raw_body = await req.body()
        sig_header = req.headers.get('x-hub-signature-256', '')
        expected = 'sha256=' + hmac.new(
            FB_APP_SECRET.encode(), raw_body, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(sig_header, expected):
            logging.warning('WhatsApp webhook signature mismatch — rejecting')
            raise HTTPException(status_code=403, detail='Invalid signature')
        payload = json.loads(raw_body)
    else:
        payload = await req.json()
    logging.info(f"WhatsApp webhook received: {json.dumps(payload, indent=2)}")

    leads_created = 0
    messages_logged = 0

    if payload.get('object') == 'whatsapp_business_account':
        for entry in payload.get('entry', []):
            for change in entry.get('changes', []):
                value = change.get('value', {})
                contacts = value.get('contacts', [])
                messages = value.get('messages', [])

                # Build a quick lookup of contacts by wa_id
                contact_map = {}
                for c in contacts:
                    wa_id = c.get('wa_id', '')
                    contact_map[wa_id] = c

                for msg in messages:
                    sender_wa_id = msg.get('from', '')
                    contact_info = contact_map.get(sender_wa_id, {})
                    profile_name = contact_info.get('profile', {}).get('name', '')

                    # Extract message text
                    msg_type = msg.get('type', 'text')
                    msg_text = ''
                    if msg_type == 'text':
                        msg_text = msg.get('text', {}).get('body', '')
                    elif msg_type == 'button':
                        msg_text = msg.get('button', {}).get('text', '')
                    elif msg_type == 'interactive':
                        interactive = msg.get('interactive', {})
                        if interactive.get('type') == 'button_reply':
                            msg_text = interactive.get('button_reply', {}).get('title', '')
                        elif interactive.get('type') == 'list_reply':
                            msg_text = interactive.get('list_reply', {}).get('title', '')
                    else:
                        msg_text = f'[{msg_type}]'

                    # Create or find existing lead
                    lead = _find_or_create_whatsapp_lead(
                        wa_id=sender_wa_id,
                        name=profile_name,
                        message=msg_text,
                    )
                    if lead.get('_created'):
                        leads_created += 1

                    # Log the message as a note
                    db.create_activity({
                        'lead_id': lead['id'],
                        'author': 'WhatsApp',
                        'content': f"[WhatsApp] {profile_name}: {msg_text}",
                    })
                    messages_logged += 1

    _audit_log({
        'action': 'whatsapp_webhook',
        'leads_created': leads_created,
        'messages_logged': messages_logged,
    })
    return JSONResponse(content={"ok": True, "leads_created": leads_created, "messages_logged": messages_logged})


def _find_or_create_whatsapp_lead(wa_id: str, name: str, message: str) -> dict:
    """Find an existing lead by WhatsApp ID or phone, or create a new one."""
    leads = db.get_leads()

    # Normalize phone for matching (strip + prefix)
    normalized = wa_id.lstrip('+')

    # Check if lead already exists
    for lead in leads:
        lead_phone = (lead.get('phone') or '').replace('+', '').replace(' ', '').replace('-', '')
        lead_wa_id = (lead.get('meta', {}) or {}).get('wa_id', '')
        if lead_wa_id == wa_id or (lead_phone and lead_phone == normalized):
            # Update last contact time
            db.update_lead(lead['id'], {
                'last_contacted_at': datetime.utcnow().isoformat() + 'Z',
            })
            lead['_created'] = False
            return lead

    # Create new lead
    phone_display = f"+{normalized}" if not wa_id.startswith('+') else wa_id
    lead = db.create_lead({
        'name': name or f'WhatsApp {phone_display}',
        'phone': phone_display,
        'email': '',
        'status': 'interested',
        'source': 'whatsapp',
        'campaign': 'WhatsApp Inbound',
        'last_contacted_at': datetime.utcnow().isoformat() + 'Z',
        'next_followup_at': None,
        'meta': {
            'wa_id': wa_id,
            'platform': 'whatsapp_cloud_api',
            'first_message': message,
        },
    })

    _audit_log({
        'action': 'whatsapp_lead_created',
        'lead_id': lead['id'],
        'name': name,
        'wa_id': wa_id,
    })
    logging.info(f"WhatsApp lead created: {name or wa_id} ({lead['id']})")
    lead['_created'] = True
    return lead


# =============================================================================
# WHATSAPP – SEND MESSAGE (outbound)
# =============================================================================

@app.post('/api/whatsapp/send')
async def whatsapp_send_message(req: Request):
    """Send a WhatsApp message via Cloud API."""
    _require_user(req)

    if not WA_ACCESS_TOKEN or not WA_PHONE_NUMBER_ID:
        raise HTTPException(status_code=400, detail='WhatsApp not configured. Set WA_ACCESS_TOKEN and WA_PHONE_NUMBER_ID.')

    payload = await req.json()
    to = payload.get('to', '').replace('+', '').replace(' ', '').replace('-', '')
    message = payload.get('message', '')

    if not to or not message:
        raise HTTPException(status_code=400, detail='Missing "to" or "message" field.')

    url = f"https://graph.facebook.com/v19.0/{WA_PHONE_NUMBER_ID}/messages"
    headers = {
        'Authorization': f'Bearer {WA_ACCESS_TOKEN}',
        'Content-Type': 'application/json',
    }
    body = {
        'messaging_product': 'whatsapp',
        'to': to,
        'type': 'text',
        'text': {'body': message},
    }

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            r = await client.post(url, json=body, headers=headers)
            data = r.json()
            if r.status_code in (200, 201):
                _audit_log({'action': 'whatsapp_message_sent', 'to': to})
                return JSONResponse(content={"ok": True, "response": data})
            else:
                logging.error(f"WhatsApp send failed: {data}")
                return JSONResponse(status_code=r.status_code, content={"ok": False, "error": data})
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# ZAPIER WEBHOOK
# =============================================================================
# Zapier sends lead data to this endpoint via a simple POST with API key auth.
# In Zapier, create a "Webhooks by Zapier" action pointing to:
#   POST https://<your-domain>/api/webhooks/zapier
#   Header: X-API-Key: <your-zapier-api-key>
# =============================================================================

@app.post('/api/webhooks/zapier')
async def zapier_webhook_receive(req: Request):
    """
    Receive leads from Zapier.
    Accepts a JSON payload with lead fields.  Supports single lead
    (object) or batch (array of objects).
    Authentication via X-API-Key header.
    """
    # --- Authenticate via API key ---
    api_key = req.headers.get('x-api-key', '')
    if not ZAPIER_API_KEY or not api_key:
        raise HTTPException(status_code=401, detail='Missing API key')
    if not hmac.compare_digest(api_key, ZAPIER_API_KEY):
        raise HTTPException(status_code=403, detail='Invalid API key')

    payload = await req.json()
    logging.info(f"Zapier webhook received: {json.dumps(payload, indent=2)}")

    # Normalise: accept a single object or a list of objects
    items = payload if isinstance(payload, list) else [payload]
    leads_created = []

    for item in items:
        name = (item.get('name') or item.get('full_name') or '').strip()
        if not name:
            first = (item.get('first_name') or '').strip()
            last = (item.get('last_name') or '').strip()
            name = f"{first} {last}".strip()
        if not name:
            name = 'Zapier Lead'

        lead = db.create_lead({
            'name': name,
            'email': (item.get('email') or '').strip(),
            'phone': (item.get('phone') or item.get('phone_number') or '').strip(),
            'status': item.get('status', 'fresh'),
            'source': item.get('source', 'zapier'),
            'campaign': (item.get('campaign') or '').strip() or None,
            'company': (item.get('company') or '').strip() or None,
            'country': (item.get('country') or 'egypt').strip(),
            'deal_value': float(item['deal_value']) if item.get('deal_value') else 0,
            'notes': (item.get('notes') or '').strip() or None,
            'last_contacted_at': None,
            'next_followup_at': None,
            'meta': {
                'platform': 'zapier',
                'raw_payload': item,
            },
        })
        leads_created.append(lead)
        logging.info(f"Zapier lead created: {name} ({lead['id']})")

    _audit_log({'action': 'zapier_webhook', 'leads_created': len(leads_created)})
    return JSONResponse(content={
        "ok": True,
        "leads_created": len(leads_created),
        "lead_ids": [l['id'] for l in leads_created],
    })


# =============================================================================
# ZAPIER CAMPAIGN WEBHOOK – create / update campaigns from Zapier
# =============================================================================
# In Zapier, add a "Webhooks by Zapier" → POST action:
#   URL:     https://<your-domain>/api/webhooks/zapier/campaign
#   Header:  X-API-Key: <ZAPIER_API_KEY>
#   Body (JSON):
#     {
#       "name":        "Spring Sale 2025",
#       "description": "Facebook + WhatsApp spring promo",
#       "market":      "egypt",          // egypt | saudi_arabia | all
#       "budget":      5000,
#       "status":      "active",         // active | paused | completed
#       "start_date":  "2025-03-01",
#       "end_date":    "2025-03-31"      // optional
#     }
#
# To UPDATE an existing campaign, include "id" in the payload.
# If "id" is provided and found, the campaign is updated; otherwise created.

@app.post('/api/webhooks/zapier/campaign')
async def zapier_campaign_webhook(req: Request):
    """
    Create or update campaigns via Zapier.
    Accepts a single campaign object or a list.
    Authentication via X-API-Key header (same key as the leads webhook).
    """
    api_key = req.headers.get('x-api-key', '')
    if not ZAPIER_API_KEY or not api_key:
        raise HTTPException(status_code=401, detail='Missing API key')
    if not hmac.compare_digest(api_key, ZAPIER_API_KEY):
        raise HTTPException(status_code=403, detail='Invalid API key')

    payload = await req.json()
    logging.info(f"Zapier campaign webhook received: {json.dumps(payload, indent=2)}")

    items = payload if isinstance(payload, list) else [payload]
    results = []

    for item in items:
        name = (item.get('name') or '').strip()
        if not name:
            raise HTTPException(status_code=422, detail="'name' field is required for each campaign")

        campaign_id = (item.get('id') or '').strip() or None

        data = {
            'name': name,
            'description': (item.get('description') or '').strip(),
            'market': (item.get('market') or 'egypt').strip(),
            'budget': float(item['budget']) if item.get('budget') is not None else 0.0,
            'status': (item.get('status') or 'active').strip(),
            'meta': {'platform': 'zapier', 'raw_payload': item},
        }
        if item.get('start_date'):
            data['start_date'] = item['start_date']
        if item.get('end_date'):
            data['end_date'] = item['end_date']

        if campaign_id:
            # Update existing campaign if it exists, otherwise create
            existing = db.get_campaign(campaign_id)
            if existing:
                campaign = db.update_campaign(campaign_id, data)
                action = 'updated'
            else:
                data['id'] = campaign_id
                campaign = db.create_campaign(data)
                action = 'created'
        else:
            campaign = db.create_campaign(data)
            action = 'created'

        results.append({'id': campaign['id'], 'name': campaign['name'], 'action': action})
        logging.info(f"Zapier campaign {action}: {campaign['name']} ({campaign['id']})")

    _audit_log({'action': 'zapier_campaign_webhook', 'campaigns_processed': len(results)})
    return JSONResponse(content={
        'ok': True,
        'campaigns_processed': len(results),
        'campaigns': results,
    })

INTEGRATION_CONFIG_FILE = DATA_DIR / 'integration_config.json'

def _load_integration_config() -> dict:
    try:
        if INTEGRATION_CONFIG_FILE.exists():
            with INTEGRATION_CONFIG_FILE.open('r', encoding='utf-8') as f:
                return json.load(f)
    except Exception:
        pass
    return {}

def _save_integration_config(config: dict):
    with INTEGRATION_CONFIG_FILE.open('w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

def _apply_integration_config():
    """Load saved integration config and apply to module-level variables."""
    global FB_VERIFY_TOKEN, FB_PAGE_ACCESS_TOKEN, WA_VERIFY_TOKEN, WA_PHONE_NUMBER_ID, WA_ACCESS_TOKEN, ZAPIER_API_KEY
    config = _load_integration_config()
    if config.get('fb_verify_token'):
        FB_VERIFY_TOKEN = config['fb_verify_token']
    if config.get('fb_page_access_token'):
        FB_PAGE_ACCESS_TOKEN = config['fb_page_access_token']
    if config.get('wa_verify_token'):
        WA_VERIFY_TOKEN = config['wa_verify_token']
    if config.get('wa_phone_number_id'):
        WA_PHONE_NUMBER_ID = config['wa_phone_number_id']
    if config.get('wa_access_token'):
        WA_ACCESS_TOKEN = config['wa_access_token']
    if config.get('zapier_api_key'):
        ZAPIER_API_KEY = config['zapier_api_key']

# Apply on startup
_apply_integration_config()


@app.get('/api/integrations/config')
async def get_integration_config(req: Request):
    """Return current integration config (tokens masked)."""
    _require_user(req)

    def _mask(s: str) -> str:
        if not s or len(s) < 8:
            return '••••' if s else ''
        return s[:4] + '••••' + s[-4:]

    return JSONResponse(content={
        'facebook': {
            'configured': bool(FB_PAGE_ACCESS_TOKEN),
            'verify_token': FB_VERIFY_TOKEN,
            'page_access_token': _mask(FB_PAGE_ACCESS_TOKEN),
            'webhook_url': '/api/webhooks/facebook',
        },
        'whatsapp': {
            'configured': bool(WA_ACCESS_TOKEN and WA_PHONE_NUMBER_ID),
            'verify_token': WA_VERIFY_TOKEN,
            'phone_number_id': WA_PHONE_NUMBER_ID,
            'access_token': _mask(WA_ACCESS_TOKEN),
            'webhook_url': '/api/webhooks/whatsapp',
        },
        'zapier': {
            'configured': bool(ZAPIER_API_KEY),
            'api_key': _mask(ZAPIER_API_KEY),
            'webhook_url': '/api/webhooks/zapier',
        },
    })


@app.post('/api/integrations/config')
async def set_integration_config(req: Request):
    """Update integration config (Facebook / WhatsApp tokens) at runtime."""
    _require_account_exec(req)

    payload = await req.json()
    config = _load_integration_config()

    # Facebook config
    fb = payload.get('facebook', {})
    if fb.get('verify_token'):
        config['fb_verify_token'] = fb['verify_token']
    if fb.get('page_access_token'):
        config['fb_page_access_token'] = fb['page_access_token']

    # WhatsApp config
    wa = payload.get('whatsapp', {})
    if wa.get('verify_token'):
        config['wa_verify_token'] = wa['verify_token']
    if wa.get('phone_number_id'):
        config['wa_phone_number_id'] = wa['phone_number_id']
    if wa.get('access_token'):
        config['wa_access_token'] = wa['access_token']

    # Zapier config
    zap = payload.get('zapier', {})
    if zap.get('api_key'):
        config['zapier_api_key'] = zap['api_key']

    _save_integration_config(config)
    _apply_integration_config()

    _audit_log({'action': 'integration_config_updated', 'keys': list(payload.keys())})
    return JSONResponse(content={"ok": True, "message": "Integration config updated"})


@app.get('/api/integrations/status')
async def integration_status(req: Request):
    """Quick status check for all integrations."""
    _require_user(req)

    # Count leads by source
    leads = db.get_leads()
    fb_leads = sum(1 for l in leads if (l.get('source') or '') == 'facebook')
    wa_leads = sum(1 for l in leads if (l.get('source') or '') == 'whatsapp')
    zap_leads = sum(1 for l in leads if (l.get('source') or '') == 'zapier')

    # Count campaigns created via Zapier (those with zapier meta or from webhook audit)
    all_campaigns = db.get_campaigns()
    zap_campaigns = sum(1 for c in all_campaigns if (c.get('meta') or {}).get('platform') == 'zapier')

    return JSONResponse(content={
        'facebook': {
            'connected': bool(FB_PAGE_ACCESS_TOKEN),
            'leads_count': fb_leads,
        },
        'whatsapp': {
            'connected': bool(WA_ACCESS_TOKEN and WA_PHONE_NUMBER_ID),
            'leads_count': wa_leads,
        },
        'zapier': {
            'connected': bool(ZAPIER_API_KEY),
            'leads_count': zap_leads,
            'campaigns_count': zap_campaigns,
        },
    })


@app.get('/api/leads')
async def get_leads(req: Request, limit: int = 0, offset: int = 0):
    """Return leads with optional pagination."""
    _require_user(req)
    # Enforce sane pagination bounds
    MAX_PAGE = 500
    if limit <= 0 or limit > MAX_PAGE:
        limit = MAX_PAGE
    offset = max(0, offset)
    leads = db.get_leads(limit=limit, offset=offset)
    total = db.get_leads_count()
    for l in leads:
        l.pop('_created', None)
    return JSONResponse(content={"leads": leads, "total": total})


@app.get('/api/leads/{lead_id}')
async def get_lead(lead_id: str, req: Request):
    """Return a single lead by ID."""
    _require_user(req)
    lead = db.get_lead(lead_id)
    if not lead:
        raise HTTPException(status_code=404, detail='Lead not found')
    lead.pop('_created', None)
    return JSONResponse(content=lead)


@app.post('/api/leads')
async def create_lead_api(req: Request):
    """Create a new lead via REST."""
    _require_user(req)
    payload = await req.json()
    try:
        validated = LeadCreate(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f'Validation error: {e}')
    lead = db.create_lead(validated.model_dump(exclude_none=True))
    _audit_log({'action': 'lead_created', 'lead_id': lead['id']})
    return JSONResponse(status_code=201, content=lead)


@app.put('/api/leads/{lead_id}')
async def update_lead_api(lead_id: str, req: Request):
    """Update a lead by ID."""
    _require_user(req)
    payload = await req.json()
    try:
        validated = LeadUpdate(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f'Validation error: {e}')
    lead = db.update_lead(lead_id, validated.model_dump(exclude_none=True))
    if not lead:
        raise HTTPException(status_code=404, detail='Lead not found')
    _audit_log({'action': 'lead_updated', 'lead_id': lead_id})
    return JSONResponse(content=lead)


@app.delete('/api/leads/{lead_id}')
async def delete_lead_api(lead_id: str, req: Request):
    """Delete a lead by ID."""
    _require_user(req)
    lead = db.get_lead(lead_id)
    if not lead:
        raise HTTPException(status_code=404, detail='Lead not found')
    db.delete_lead(lead_id)
    _audit_log({'action': 'lead_deleted', 'lead_id': lead_id})
    return JSONResponse(content={"ok": True})


@app.post('/api/leads/import')
async def import_leads_api(req: Request):
    """Bulk import leads. Expects {"leads": [...]}."""
    _require_account_exec(req)
    payload = await req.json()
    incoming = payload.get('leads', [])
    if not incoming:
        raise HTTPException(status_code=400, detail='No leads provided')
    added = db.import_leads(incoming)
    total = db.get_leads_count()
    _audit_log({'action': 'leads_imported', 'count': added})
    return JSONResponse(content={"ok": True, "imported": added, "total": total})


@app.post('/api/leads/bulk-update')
async def bulk_update_leads(req: Request):
    """Update multiple leads at once. Expects {"ids": [...], "fields": {...}}."""
    _require_account_exec(req)
    payload = await req.json()
    ids = payload.get('ids', [])
    fields = payload.get('fields', {})
    if not ids or not fields:
        raise HTTPException(status_code=400, detail='ids and fields required')
    updated = 0
    for lid in ids:
        result = db.update_lead(lid, dict(fields))  # copy to avoid mutation
        if result:
            updated += 1
    _audit_log({'action': 'leads_bulk_updated', 'count': updated, 'fields': list(fields.keys())})
    return JSONResponse(content={"ok": True, "updated": updated})


@app.post('/api/leads/bulk-delete')
async def bulk_delete_leads(req: Request):
    """Delete multiple leads at once. Expects {"ids": [...]}."""
    _require_account_exec(req)
    payload = await req.json()
    ids = payload.get('ids', [])
    if not ids:
        raise HTTPException(status_code=400, detail='No ids provided')
    deleted = 0
    for lid in ids:
        try:
            db.delete_lead(lid)
            deleted += 1
        except Exception:
            pass
    _audit_log({'action': 'leads_bulk_deleted', 'count': deleted})
    return JSONResponse(content={"ok": True, "deleted": deleted})


# =============================================================================
# ACTIVITIES / NOTES REST API
# =============================================================================

@app.get('/api/activities/{lead_id}')
async def get_activities(lead_id: str, req: Request):
    """Return all notes/activities for a specific lead."""
    _require_user(req)
    lead_notes = db.get_activities(lead_id)
    return JSONResponse(content={"activities": lead_notes})


@app.post('/api/activities')
async def create_activity(req: Request):
    """Create a new activity / note."""
    _require_user(req)
    payload = await req.json()
    try:
        validated = ActivityCreate(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f'Validation error: {e}')
    note = db.create_activity(validated.model_dump(exclude_none=True))
    _audit_log({'action': 'activity_created', 'note_id': note['id'], 'lead_id': note.get('lead_id')})
    return JSONResponse(status_code=201, content=note)


@app.get('/api/activities')
async def get_all_activities(req: Request):
    """Return all activities grouped by lead_id."""
    _require_user(req)
    grouped = db.get_all_activities()
    return JSONResponse(content={"activities": grouped})


# =============================================================================
# COLLABORATION: TEAM ACTIVITY FEED
# =============================================================================

def _post_team_activity(user: dict, action: str, target_type: str,
                        target_id: str = '', target_name: str = '',
                        detail: str = ''):
    """Helper to append a team activity entry — delegates to db layer."""
    try:
        return db.post_team_activity(user, action, target_type,
                                     target_id, target_name, detail)
    except Exception as e:
        logging.debug(f'Team activity post failed (table may not exist): {e}')
        return {}


@app.get('/api/team-activities')
async def get_team_activities(req: Request, limit: int = 50, offset: int = 0):
    user = _require_user(req)
    page, total = db.get_team_activities(limit=limit, offset=offset)
    return JSONResponse(content={'activities': page, 'total': total})


# =============================================================================
# COLLABORATION: NOTIFICATIONS
# =============================================================================

def _create_notification(user_id: str, notif_type: str, title: str,
                         body: str = '', action_url: str = '',
                         from_user_id: str = '', from_user_name: str = ''):
    """Helper to create a notification — delegates to db layer."""
    try:
        return db.create_notification(user_id, notif_type, title, body,
                                      action_url, from_user_id, from_user_name)
    except Exception as e:
        logging.debug(f'Notification creation failed (table may not exist): {e}')
        return {}


@app.get('/api/notifications')
async def get_notifications(req: Request, limit: int = 50):
    user = _require_user(req)
    mine, unread = db.get_notifications(user['id'], limit=limit)
    return JSONResponse(content={
        'notifications': mine,
        'unread_count': unread,
    })


@app.put('/api/notifications/{notif_id}/read')
async def mark_notification_read(notif_id: str, req: Request):
    user = _require_user(req)
    db.mark_notification_read(notif_id, user['id'])
    return JSONResponse(content={'ok': True})


@app.put('/api/notifications/read-all')
async def mark_all_notifications_read(req: Request):
    user = _require_user(req)
    db.mark_all_notifications_read(user['id'])
    return JSONResponse(content={'ok': True})


# =============================================================================
# COLLABORATION: LEAD ASSIGNMENT & TEAM NOTES
# =============================================================================

@app.put('/api/leads/{lead_id}/assign')
async def assign_lead(lead_id: str, req: Request):
    user = _require_user(req)
    payload = await req.json()
    assigned_to_id = payload.get('assigned_to_id', '')
    assigned_to_name = payload.get('assigned_to_name', '')
    lead = db.assign_lead(lead_id, assigned_to_id, assigned_to_name)
    if not lead:
        raise HTTPException(status_code=404, detail='Lead not found')
    # Post activity
    _post_team_activity(user, 'assigned_lead', 'lead', lead_id,
                        lead.get('name', ''),
                        f"Assigned to {assigned_to_name}")
    # Notify assignee
    if assigned_to_id and assigned_to_id != user['id']:
        _create_notification(assigned_to_id, 'lead_assigned',
                             'New lead assigned to you',
                             f"{user['name']} assigned {lead.get('name', '')} to you",
                             f"/app/lead/{lead_id}",
                             user['id'], user['name'])
    _audit_log({'action': 'lead_assigned', 'lead_id': lead_id,
                'assigned_to': assigned_to_id, 'by': user['id']})
    return JSONResponse(content={'ok': True, 'lead': lead})


@app.get('/api/leads/{lead_id}/team-notes')
async def get_lead_team_notes(lead_id: str, req: Request):
    user = _require_user(req)
    lead_notes = db.get_team_notes(lead_id)
    return JSONResponse(content={'notes': lead_notes})


@app.post('/api/leads/{lead_id}/team-notes')
async def add_lead_team_note(lead_id: str, req: Request):
    user = _require_user(req)
    payload = await req.json()
    note = db.create_activity({
        'lead_id': lead_id,
        'type': 'team_note',
        'author': user['name'],
        'author_id': user['id'],
        'content': payload.get('content', ''),
    })
    # Get lead name for activity
    lead = db.get_lead(lead_id)
    lead_name = lead.get('name', '') if lead else ''
    _post_team_activity(user, 'added_note', 'lead', lead_id, lead_name,
                        payload.get('content', '')[:80])
    return JSONResponse(status_code=201, content=note)


# =============================================================================
# COLLABORATION: TASK MANAGEMENT
# =============================================================================

@app.get('/api/tasks')
async def get_tasks(req: Request, assigned_to: str = '', status: str = '',
                    limit: int = 0, offset: int = 0):
    user = _require_user(req)
    tasks = db.get_tasks(assigned_to=assigned_to, status=status,
                         limit=limit, offset=offset)
    return JSONResponse(content={'tasks': tasks})


@app.post('/api/tasks')
async def create_task(req: Request):
    user = _require_user(req)
    payload = await req.json()
    task = db.create_task({
        'title': payload.get('title', ''),
        'description': payload.get('description', ''),
        'status': payload.get('status', 'todo'),
        'priority': payload.get('priority', 'medium'),
        'assigned_to': payload.get('assigned_to', ''),
        'assigned_to_name': payload.get('assigned_to_name', ''),
        'created_by': user['id'],
        'created_by_name': user['name'],
        'lead_id': payload.get('lead_id', ''),
        'lead_name': payload.get('lead_name', ''),
        'due_date': payload.get('due_date', ''),
    })
    _post_team_activity(user, 'created_task', 'task', task['id'], task['title'])
    if task.get('assigned_to') and task['assigned_to'] != user['id']:
        _create_notification(task['assigned_to'], 'task_assigned',
                             'New task assigned to you',
                             f"{user['name']} assigned '{task['title']}' to you",
                             '', user['id'], user['name'])
    _audit_log({'action': 'task_created', 'task_id': task['id'], 'by': user['id']})
    return JSONResponse(status_code=201, content=task)


@app.put('/api/tasks/{task_id}')
async def update_task(task_id: str, req: Request):
    user = _require_user(req)
    payload = await req.json()
    task = db.update_task(task_id, payload)
    if not task:
        raise HTTPException(status_code=404, detail='Task not found')
    if 'status' in payload:
        old_status = task.get('_old_status', '')
        if payload['status'] != old_status:
            _post_team_activity(user, f"moved_task_{payload['status']}",
                                'task', task_id, task.get('title', ''),
                                f"Status: {old_status} → {payload['status']}")
    task.pop('_old_status', None)
    return JSONResponse(content=task)


@app.delete('/api/tasks/{task_id}')
async def delete_task(task_id: str, req: Request):
    user = _require_user(req)
    task = db.delete_task(task_id)
    if task:
        _post_team_activity(user, 'deleted_task', 'task', task_id,
                            task.get('title', ''))
    return JSONResponse(content={'ok': True})


# =============================================================================
# COLLABORATION: TEAM CHAT
# =============================================================================

@app.get('/api/chat/channels')
async def get_chat_channels(req: Request):
    user = _require_user(req)
    channels = db.get_chat_channels(user['id'])
    return JSONResponse(content={'channels': channels})


@app.post('/api/chat/channels')
async def create_chat_channel(req: Request):
    user = _require_user(req)
    payload = await req.json()
    channel = db.create_chat_channel(payload, user['id'])
    return JSONResponse(status_code=201, content=channel)


@app.get('/api/chat/channels/{channel_id}/messages')
async def get_channel_messages(channel_id: str, req: Request, limit: int = 100):
    user = _require_user(req)
    messages = db.get_chat_messages(channel_id, limit=limit)
    return JSONResponse(content={'messages': messages})


@app.post('/api/chat/channels/{channel_id}/messages')
async def send_chat_message(channel_id: str, req: Request):
    user = _require_user(req)
    payload = await req.json()
    msg = db.send_chat_message(channel_id, user['id'], user['name'],
                               payload.get('text', ''))
    # Notify other members
    channel = db.get_chat_channel(channel_id)
    if channel:
        for mid in channel.get('member_ids', []):
            if mid != user['id']:
                _create_notification(mid, 'chat_message',
                                     f"New message from {user['name']}",
                                     msg['text'][:80],
                                     '', user['id'], user['name'])
    return JSONResponse(status_code=201, content=msg)


# Ensure a "General" channel exists on startup
try:
    db.ensure_general_channel()
except Exception as e:
    logging.warning('Could not ensure General channel (migration may not be applied yet): %s', e)


# =============================================================================
# COLLABORATION: LEADERBOARD
# =============================================================================

@app.get('/api/leaderboard')
async def get_leaderboard(req: Request):
    user = _require_user(req)
    leads = db.get_leads()
    notes = db.get_leads()  # activities for counting
    tasks = db.get_tasks()
    # Re-fetch activities for accurate counting
    try:
        all_activities = db.get_all_activities()
        notes = [a for acts in all_activities.values() for a in acts]
    except Exception:
        notes = []
    # Get all users from Supabase
    users_data = []
    if _supabase_admin:
        try:
            all_users = _supabase_admin.auth.admin.list_users()
            for u in all_users:
                meta = getattr(u, 'user_metadata', {}) or {}
                uid = str(u.id)
                # Count assigned leads
                assigned_leads = sum(1 for l in leads if l.get('assigned_to') == uid)
                converted_leads = sum(1 for l in leads
                                      if l.get('assigned_to') == uid
                                      and l.get('status') == 'converted')
                # Count activities
                user_activities = sum(1 for n in notes if n.get('author_id') == uid)
                # Count completed tasks
                completed_tasks = sum(1 for t in tasks
                                      if t.get('assigned_to') == uid
                                      and t.get('status') == 'done')
                total_tasks = sum(1 for t in tasks if t.get('assigned_to') == uid)
                # Score = converted*10 + activities*2 + completed_tasks*5 + assigned*1
                score = converted_leads * 10 + user_activities * 2 + completed_tasks * 5 + assigned_leads
                users_data.append({
                    'id': uid,
                    'name': meta.get('name', (u.email or '').split('@')[0]),
                    'email': u.email or '',
                    'role': meta.get('role', ROLE_CAMPAIGN_EXEC),
                    'avatar_url': meta.get('avatar_url', ''),
                    'assigned_leads': assigned_leads,
                    'converted_leads': converted_leads,
                    'activities_count': user_activities,
                    'completed_tasks': completed_tasks,
                    'total_tasks': total_tasks,
                    'score': score,
                    'monthly_lead_target': meta.get('monthly_lead_target', 0),
                    'monthly_deal_target': meta.get('monthly_deal_target', 0),
                    'monthly_revenue_target': meta.get('monthly_revenue_target', 0),
                })
        except Exception as e:
            logging.error(f"Leaderboard error: {e}")
    users_data.sort(key=lambda u: u['score'], reverse=True)
    # Add rank
    for i, u in enumerate(users_data):
        u['rank'] = i + 1
    return JSONResponse(content={'leaderboard': users_data})


# =============================================================================
# DEALS / REVENUE PIPELINE
# =============================================================================

@app.get('/api/deals')
async def get_deals(req: Request, limit: int = 0, offset: int = 0):
    _require_user(req)
    deals = db.get_deals(limit=limit, offset=offset)
    return JSONResponse(content={'deals': deals})


@app.post('/api/deals')
async def create_deal(req: Request):
    user = _require_user(req)
    payload = await req.json()
    try:
        validated = DealCreate(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f'Validation error: {e}')
    try:
        deal = db.create_deal(validated.model_dump(exclude_none=True))
    except Exception as e:
        logging.error(f'Failed to create deal: {e}')
        raise HTTPException(status_code=500, detail=f'Failed to create deal: {e}')
    try:
        _post_team_activity(user, 'created_deal', 'deal', deal['id'],
                            deal.get('title', ''),
                            f"Value: {deal.get('value', 0)}")
    except Exception as e:
        logging.warning(f'Team activity post failed (deal still created): {e}')
    _audit_log({'action': 'deal_created', 'deal_id': deal['id'], 'by': user['id']})
    return JSONResponse(status_code=201, content=deal)


@app.put('/api/deals/{deal_id}')
async def update_deal(deal_id: str, req: Request):
    user = _require_user(req)
    payload = await req.json()
    deal = db.update_deal(deal_id, payload)
    if not deal:
        raise HTTPException(status_code=404, detail='Deal not found')
    if 'stage' in payload:
        _post_team_activity(user, 'updated_deal_stage', 'deal', deal_id,
                            deal.get('title', ''),
                            f"Stage → {payload['stage']}")
    _audit_log({'action': 'deal_updated', 'deal_id': deal_id, 'by': user['id']})
    return JSONResponse(content=deal)


@app.delete('/api/deals/{deal_id}')
async def delete_deal(deal_id: str, req: Request):
    user = _require_user(req)
    db.delete_deal(deal_id)
    _audit_log({'action': 'deal_deleted', 'deal_id': deal_id, 'by': user['id']})
    return JSONResponse(content={'ok': True})


@app.get('/api/deals/forecast')
async def get_revenue_forecast(req: Request):
    _require_user(req)
    forecast = db.get_revenue_forecast()
    return JSONResponse(content=forecast)


# =============================================================================
# GLOBAL SEARCH
# =============================================================================

@app.get('/api/search')
async def global_search(req: Request, q: str = ''):
    _require_user(req)
    if not q or len(q) < 2:
        return JSONResponse(content={'leads': [], 'tasks': [], 'deals': [], 'activities': []})
    results = db.search(q)
    return JSONResponse(content=results)


# =============================================================================
# REPORTS
# =============================================================================

@app.get('/api/reports/{report_type}')
async def get_report(report_type: str, req: Request):
    _require_user(req)
    if report_type not in ('overview', 'leads', 'revenue'):
        raise HTTPException(status_code=400, detail='Invalid report type')
    data = db.get_report_data(report_type)
    return JSONResponse(content=data)


# =============================================================================
# AUTOMATION RULES
# =============================================================================

@app.get('/api/automation/rules')
async def get_automation_rules(req: Request):
    _require_user(req)
    rules = db.get_automation_rules()
    return JSONResponse(content={'rules': rules})


@app.post('/api/automation/rules')
async def create_automation_rule(req: Request):
    user = _require_user(req)
    payload = await req.json()
    rule = db.create_automation_rule(payload)
    _audit_log({'action': 'automation_rule_created', 'rule_id': rule['id'], 'by': user['id']})
    return JSONResponse(status_code=201, content=rule)


@app.put('/api/automation/rules/{rule_id}')
async def update_automation_rule(rule_id: str, req: Request):
    user = _require_user(req)
    payload = await req.json()
    rule = db.update_automation_rule(rule_id, payload)
    if not rule:
        raise HTTPException(status_code=404, detail='Rule not found')
    _audit_log({'action': 'automation_rule_updated', 'rule_id': rule_id, 'by': user['id']})
    return JSONResponse(content=rule)


@app.delete('/api/automation/rules/{rule_id}')
async def delete_automation_rule(rule_id: str, req: Request):
    user = _require_user(req)
    db.delete_automation_rule(rule_id)
    _audit_log({'action': 'automation_rule_deleted', 'rule_id': rule_id, 'by': user['id']})
    return JSONResponse(content={'ok': True})


@app.post('/api/automation/evaluate')
async def evaluate_automation(req: Request):
    """Evaluate automation rules for a given trigger and context."""
    _require_user(req)
    payload = await req.json()
    trigger = payload.get('trigger', '')
    ctx = payload.get('context', {})
    rules = db.get_automation_rules()
    executed = []
    for rule in rules:
        if not rule.get('enabled', True):
            continue
        if rule.get('trigger') != trigger:
            continue
        # Check conditions
        conditions = rule.get('conditions', {})
        match = True
        for k, v in conditions.items():
            if ctx.get(k) != v:
                match = False
                break
        if not match:
            continue
        # Execute action
        action = rule.get('action', '')
        params = rule.get('action_params', {})
        try:
            if action == 'assignLead' and ctx.get('lead_id'):
                db.assign_lead(ctx['lead_id'],
                               params.get('assign_to', ''),
                               params.get('assign_to_name', ''))
            elif action == 'changeStatus' and ctx.get('lead_id'):
                db.update_lead(ctx['lead_id'], {'status': params.get('status', 'fresh')})
            elif action == 'createTask':
                db.create_task({
                    'title': params.get('task_title', 'Auto-created task'),
                    'status': 'todo',
                    'priority': 'medium',
                    'lead_id': ctx.get('lead_id', ''),
                    'lead_name': ctx.get('lead_name', ''),
                    'created_by': 'automation',
                    'created_by_name': f'Rule: {rule.get("name", "")}',
                })
            elif action == 'sendNotification':
                user_id = ctx.get('assigned_to') or ctx.get('owner_id', '')
                if user_id:
                    db.create_notification(user_id, 'automation',
                                           f'Automation: {rule.get("name", "")}',
                                           params.get('message', ''))
            executed.append({'rule_id': rule['id'], 'rule_name': rule.get('name', ''), 'action': action})
        except Exception as e:
            logging.error(f'Automation rule {rule["id"]} failed: {e}')
    return JSONResponse(content={'executed': executed, 'count': len(executed)})


# =============================================================================
# CUSTOM FIELDS
# =============================================================================

@app.get('/api/custom-fields')
async def get_custom_fields(req: Request):
    _require_user(req)
    fields = db.get_custom_fields()
    return JSONResponse(content=fields)


@app.post('/api/custom-fields')
async def create_custom_field(req: Request):
    user = _require_user(req)
    payload = await req.json()
    field = db.create_custom_field(payload)
    _audit_log({'action': 'custom_field_created', 'field_id': field['id'], 'by': user['id']})
    return JSONResponse(status_code=201, content=field)


@app.delete('/api/custom-fields/{field_id}')
async def delete_custom_field(field_id: str, req: Request):
    user = _require_user(req)
    db.delete_custom_field(field_id)
    _audit_log({'action': 'custom_field_deleted', 'field_id': field_id, 'by': user['id']})
    return JSONResponse(content={'ok': True})


# =============================================================================
# CAMPAIGNS
# =============================================================================

@app.get('/api/campaigns')
async def get_campaigns(req: Request, market: str = ''):
    """Return all campaigns, optionally filtered by market."""
    _require_user(req)
    campaigns = db.get_campaigns(market=market)
    return JSONResponse(content={"campaigns": campaigns})


@app.get('/api/campaigns/{campaign_id}')
async def get_campaign(campaign_id: str, req: Request):
    """Return a single campaign by ID."""
    _require_user(req)
    c = db.get_campaign(campaign_id)
    if not c:
        raise HTTPException(status_code=404, detail='Campaign not found')
    return JSONResponse(content=c)


@app.post('/api/campaigns')
async def create_campaign_api(req: Request):
    """Create a new campaign."""
    _require_user(req)
    payload = await req.json()
    try:
        validated = CampaignCreate(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f'Validation error: {e}')
    data = validated.model_dump(exclude_none=True)
    campaign = db.create_campaign(data)
    _audit_log({'action': 'campaign_created', 'campaign_id': campaign['id']})
    return JSONResponse(status_code=201, content=campaign)


@app.put('/api/campaigns/{campaign_id}')
async def update_campaign_api(campaign_id: str, req: Request):
    """Update a campaign by ID."""
    _require_user(req)
    payload = await req.json()
    try:
        validated = CampaignUpdate(**payload)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f'Validation error: {e}')
    campaign = db.update_campaign(campaign_id, validated.model_dump(exclude_none=True))
    if not campaign:
        raise HTTPException(status_code=404, detail='Campaign not found')
    _audit_log({'action': 'campaign_updated', 'campaign_id': campaign_id})
    return JSONResponse(content=campaign)


@app.delete('/api/campaigns/{campaign_id}')
async def delete_campaign_api(campaign_id: str, req: Request):
    """Delete a campaign by ID."""
    _require_user(req)
    c = db.get_campaign(campaign_id)
    if not c:
        raise HTTPException(status_code=404, detail='Campaign not found')
    db.delete_campaign(campaign_id)
    _audit_log({'action': 'campaign_deleted', 'campaign_id': campaign_id})
    return JSONResponse(content={"ok": True})


# ── Serve Flutter web build (SPA catch-all — must be last) ──
_WEB_DIR = Path(__file__).parent.parent / 'build' / 'web'

@app.get('/{full_path:path}')
async def serve_flutter(full_path: str):
    if not _WEB_DIR.exists():
        return JSONResponse({'error': 'Not found'}, status_code=404)
    target = _WEB_DIR / full_path
    _no_cache = {'Cache-Control': 'no-cache, no-store, must-revalidate', 'Pragma': 'no-cache', 'Expires': '0'}
    if target.is_file():
        return FileResponse(str(target), headers=_no_cache)
    # SPA fallback — let Flutter router handle it
    return FileResponse(str(_WEB_DIR / 'index.html'), headers=_no_cache)
