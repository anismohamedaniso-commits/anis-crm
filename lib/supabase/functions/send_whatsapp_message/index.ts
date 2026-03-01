// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_CLOUD_ACCESS_TOKEN")!;
const WHATSAPP_PHONE_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID")!;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...CORS_HEADERS, "content-type": "application/json" } });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const body = await req.json();
    const leadId = String(body.lead_id || "");
    const toPhone = String(body.to_phone || "");
    const text = String(body.text || "").trim();

    if (!leadId || !toPhone || !text) {
      return new Response(JSON.stringify({ error: "Missing lead_id, to_phone or text" }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    // Insert a provisional outgoing message with status 'sending'
    const inserting = {
      lead_id: leadId,
      phone: toPhone,
      channel: "whatsapp",
      direction: "outgoing",
      text,
      status: "sending",
    } as const;

    const { data: inserted, error: insertErr } = await supabase.from("messages").insert(inserting).select("*").single();
    if (insertErr) throw insertErr;

    // Call WhatsApp Cloud API
    const waResp = await fetch(`https://graph.facebook.com/v19.0/${WHATSAPP_PHONE_ID}/messages`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${WHATSAPP_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to: toPhone,
        type: "text",
        text: { body: text },
      }),
    });

    const waJson: any = await waResp.json().catch(() => ({}));

    if (!waResp.ok) {
      // Update to failed
      await supabase.from("messages").update({ status: "failed" }).eq("id", inserted.id);
      return new Response(JSON.stringify({ error: "WhatsApp send failed", details: waJson }), { status: waResp.status || 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    const externalId = Array.isArray(waJson?.messages) && waJson.messages[0]?.id ? String(waJson.messages[0].id) : null;

    const { data: updated, error: upErr } = await supabase
      .from("messages")
      .update({ status: "sent", external_id: externalId })
      .eq("id", inserted.id)
      .select("*")
      .single();
    if (upErr) throw upErr;

    return new Response(JSON.stringify({ message: updated }), { status: 200, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }
});
