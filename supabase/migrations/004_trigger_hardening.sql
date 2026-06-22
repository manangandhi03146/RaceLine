-- ============================================================
-- RaceLine — Migration 004: handle_new_user trigger hardening
-- ============================================================
--
-- Replaces the trigger that auto-creates a profiles row on
-- `auth.users` insert. The previous version (in 001_schema.sql)
-- failed silently when its insert errored, which caused
-- "Database error saving new user" responses from Supabase Auth
-- whenever the search_path wasn't set, blocking sign-up entirely.
--
-- This version:
--   • Pins `search_path = public` so the trigger always finds
--     public.profiles even when invoked from the auth schema.
--   • Wraps the insert in an EXCEPTION block so a profile-creation
--     failure never blocks the auth.users insert itself; sign-up
--     still succeeds and the warning is logged.
--   • Backfills profile rows for any existing auth.users that
--     don't have one yet (no-op if everyone already has one).
--
-- Idempotent: safe to re-run.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill profiles for any auth.users that are missing one
INSERT INTO public.profiles (id, email)
SELECT u.id, u.email
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;
