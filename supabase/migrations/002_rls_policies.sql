-- ============================================================
-- Tread — Migration 002: Row Level Security Policies
-- Run AFTER 001_schema.sql
-- ============================================================

-- ============================================================
-- Enable RLS on all tables
-- ============================================================
ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE bikes                ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides                ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE deletion_requests    ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- profiles
-- ============================================================
CREATE POLICY "profiles: users can view own profile"
    ON profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "profiles: users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (id = auth.uid());

CREATE POLICY "profiles: users can update own profile"
    ON profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- No DELETE policy — deletion handled by CASCADE from auth.users deletion

-- ============================================================
-- bikes
-- ============================================================
CREATE POLICY "bikes: users can view own bikes"
    ON bikes FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "bikes: users can insert own bikes"
    ON bikes FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "bikes: users can update own bikes"
    ON bikes FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "bikes: users can delete own bikes"
    ON bikes FOR DELETE
    USING (user_id = auth.uid());

-- ============================================================
-- rides
-- ============================================================
CREATE POLICY "rides: users can view own rides"
    ON rides FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "rides: users can insert own rides"
    ON rides FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "rides: users can update own rides"
    ON rides FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "rides: users can delete own rides"
    ON rides FOR DELETE
    USING (user_id = auth.uid());

-- ============================================================
-- maintenance_records
-- ============================================================
CREATE POLICY "maintenance: users can view own records"
    ON maintenance_records FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "maintenance: users can insert own records"
    ON maintenance_records FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "maintenance: users can update own records"
    ON maintenance_records FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "maintenance: users can delete own records"
    ON maintenance_records FOR DELETE
    USING (user_id = auth.uid());

-- ============================================================
-- deletion_requests
-- ============================================================
CREATE POLICY "deletion_requests: users can view own requests"
    ON deletion_requests FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "deletion_requests: users can insert own requests"
    ON deletion_requests FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- No UPDATE/DELETE from client — these are managed by the Edge Function

-- ============================================================
-- NOTE: Future public visibility
-- When adding public ride pages, add a separate policy:
--
-- CREATE POLICY "rides: public can view public rides"
--     ON rides FOR SELECT
--     USING (visibility = 'public');
--
-- This is intentionally NOT added now. All rides are private by default.
-- ============================================================
