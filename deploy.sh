#!/bin/bash
# ─────────────────────────────────────────────────────────
#  Anis CRM — Production Build Script
#  Usage: ./deploy.sh <BACKEND_URL>
#  Example: ./deploy.sh https://anis-crm-api.up.railway.app
#
#  After running this, upload the build/web/ folder to:
#    Netlify → netlify.com/drop  (drag & drop)
#    Vercel  → npx vercel build/web
# ─────────────────────────────────────────────────────────

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="$HOME/flutter/bin/flutter"

# ── Read from .env ────────────────────────────────────────
ENV_FILE="$DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  ENV_FILE="$DIR/server/.env"
fi
if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env file not found. Copy .env.example → .env and fill in values."
  exit 1
fi

SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
BACKEND_URL="${1:-}"

if [ -z "$BACKEND_URL" ]; then
  # Try to read from env if provided there
  BACKEND_URL=$(grep '^API_BASE_URL=' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
fi

if [ -z "$BACKEND_URL" ]; then
  echo "❌  Backend URL required."
  echo "    Usage: ./deploy.sh https://your-backend.up.railway.app"
  exit 1
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "❌  SUPABASE_ANON_KEY missing from .env"
  exit 1
fi

echo "======================================"
echo "  Anis CRM — Production Build"
echo "======================================"
echo "  Backend URL: $BACKEND_URL"
echo ""

# ── Build Flutter web ─────────────────────────────────────
echo "▶ Building Flutter web..."
cd "$DIR"
export PATH="$PATH:$HOME/flutter/bin"

"$FLUTTER" build web --release \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=API_BASE_URL="$BACKEND_URL"

echo ""
echo "✅ Build complete → build/web/"
echo ""
echo "Next steps:"
echo ""
echo "  Option A — Netlify (free, instant):"
echo "    1. Go to netlify.com/drop"
echo "    2. Drag the 'build/web' folder onto the page"
echo "    3. Done — you'll get a URL like https://yourapp.netlify.app"
echo ""
echo "  Option B — Vercel:"
echo "    cd build/web && npx vercel --prod"
echo ""
echo "  Option C — Firebase Hosting:"
echo "    firebase init hosting  (set public dir to build/web)"
echo "    firebase deploy"
echo ""
