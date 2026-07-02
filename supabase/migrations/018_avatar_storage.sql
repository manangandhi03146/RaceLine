-- ============================================================
-- RaceLine — Migration 018: Avatar storage policies
-- Run AFTER 017_social_polish.sql
--
-- PREREQUISITE: create a bucket named `avatars` in the Supabase
-- Dashboard first. Mark it PUBLIC — avatars are meant to be visible
-- to any signed-in rider on the app. The RLS policies below still
-- restrict writes to the owning user.
--
-- Storage path convention:
--   {user_id}/avatar.jpg
--
-- Anyone (including anon) can SELECT so we can render URLs without
-- a signed URL round-trip. Writes are always owner-only.
-- ============================================================

DROP POLICY IF EXISTS "avatars: signed-in can read"       ON storage.objects;
DROP POLICY IF EXISTS "avatars: users upload own avatar"  ON storage.objects;
DROP POLICY IF EXISTS "avatars: users update own avatar"  ON storage.objects;
DROP POLICY IF EXISTS "avatars: users delete own avatar"  ON storage.objects;

CREATE POLICY "avatars: signed-in can read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "avatars: users upload own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "avatars: users update own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "avatars: users delete own avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
