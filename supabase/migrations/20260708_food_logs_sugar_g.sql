-- 20260708 — food_logs.sugar_g (v1.1.5)
--
-- Sugar joins the synced plate macros. The iOS app (v1.1.5+) writes
-- sugar_g on the food_logs upsert and reads it back on hydrate, so a
-- logged plate's sugar survives reinstall / cross-device like the other
-- macros. Nullable, no default: a plate with no sugar value stays NULL
-- (the app omits it from the upsert), never a fabricated 0.
--
-- ORDERING: apply this BEFORE shipping the v1.1.5 build. The app's
-- food-log upsert includes sugar_g whenever a plate carried sugar; if
-- the column is absent those upserts 42703 (undefined column). Reads are
-- safe either way (the client selects * and tolerates a missing column).
-- Idempotent — safe to re-run.

ALTER TABLE public.food_logs
    ADD COLUMN IF NOT EXISTS sugar_g double precision;
