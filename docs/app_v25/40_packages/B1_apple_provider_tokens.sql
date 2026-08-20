-- PACKAGE B · 1 of 2 — THE APPLE REFRESH-TOKEN STORE
--
-- ==========================================================================
-- ==  NOT WRITTEN TO supabase/migrations. NOT APPLIED.                    ==
-- ==  BLOCKED ON A CREDENTIAL THAT DOES NOT EXIST (§40 §17).              ==
-- ==========================================================================
--
-- WHY A TABLE AT ALL.
-- Apple requires an app that offers Sign in with Apple AND account deletion
-- to call `POST https://appleid.apple.com/auth/revoke` on deletion (enforced
-- since 2022-06-30). That endpoint accepts a REFRESH TOKEN or an ACCESS
-- TOKEN. It does not accept an identity token and it does not accept a
-- `sub`. Jeni holds none of the three: `credential.authorizationCode` has
-- zero call sites in first-party code, and `auth.identities.identity_data`
-- for all 559 Apple rows carries only `sub`/`email`/`email_verified`/
-- `iss`/`provider_id`/`custom_claims` — no token key of any kind, because
-- `signInWithIdToken` never sends GoTrue an authorization code.
--
-- So the token has to be obtained (client sends the authorization code once,
-- at sign-in) and KEPT (server-side, until deletion). This is where it is
-- kept.
--
-- WHERE IT IS NOT KEPT, and these are hard rules:
--   * NOT in `public.users` — that table is readable by its owner under RLS.
--   * NOT in the app bundle, `UserDefaults`, the keychain, or any log.
--   * NOT reachable by the `authenticated` role at all. There is no read
--     policy and no grant; only the Edge Function's service role can see it.
--
-- MINIMUM FIELDS ONLY. No identity token is stored: it is a short-lived
-- assertion, it carries her email, and nothing in the revocation flow needs
-- it. No access token is stored either — the refresh token is the one Apple
-- accepts for the lifetime of the grant.

-- ------------------------------- FORWARD ---------------------------------

create schema if not exists private;

create table if not exists private.apple_provider_tokens (
    user_id       uuid primary key references auth.users(id) on delete cascade,
    provider      text not null default 'apple' check (provider = 'apple'),
    refresh_token text not null,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    revoked_at    timestamptz
);

comment on table private.apple_provider_tokens is
  'Sign in with Apple refresh tokens, held ONLY so account deletion can call
   appleid.apple.com/auth/revoke (Apple TN3194). Never exposed to any client.
   No RLS policy and no grant to `authenticated` or `anon` — the Edge
   Function service role is the only reader. Cascades with the account, so a
   deletion that revokes and then deletes leaves nothing behind either way.
   v25 §40 §16.';

-- RLS ON WITH NO POLICIES = deny-all for every role that is not
-- BYPASSRLS. Stated explicitly rather than relied on.
alter table private.apple_provider_tokens enable row level security;
revoke all on private.apple_provider_tokens from anon, authenticated;

-- ------------------------------- ROLLBACK --------------------------------
-- drop table if exists private.apple_provider_tokens;
--
-- ------------------------------ SAFETY MATRIX -----------------------------
-- OLD CLIENT (build 30):   SAFE. It never reads or writes this table and
--                          never calls the function that does.
-- NEW CLIENT:              SAFE, and it must ship AFTER this table exists —
--                          a client that posts an authorization code to a
--                          function whose table is missing gets a 500 on
--                          every sign-in. THIS IS THE ONE SERVER-FIRST ITEM
--                          in the whole package.
-- DEPLOY ORDER:            B1 (table) → B2 (function) → the client line that
--                          captures `credential.authorizationCode`.
-- SECRET REQUIRED:         none for the table. B2 needs the `.p8` (§40 §17).
-- FOUNDER ACTION:          create the Apple key first; this table is worth
--                          nothing without it.
