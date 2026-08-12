-- 20260811120000 — food_logs.source tells the truth (v25 E8.1)
--
-- THE DEFECT. `food_logs.source` has always answered the question
-- "which door did this plate enter through", and it has never been able
-- to. One decoder in FoodVisionService is shared by three inputs — a
-- photograph of food, a photograph of a printed nutrition panel, and a
-- typed sentence — and it hardcodes `photo` for all three, because it
-- was written in v1.0.9 when only the first existed. E8 fixed the
-- TELEMETRY (`food_log_saved{entry_method}`) and deliberately left the
-- record lying, because correcting it needs this file.
--
-- The lie was not only cosmetic. Every behaviour that reads `source`
-- was wrong, and one of them was wrong to the user's face:
--   · PlateDetailSheet renders "read from your photo" when source is
--     `photo` and "logged from your words" otherwise. So a plate she
--     TYPED claimed to have been read from a photograph she never took,
--     and a barcode read claimed to have come from her words.
--   · FoodLogPersister's "dining out" title branch tested a value
--     (`im_out`) that nothing has ever written, so it was dead and the
--     restaurant path fell through to "scanned plate".
--   · Nothing downstream of the record could ever separate the doors,
--     so any question asked of the RECORD rather than of the event
--     stream — which doors do returning payers use, do label reads get
--     corrected more often — was unanswerable by construction.
-- (PlatePriors is NOT in that list: its photo-only law is enforced by
-- dispatcher scope, which is correct today. Its `source != .barcode`
-- guard is belt-and-braces and stays.)
--
-- THE CONTRACT. `source` answers exactly one question — WHICH DOOR —
-- and its vocabulary is now the same closed set the `entry_method`
-- analytics property carries (`PlankFood.EntryMethod`). One vocabulary,
-- one meaning, in the row and in the telemetry.
--
--   photo               a photograph of the food itself
--   label               a photograph of a printed nutrition panel
--   words               typed or dictated words
--   barcode             a scanned product barcode
--   again               re-logged from her own record
--   restaurant_estimate the rule-based restaurant placeholder
--   quick_add           a pantry tile
--   unknown             not attributed (a writer that predates this)
--
-- NO HISTORY IS REWRITTEN AND NONE IS INVENTED. Rows written before the
-- release carrying this migration say `photo` whether they were a
-- photograph, a label or a sentence; that ambiguity is a fact about a
-- date, not a value to be repaired, and any attempt to guess would
-- manufacture precision we do not have. This follows E8 §3.1's
-- precedent for `environment`: SPLIT a value, never rename one, so no
-- existing insight, funnel or cohort filter breaks. The three names
-- that already appear in the column keep their exact spelling
-- (`photo`, `restaurant_estimate`, `quick_add`); only genuinely new
-- doors get new strings.
--
-- IDEMPOTENT + REPLAYABLE. The constraint is dropped by DEFINITION
-- rather than by name: `food_logs` predates this migrations folder, so
-- its CHECK was created inline and its name is Postgres's default
-- guess. Dropping by name alone would silently no-op against a
-- differently-named constraint and then ADD a second, contradictory
-- one — the failure mode would be `label` inserts rejected in
-- production with a green migration. Scanning pg_constraint cannot
-- miss.

-- 1 · Report what is actually in the column before touching it. If the
--     ADD below ever fails, this NOTICE names the value that did it.
do $$
declare
    found text;
begin
    if exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'food_logs'
    ) then
        select string_agg(distinct coalesce(source, '<null>'), ', ' order by coalesce(source, '<null>'))
          into found
          from public.food_logs;
        raise notice 'food_logs.source distinct values before widening: %',
            coalesce(found, '<table empty>');
    end if;
end $$;

-- 2 · Drop every CHECK on food_logs that constrains `source`, whatever
--     it happens to be called.
do $$
declare
    c record;
begin
    if not exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'food_logs'
    ) then
        return;
    end if;
    for c in
        select con.conname
          from pg_constraint con
          join pg_class rel on rel.oid = con.conrelid
          join pg_namespace ns on ns.oid = rel.relnamespace
         where ns.nspname = 'public'
           and rel.relname = 'food_logs'
           and con.contype = 'c'
           and pg_get_constraintdef(con.oid) ilike '%source%'
    loop
        execute format(
            'alter table public.food_logs drop constraint %I', c.conname
        );
        raise notice 'dropped food_logs source constraint %', c.conname;
    end loop;
end $$;

-- 3 · Add the widened constraint under a stable, known name.
--
--     The list is the union of the canonical door vocabulary and every
--     value any shipped build was ever able to write. The five legacy
--     values below are tolerated so no historical row can be
--     invalidated, and the client will never write them again:
--       im_out              superseded by restaurant_estimate
--       voice · menu · text reserved in v1.0.7, never written
--     Removing them is a separate, later migration that must first
--     prove the column is clean.
do $$
begin
    if exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'food_logs'
    ) and not exists (
        select 1 from pg_constraint
        where conname = 'food_logs_source_door_check'
    ) then
        alter table public.food_logs
            add constraint food_logs_source_door_check check (source in (
                -- the canonical doors
                'photo', 'label', 'words', 'barcode', 'again',
                'restaurant_estimate', 'quick_add', 'unknown',
                -- legacy, tolerated, never written again
                'im_out', 'voice', 'menu', 'text'
            ));
    end if;
end $$;

comment on column public.food_logs.source is
    'WHICH DOOR this plate entered through. Closed vocabulary, shared '
    'verbatim with the entry_method analytics property and '
    'PlankFood.EntryMethod: photo | label | words | barcode | again | '
    'restaurant_estimate | quick_add | unknown. Rows written before the '
    'release carrying migration 20260811120000 say photo for '
    'photographs, nutrition labels AND typed sentences alike — that '
    'ambiguity is not repairable and must not be guessed at. Legacy '
    'values im_out/voice/menu/text remain valid for historical rows.';
