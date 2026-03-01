-- ============================================================================
-- Migration v3: Deals, Automation Rules, Custom Fields
-- Run in Supabase SQL Editor after migration_v2
-- ============================================================================

-- ── DEALS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deals (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL DEFAULT '',
    lead_id     TEXT REFERENCES leads(id) ON DELETE SET NULL,
    lead_name   TEXT DEFAULT '',
    stage       TEXT NOT NULL DEFAULT 'qualified'
                CHECK (stage IN ('qualified','proposal','negotiation','won','lost')),
    value       DOUBLE PRECISION DEFAULT 0,
    currency    TEXT DEFAULT 'USD',
    expected_close_date TEXT DEFAULT '',
    owner_id    TEXT DEFAULT '',
    owner_name  TEXT DEFAULT '',
    notes       TEXT DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "deals_all" ON deals FOR ALL USING (true) WITH CHECK (true);

-- ── AUTOMATION RULES ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS automation_rules (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL DEFAULT '',
    enabled         BOOLEAN DEFAULT TRUE,
    trigger         TEXT NOT NULL DEFAULT 'leadCreated',
    conditions      JSONB DEFAULT '{}',
    action          TEXT NOT NULL DEFAULT 'assignLead',
    action_params   JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE automation_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "automation_rules_all" ON automation_rules FOR ALL USING (true) WITH CHECK (true);

-- ── CUSTOM FIELDS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS custom_fields (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL DEFAULT '',
    field_type  TEXT NOT NULL DEFAULT 'text'
                CHECK (field_type IN ('text','number','date','select')),
    options     JSONB DEFAULT '[]',
    required    BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE custom_fields ENABLE ROW LEVEL SECURITY;
CREATE POLICY "custom_fields_all" ON custom_fields FOR ALL USING (true) WITH CHECK (true);

-- ── INDEXES ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_deals_stage      ON deals(stage);
CREATE INDEX IF NOT EXISTS idx_deals_lead_id    ON deals(lead_id);
CREATE INDEX IF NOT EXISTS idx_deals_owner_id   ON deals(owner_id);
CREATE INDEX IF NOT EXISTS idx_automation_trigger ON automation_rules(trigger);
