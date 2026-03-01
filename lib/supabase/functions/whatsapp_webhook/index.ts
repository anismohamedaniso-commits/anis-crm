// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, GET, OPTIONS",
  "access-control-max-age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // server side for webhook

// NOTE: In config.toml for this function, set verify_jwt = false because Meta won't send a Supabase JWT

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  // GET verification for Meta webhook setup
  if (req.method === "GET") {
    const url = new URL(req.url);
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    if (mode === "subscribe" && token && challenge) {
      // You may want to validate token; here we just echo challenge
      return new Response(challenge, { status: 200, headers: CORS_HEADERS });
    }
    return new Response("not verified", { status: 403, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...CORS_HEADERS, "content-type": "application/json" } });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const payload = await req.json();

    const entries: any[] = Array.isArray(payload?.entry) ? payload.entry : [];
    for (const entry of entries) {
      const changes: any[] = Array.isArray(entry?.changes) ? entry.changes : [];
      for (const ch of changes) {
        const value: any = ch?.value || {};
        const messages: any[] = Array.isArray(value?.messages) ? value.messages : [];
        for (const m of messages) {
          const fromPhone = String(m.from || "");
          const text = String(m.text?.body || m.button?.text || "");
          if (!fromPhone || !text) continue;

          // Determine lead_id by looking up last outbound/inbound message to that phone
          const { data: prev } = await supabase.from("messages").select("lead_id").eq("phone", fromPhone).order("created_at", { ascending: false }).limit(1);
          const leadId = prev && prev.length > 0 ? String(prev[0].lead_id) : null;

          await supabase.from("messages").insert({
            lead_id: leadId,
            phone: fromPhone,
            channel: "whatsapp",
            direction: "incoming",
            text,
            status: "delivered",
            external_id: String(m.id || ""),
          });
        }
      }
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }
});
