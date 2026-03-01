// supabase/functions/whatsapp_send/index.ts
// Sends WhatsApp messages via Meta WhatsApp Cloud API
// CORS enabled. Expects JSON: { to: "+15551234567", text: "Hello" }

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

interface SendBody { to?: string; text?: string }

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } });

  try {
    const { to, text } = (await req.json()) as SendBody;
    if (!to || !text) {
      return new Response(JSON.stringify({ error: 'Missing `to` or `text`' }), { status: 400, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } });
    }

    const token = Deno.env.get('WHATSAPP_TOKEN');
    const phoneId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');
    if (!token || !phoneId) {
      return new Response(JSON.stringify({ error: 'Server not configured' }), { status: 500, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } });
    }

    const payload = {
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body: text },
    };

    const url = `https://graph.facebook.com/v20.0/${phoneId}/messages`;
    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(payload),
    });

    const data = await resp.json();
    if (!resp.ok) {
      return new Response(JSON.stringify({ error: 'WhatsApp API error', details: data }), { status: 400, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } });
    }

    return new Response(JSON.stringify({ ok: true, data }), { status: 200, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Unexpected server error', message: String(e) }), { status: 500, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } });
  }
});
