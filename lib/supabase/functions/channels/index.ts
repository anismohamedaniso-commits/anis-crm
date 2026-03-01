// supabase/functions/channels/index.ts
// Manage per-user channel connection statuses: WhatsApp, Instagram, Facebook, Website forms, Email
// - GET: return current user's channel connections
// - POST: upsert a connection { provider: string, connected: boolean, details?: object }
//
// ALWAYS include CORS headers per Dreamflow guidelines
// Requires Authorization: Bearer <JWT> from Supabase Auth (verify_jwt default enabled)

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-max-age": "86400",
};

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const json = (status: number, data: unknown) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", ...CORS_HEADERS } });

function getBearer(req: Request): string | null {
  const h = req.headers.get("authorization") || req.headers.get("Authorization");
  if (!h) return null;
  const [scheme, token] = h.split(" ");
  if (!scheme || !token || scheme.toLowerCase() !== "bearer") return null;
  return token.trim();
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });

  const jwt = getBearer(req);
  if (!jwt) return json(401, { error: "Missing Authorization bearer" });

  const supabase = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: `Bearer ${jwt}` } } });

  // Get current user
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) return json(401, { error: "Invalid or expired token" });

  if (req.method === "GET") {
    const { data, error } = await supabase
      .from("channel_connections")
      .select("id, provider, connected, details, created_at, updated_at")
      .eq("user_id", user.id)
      .order("provider", { ascending: true });
    if (error) return json(500, { error: error.message });
    return json(200, { ok: true, channels: data || [] });
  }

  if (req.method === "POST") {
    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {}

    const provider = String(body.provider || "").toLowerCase();
    const connected = Boolean(body.connected);
    const details = body.details && typeof body.details === "object" ? body.details : null;

    if (!provider) return json(400, { error: "Missing provider" });
    const allowed = ["whatsapp", "instagram", "facebook", "webforms", "email", "website", "web"];
    if (!allowed.includes(provider)) return json(400, { error: "Unsupported provider" });

    const normalized = provider === "website" || provider === "web" ? "webforms" : provider;

    const now = new Date().toISOString();

    // Upsert by (user_id, provider)
    const { data, error } = await supabase
      .from("channel_connections")
      .upsert(
        [
          {
            user_id: user.id,
            provider: normalized,
            connected,
            details,
            updated_at: now,
          },
        ],
        { onConflict: "user_id,provider" }
      )
      .select("id, provider, connected, details, created_at, updated_at")
      .single();

    if (error) return json(500, { error: error.message });
    return json(200, { ok: true, channel: data });
  }

  return json(405, { error: "Method not allowed" });
});
