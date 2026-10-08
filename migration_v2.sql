-- ============================================================================
-- Migration v2 — Agricultural filtering / recommendation assistant
-- Target: existing PostgreSQL database
-- Run order: sections 1 → 2 → 3
-- (Adjust table names "SaleItem", "Sale", "Customer" if yours differ in case)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) CHANGES TO EXISTING TABLES
-- ----------------------------------------------------------------------------

-- 1a. Dosage is NOT a property of a product: it depends on crop + disease +
--     phase. Move dosage to the recommendation table (section 2).
--     Option A (recommended): remove it.
ALTER TABLE product DROP COLUMN dosage;

--     Option B (instead of A): keep it only as a non-binding reference and
--     make sure the app NEVER shows it as a recommendation:
-- ALTER TABLE product RENAME COLUMN dosage TO default_dosage;


-- 1b. Protect sales history: deleting a product must never wipe sale lines.
--     Find your current constraint name first:  \d "SaleItem"
-- ALTER TABLE "SaleItem" DROP CONSTRAINT <existing_fk_name>;
-- ALTER TABLE "SaleItem"
--   ADD CONSTRAINT saleitem_product_fk
--   FOREIGN KEY (productId) REFERENCES product(id)
--   ON DELETE RESTRICT ON UPDATE CASCADE;


-- 1c. If "deadline" is the expiry date (rok na upotreba), make sure it is a DATE:
-- ALTER TABLE product ALTER COLUMN deadline TYPE DATE USING deadline::date;
--     If "deadline" actually means KARENCA (waiting days before harvest) and it
--     differs per crop/disease, it belongs on recommendation instead:
-- ALTER TABLE product DROP COLUMN deadline;
-- ALTER TABLE recommendation ADD COLUMN karenca_days INTEGER;


-- ----------------------------------------------------------------------------
-- 2) NEW TABLES
-- ----------------------------------------------------------------------------

-- 2a. Kultura / crop  (small lookup table — keep it!)
CREATE TABLE crop (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL UNIQUE,   -- 'Lozje', 'Praski', 'Luk'
    description TEXT,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,   -- deactivate, don't delete
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- 2b. Bolest / problem (small lookup table — keep it!)
CREATE TABLE disease (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL UNIQUE,   -- 'Pepelnica', 'Plamenica'
    description TEXT,                           -- symptoms / how to recognize it
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- 2c. Faza na rastenje
CREATE TABLE growth_phase (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(120) NOT NULL UNIQUE,   -- 'Faza 1 - rastenje', 'Faza 2 - cvetanje'
    sort_order  INTEGER      NOT NULL DEFAULT 0,      -- 1,2,3… = order in dropdown
    period_from DATE,                                  -- optional guidance only (nullable)
    period_to   DATE,                                  -- optional guidance only (nullable)
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE
);

-- 2d. Preporaka — the heart of the app.
--     One row = "For crop X, in phase Y, against disease Z, use product P,
--     dosage D". This single table replaces product_crop and answers ALL your
--     questions: phase-specific products, multi-disease products, per-disease
--     dosage — all just more rows.
CREATE TABLE recommendation (
    id          SERIAL PRIMARY KEY,
    crop_id     INTEGER NOT NULL,
    disease_id  INTEGER NOT NULL,
    phase_id    INTEGER NOT NULL,
    product_id  INTEGER NOT NULL,
    dosage      TEXT    NOT NULL,               -- '20 g na 100 L voda', '3 mL/L'
    notes       TEXT,                           -- karenca, repeat after X days, warnings
    sort_order  INTEGER NOT NULL DEFAULT 0,     -- preferred/cheaper product first
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_recommendation
        UNIQUE (crop_id, disease_id, phase_id, product_id),  -- no duplicate rows
    CONSTRAINT fk_rec_crop
        FOREIGN KEY (crop_id)     REFERENCES crop(id)        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rec_disease
        FOREIGN KEY (disease_id)  REFERENCES disease(id)     ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rec_phase
        FOREIGN KEY (phase_id)    REFERENCES growth_phase(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rec_product
        FOREIGN KEY (product_id)  REFERENCES product(id)     ON DELETE CASCADE ON UPDATE CASCADE
);

-- 3) INDEXES for fast filtering
CREATE INDEX idx_rec_disease     ON recommendation (disease_id);
CREATE INDEX idx_rec_phase       ON recommendation (phase_id);
CREATE INDEX idx_rec_product     ON recommendation (product_id);
-- idx on (crop_id,… ) already exists via the UNIQUE constraint
CREATE INDEX idx_saleitem_product ON "SaleItem" (productId);
