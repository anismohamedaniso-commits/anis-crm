// supabase/functions/ingest_lead/index.ts
// Generic Lead Ingestion webhook for social campaigns (Facebook, LinkedIn, TikTok, Zapier/Make, website forms)
// - Validates a shared secret
// - Optionally handles Facebook Lead Ads verification challenge
// - Normalizes payload and inserts into 'leads' table

// CORS per Dreamflow guidelines
const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret, x-provider",
  "access-control-allow-methods": "POST, GET, OPTIONS",
  "access-control-max-age": "86400",
};

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("LEAD_WEBHOOK_SECRET") ?? "";
const FB_VERIFY_TOKEN = Deno.env.get("FACEBOOK_VERIFY_TOKEN") ?? "";
const FB_PAGE_ACCESS_TOKEN = Deno.env.get("FACEBOOK_PAGE_ACCESS_TOKEN") ?? ""; // optional, used to fetch lead details

const supabase = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false } });
const DEFAULT_LEAD_OWNER_USER_ID = Deno.env.get("DEFAULT_LEAD_OWNER_USER_ID") ?? "";

// Helper: JSON response with CORS
const json = (status: number, data: unknown) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", ...CORS_HEADERS } });

// Helper: try parse date string
const safeDate = (v: unknown): string | null => {
  if (typeof v === "string") {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d.toISOString();
  }
  return null;
};

// Normalize incoming payloads to a common shape
interface NormalizedLead {
  name: string;
  email?: string;
  phone?: string;
  source?: string; // facebook | instagram | linkedin | tiktok | web | manual | etc.
  campaign?: string;
  status?: string; // interested | followUp | noAnswer | notInterested | closed
  created_at?: string; // ISO
}

async function normalizeFromFacebook(body: any): Promise<NormalizedLead | null> {
  // Two possibilities:
  // 1) Raw webhook with leadgen_id, we need to fetch details via Graph API
  // 2) Already normalized payload from a tool (Zapier/Make) where fields are present
  if (body && typeof body === "object") {
    if (body.leadgen_id && FB_PAGE_ACCESS_TOKEN) {
      try {
        const leadId = String(body.leadgen_id);
        const url = `https://graph.facebook.com/v20.0/${leadId}?access_token=${FB_PAGE_ACCESS_TOKEN}`;
        const r = await fetch(url);
        if (!r.ok) {
          const t = await r.text();
          console.error("FB fetch error", r.status, t);
          return null;
        }
        const fb = await r.json();
        // fb.field_data is an array of { name: 'full_name' | 'email' | 'phone_number' | <custom>, values: [string] }
        const field = (key: string) => {
          const f = (fb.field_data || []).find((x: any) => String(x.name).toLowerCase() === key);
          const v = f?.values?.[0];
          return typeof v === "string" ? v : undefined;
        };
        const name = field("full_name") || field("name") || "";
        const email = field("email");
        const phone = field("phone_number") || field("phone");
        const campaign = body.campaign || body.campaign_name || undefined;
        return { name, email, phone, source: "facebook", campaign };
      } catch (e) {
        console.error("normalizeFromFacebook error", e);
        return null;
      }
    }
    // Normalized case
    const name = body.name || body.full_name || "";
    const email = body.email;
    const phone = body.phone || body.phone_number;
    const campaign = body.campaign || body.campaign_name;
    return { name, email, phone, source: "facebook", campaign } as NormalizedLead;
  }
  return null;
}

async function normalizeGeneric(body: any, provider?: string): Promise<NormalizedLead | null> {
  if (!body || typeof body !== "object") return null;
  const name = body.name || body.full_name || "";
  const email = body.email;
  const phone = body.phone || body.phone_number;
  const status = body.status;
  const campaign = body.campaign || body.campaign_name || body.utm_campaign;
  const created_at = safeDate(body.created_at) ?? undefined;
  const source = provider || body.source || body.platform;
  return { name, email, phone, status, campaign, created_at, source } as NormalizedLead;
}

async function insertLead(n: NormalizedLead) {
  // Map to DB columns. Table: leads
  const payload: Record<string, unknown> = {
    name: n.name,
    email: n.email ?? null,
    phone: n.phone ?? null,
    source: (n.source || "web").toString(),
    campaign: n.campaign ?? null,
    status: (n.status || "interested").toString(),
    created_at: n.created_at ? new Date(n.created_at).toISOString() : new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  if (DEFAULT_LEAD_OWNER_USER_ID) payload["user_id"] = DEFAULT_LEAD_OWNER_USER_ID;
  const { data, error } = await supabase.from("leads").insert(payload).select().single();
  if (error) throw error;
  return data;
}

function getUrl(req: Request) {
  try {
    return new URL(req.url);
  } catch {
    // Cloud runtime always provides full URL; fallback for safety
    return new URL("http://localhost");
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const url = getUrl(req);
  const method = req.method.toUpperCase();

  if (method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });

  // Facebook verification challenge (GET)
  if (method === "GET" && url.searchParams.get("hub.mode") === "subscribe") {
    const verify = url.searchParams.get("hub.verify_token") ?? "";
    const challenge = url.searchParams.get("hub.challenge") ?? "";
    if (FB_VERIFY_TOKEN && verify === FB_VERIFY_TOKEN) {
      return new Response(challenge, { status: 200, headers: { "content-type": "text/plain", ...CORS_HEADERS } });
    }
    return json(403, { error: "Invalid verify token" });
  }

  // Secret validation for POST
  const providedSecret = req.headers.get("x-webhook-secret") ?? url.searchParams.get("secret") ?? "";
  if (!WEBHOOK_SECRET || providedSecret !== WEBHOOK_SECRET) return json(401, { error: "Unauthorized" });

  let body: any = {};
  try {
    const contentType = req.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      body = await req.json();
    } else if (contentType.includes("application/x-www-form-urlencoded")) {
      const form = await req.formData();
      form.forEach((v, k) => (body[k] = v));
    } else {
      // Try json as default
      body = await req.json();
    }
  } catch (_) {
    // ignore, keep empty object
  }

  const provider = (req.headers.get("x-provider") || url.searchParams.get("provider") || body.provider || "generic").toString().toLowerCase();

  try {
    let norm: NormalizedLead | null = null;
    if (provider === "facebook") norm = await normalizeFromFacebook(body);
    else norm = await normalizeGeneric(body, provider);

    if (!norm || !norm.name || String(norm.name).trim().length === 0) return json(400, { error: "Missing lead name" });

    const inserted = await insertLead(norm);
    return json(200, { ok: true, provider, lead: inserted });
  } catch (e) {
    console.error("ingest_lead error", e);
    const details = e instanceof Error ? e.message : String(e);
    return json(500, { error: "Internal error", details });
  }
});
