-- ============================================================
-- Tread — Schema Migration 001: Core Tables
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- Enable UUID extension (usually already enabled on Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
    id                          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email                       TEXT,
    display_name                TEXT,
    preferred_units             TEXT NOT NULL DEFAULT 'imperial' CHECK (preferred_units IN ('imperial', 'metric')),
    default_storage_mode        TEXT NOT NULL DEFAULT 'cloudSummaryOnly'
                                    CHECK (default_storage_mode IN ('localOnly', 'cloudSummaryOnly', 'cloudFull', 'localAndCloudFull')),
    hide_route_by_default       BOOLEAN NOT NULL DEFAULT TRUE,
    route_hide_distance_miles   DOUBLE PRECISION NOT NULL DEFAULT 0.25,
    cloud_sync_paused           BOOLEAN NOT NULL DEFAULT FALSE,
    sampling_rate_hz            INTEGER NOT NULL DEFAULT 10
                                    CHECK (sampling_rate_hz IN (1, 10, 25, 50)),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- bikes
-- ============================================================
CREATE TABLE IF NOT EXISTS bikes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    local_id        UUID,                   -- iOS-side UUID for deduplication
    nickname        TEXT NOT NULL DEFAULT '',
    make            TEXT NOT NULL DEFAULT '',
    model           TEXT NOT NULL DEFAULT '',
    year            INTEGER,
    odometer_miles  DOUBLE PRECISION,
    notes           TEXT,
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    photo_path      TEXT,                   -- Storage path: {user_id}/bikes/{bike_id}/photo.jpg
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, local_id)
);

-- ============================================================
-- rides
-- ============================================================
CREATE TABLE IF NOT EXISTS rides (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    bike_id                 UUID REFERENCES bikes(id) ON DELETE SET NULL,
    local_id                UUID,           -- iOS-side UUID for deduplication
    bike_local_id           UUID,           -- Reference to bike by local_id (for iOS sync before bike is cloud-synced)
    name                    TEXT,
    started_at              TIMESTAMPTZ,
    ended_at                TIMESTAMPTZ,
    duration_seconds        DOUBLE PRECISION NOT NULL DEFAULT 0,
    distance_meters         DOUBLE PRECISION NOT NULL DEFAULT 0,
    max_speed_mps           DOUBLE PRECISION NOT NULL DEFAULT 0,
    avg_speed_mps           DOUBLE PRECISION NOT NULL DEFAULT 0,
    max_lean_deg            DOUBLE PRECISION NOT NULL DEFAULT 0,
    max_left_lean_deg       DOUBLE PRECISION NOT NULL DEFAULT 0,
    max_right_lean_deg      DOUBLE PRECISION NOT NULL DEFAULT 0,
    elevation_gain_meters   DOUBLE PRECISION,
    min_altitude_meters     DOUBLE PRECISION,
    max_altitude_meters     DOUBLE PRECISION,
    hard_braking_count      INTEGER NOT NULL DEFAULT 0,
    aggressive_accel_count  INTEGER NOT NULL DEFAULT 0,
    ride_type               TEXT NOT NULL DEFAULT 'street' CHECK (ride_type IN ('street', 'track')),
    track_name              TEXT,
    session_name            TEXT,
    session_notes           TEXT,
    tire_pressure           TEXT,
    tire_type               TEXT,
    suspension_notes        TEXT,
    notes                   TEXT,
    tags                    TEXT[] NOT NULL DEFAULT '{}',
    storage_mode            TEXT NOT NULL DEFAULT 'cloudSummaryOnly'
                                CHECK (storage_mode IN ('localOnly', 'cloudSummaryOnly', 'cloudFull', 'localAndCloudFull')),
    sync_status             TEXT NOT NULL DEFAULT 'synced'
                                CHECK (sync_status IN ('synced', 'pendingUpload', 'syncFailed')),
    has_full_telemetry      BOOLEAN NOT NULL DEFAULT FALSE,
    has_photo               BOOLEAN NOT NULL DEFAULT FALSE,
    photo_path              TEXT,           -- Storage path: {user_id}/rides/{ride_id}/photo.jpg
    telemetry_path          TEXT,           -- Storage path: {user_id}/rides/{ride_id}/telemetry.jsonl
    visibility              TEXT NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'public')),
    source                  TEXT,           -- 'recorded' | 'importedGPX'
    log_filename            TEXT,           -- original filename for compatibility
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, local_id)
);

-- ============================================================
-- maintenance_records
-- ============================================================
CREATE TABLE IF NOT EXISTS maintenance_records (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    bike_id                 UUID REFERENCES bikes(id) ON DELETE SET NULL,
    bike_local_id           UUID,           -- Reference by local_id for iOS sync
    local_id                UUID,           -- iOS-side UUID for deduplication
    type                    TEXT NOT NULL DEFAULT 'custom',
    title                   TEXT NOT NULL,
    date                    DATE NOT NULL,
    odometer_miles          DOUBLE PRECISION,
    notes                   TEXT,
    reminder_interval_days  INTEGER,
    reminder_interval_miles DOUBLE PRECISION,
    receipt_photo_path      TEXT,           -- Storage path: {user_id}/maintenance/{record_id}/receipt.jpg
    is_archived             BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, local_id)
);

-- ============================================================
-- deletion_requests
-- (For server-side account deletion queue if Edge Function is unavailable)
-- ============================================================
CREATE TABLE IF NOT EXISTS deletion_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    notes           TEXT
);

-- ============================================================
-- Indexes for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_rides_user_id         ON rides(user_id);
CREATE INDEX IF NOT EXISTS idx_rides_started_at      ON rides(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_rides_ride_type       ON rides(ride_type);
CREATE INDEX IF NOT EXISTS idx_bikes_user_id         ON bikes(user_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_user_id   ON maintenance_records(user_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_bike_id   ON maintenance_records(bike_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_date      ON maintenance_records(date DESC);

-- ============================================================
-- Updated-at trigger
-- ============================================================
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE OR REPLACE TRIGGER bikes_updated_at
    BEFORE UPDATE ON bikes
    FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE OR REPLACE TRIGGER rides_updated_at
    BEFORE UPDATE ON rides
    FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE OR REPLACE TRIGGER maintenance_updated_at
    BEFORE UPDATE ON maintenance_records
    FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- ============================================================
-- Auto-create profile on auth.users insert
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
