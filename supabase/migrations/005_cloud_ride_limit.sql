-- ============================================================
-- RaceLine — Migration 005: Cap cloud rides at 10 per user
-- ============================================================
--
-- Hard server-side limit. Trips at INSERT time before the row is
-- persisted; clients see a P0001 exception with a human-readable
-- message and the SyncService surfaces it as a friendly banner.
--
-- Upserts hitting an existing (user_id, local_id) row are treated
-- as updates and skip the count check, so editing a ride's name
-- or notes never bumps against the limit.
--
-- Lift the limit later by changing `ride_limit` and re-running
-- this migration (it's CREATE OR REPLACE / DROP IF EXISTS, so safe).
-- ============================================================

CREATE OR REPLACE FUNCTION public.enforce_ride_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    ride_limit CONSTANT INT := 10;
    user_count INT;
    is_update BOOLEAN;
BEGIN
    -- If a row with the same (user_id, local_id) already exists,
    -- this insert is actually an upsert UPDATE — let it through.
    SELECT EXISTS(
        SELECT 1 FROM public.rides
        WHERE user_id = NEW.user_id AND local_id = NEW.local_id
    ) INTO is_update;
    IF is_update THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO user_count FROM public.rides WHERE user_id = NEW.user_id;
    IF user_count >= ride_limit THEN
        RAISE EXCEPTION 'Ride limit reached (% / %). Delete a ride to make room for new uploads.',
            user_count, ride_limit
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_ride_limit ON public.rides;

CREATE TRIGGER enforce_ride_limit
    BEFORE INSERT ON public.rides
    FOR EACH ROW EXECUTE FUNCTION public.enforce_ride_limit();
