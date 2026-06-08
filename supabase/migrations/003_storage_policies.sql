-- ============================================================
-- Tread — Migration 003: Storage Bucket Policies
-- Run AFTER 001_schema.sql
--
-- PREREQUISITES: Create these private buckets in Supabase Dashboard first:
--   - ride-photos
--   - bike-photos
--   - ride-telemetry
--   - maintenance-photos
--
-- Storage path convention:
--   {user_id}/rides/{ride_id}/photo.jpg
--   {user_id}/rides/{ride_id}/telemetry.jsonl
--   {user_id}/bikes/{bike_id}/photo.jpg
--   {user_id}/maintenance/{record_id}/receipt.jpg
-- ============================================================

-- ============================================================
-- ride-photos bucket
-- ============================================================
CREATE POLICY "ride-photos: users can upload own photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'ride-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "ride-photos: users can view own photos"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'ride-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "ride-photos: users can update own photos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'ride-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "ride-photos: users can delete own photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'ride-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- bike-photos bucket
-- ============================================================
CREATE POLICY "bike-photos: users can upload own photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'bike-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "bike-photos: users can view own photos"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'bike-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "bike-photos: users can update own photos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'bike-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "bike-photos: users can delete own photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'bike-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- ride-telemetry bucket
-- ============================================================
CREATE POLICY "ride-telemetry: users can upload own telemetry"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'ride-telemetry'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "ride-telemetry: users can view own telemetry"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'ride-telemetry'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "ride-telemetry: users can update own telemetry"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'ride-telemetry'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "ride-telemetry: users can delete own telemetry"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'ride-telemetry'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- maintenance-photos bucket
-- ============================================================
CREATE POLICY "maintenance-photos: users can upload own photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'maintenance-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "maintenance-photos: users can view own photos"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'maintenance-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "maintenance-photos: users can update own photos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'maintenance-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "maintenance-photos: users can delete own photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'maintenance-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
