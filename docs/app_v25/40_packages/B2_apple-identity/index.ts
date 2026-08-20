// PACKAGE B · 2 of 2 — apple-identity Edge Function
//
// =========================================================================
// ==  PREPARED, NOT DEPLOYED. NOT PLACED IN supabase/functions/.         ==
// ==  A file under supabase/functions is deployable by name; this one is ==
// ==  staged so it cannot be shipped by accident, and because it needs a ==
// ==  secret that does not exist yet (§40 §17).                          ==
// =========================================================================
//
// WHAT IT DOES, AND NOTHING ELSE.
//
//   POST { action: "capture", authorization_code }
//        exchange the code at Apple for a refresh token, store it, return
//        { ok: true }. THE TOKEN IS NEVER RETURNED TO THE CLIENT.
//
//   POST { action: "revoke" }
//        load this customer's stored refresh token, call Apple's
//        /auth/revoke, erase the row, return { ok, revoked }.
//        THE TOKEN IS NEVER RETURNED AND NEVER LOGGED.
//
// THE ORDERING RULE, WHICH IS THE WHOLE DESIGN:
//
//   ▎ FAILURE TO REACH APPLE MUST NEVER BECOME FAILURE TO DELETE CUSTOMER
//   ▎ DATA.
//
// The client calls "revoke" BEFORE `delete_user_account()` — while a
// credential still exists to look the token up with — and then deletes
// REGARDLESS of what this function said. It returns 200 with
// `{ ok: true, revoked: false }` on every Apple failure precisely so the
// client has nothing to branch on: making a privacy deletion depend on a
// third party's availability turns an Apple outage into a Jeni retention
// event, and Apple's own TN3194 assumes an app may hold no usable token at
// all and still requires the deletion to complete.
//
// Apple returns 200 WITH NO BODY both on success and when the token was
// ALREADY INVALIDATED, so revocation is idempotent by Apple's own contract
// and this function needs no special case for a second call.
//
// SECRETS (Supabase project secrets — never in the repo, never in the app):
//   APPLE_TEAM_ID        10 characters, Apple Developer › Membership
//   APPLE_KEY_ID         10 characters, the Sign in with Apple key's Key ID
//   APPLE_CLIENT_ID      the app's Bundle ID: com.bk.plankAI
//   APPLE_PRIVATE_KEY    the .p8 contents, PEM, newlines preserved
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY   (injected by the platform)
//
// DEPLOY:  supabase functions deploy apple-identity
//          (verify_jwt stays ON — the caller must be the customer.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

// --- client_secret: an ES256 JWT signed with the team's .p8 -------------

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function appleClientSecret(): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID")!;
  const keyId = Deno.env.get("APPLE_KEY_ID")!;
  const clientId = Deno.env.get("APPLE_CLIENT_ID")!;
  const pem = Deno.env.get("APPLE_PRIVATE_KEY")!;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const claims = {
    iss: teamId,
    iat: now,
    // Apple's ceiling is 6 months. Ten minutes is plenty for one call and
    // means a leaked secret is worthless almost immediately.
    exp: now + 600,
    aud: "https://appleid.apple.com",
    sub: clientId,
  };

  const enc = new TextEncoder();
  const signingInput =
    `${b64url(enc.encode(JSON.stringify(header)))}.${b64url(enc.encode(JSON.stringify(claims)))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(pem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(signingInput)),
  );
  return `${signingInput}.${b64url(signature)}`;
}

// --- the function -------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405 });
  }

  // The CALLER must be the customer. `verify_jwt` has already validated the
  // signature; this resolves it to a uid, and the uid is the only thing that
  // decides which row is touched. There is no path here that accepts a
  // user_id from the request body.
  const authHeader = req.headers.get("Authorization") ?? "";
  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: userError } = await anon.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "unauthenticated" }), { status: 401 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let body: { action?: string; authorization_code?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "bad_request" }), { status: 400 });
  }

  const clientId = Deno.env.get("APPLE_CLIENT_ID")!;

  // ---------------------------------------------------------------- capture
  if (body.action === "capture") {
    const code = body.authorization_code;
    if (!code) {
      return new Response(JSON.stringify({ error: "bad_request" }), { status: 400 });
    }
    let refreshToken: string | undefined;
    try {
      const secret = await appleClientSecret();
      const res = await fetch(APPLE_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          code,
          client_id: clientId,
          client_secret: secret,
        }),
      });
      if (res.ok) {
        const json = await res.json();
        refreshToken = json.refresh_token;
      }
      // A failure here is NOT a sign-in failure. The customer signed in
      // successfully; Jeni simply has no revocable token for her, which is
      // the position every one of the 559 existing Apple customers is in,
      // and TN3194's fallback covers it. The status is deliberately not
      // echoed: it would tell a caller whether a code was valid.
    } catch {
      refreshToken = undefined;
    }

    if (!refreshToken) {
      return new Response(JSON.stringify({ ok: false }), { status: 200 });
    }

    const { error } = await admin
      .from("apple_provider_tokens")
      .upsert(
        { user_id: user.id, provider: "apple", refresh_token: refreshToken, updated_at: new Date().toISOString() },
        { onConflict: "user_id" },
      );
    // NOTHING about the token is logged, on either branch.
    return new Response(JSON.stringify({ ok: !error }), { status: 200 });
  }

  // ----------------------------------------------------------------- revoke
  if (body.action === "revoke") {
    const { data: row } = await admin
      .from("apple_provider_tokens")
      .select("refresh_token")
      .eq("user_id", user.id)
      .maybeSingle();

    if (!row?.refresh_token) {
      // NOTHING TO REVOKE IS A SUCCESSFUL OUTCOME, not an error. It is the
      // state of every customer who signed in before this shipped, and
      // Apple's documented fallback (delete the data, direct her to revoke
      // manually, honour the revocation notice) is what the app does for
      // them. The deletion must not stall on it.
      return new Response(JSON.stringify({ ok: true, revoked: false }), { status: 200 });
    }

    let revoked = false;
    try {
      const secret = await appleClientSecret();
      const res = await fetch(APPLE_REVOKE_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          token: row.refresh_token,
          token_type_hint: "refresh_token",
          client_id: clientId,
          client_secret: secret,
        }),
      });
      // Apple documents 200-with-no-body for BOTH success and an already
      // invalidated token, so there is no "already revoked" branch to write.
      // A 400 `invalid_grant` means the token is already dead, which is the
      // same end state.
      revoked = res.ok || res.status === 400;
    } catch {
      revoked = false;
    }

    if (revoked) {
      // Erase rather than mark: a revoked refresh token has no further use
      // and keeping it is keeping a credential for no reason.
      await admin.from("apple_provider_tokens").delete().eq("user_id", user.id);
    }

    // ALWAYS 200. The client must have nothing to branch on: it proceeds to
    // `delete_user_account()` either way.
    return new Response(JSON.stringify({ ok: true, revoked }), { status: 200 });
  }

  return new Response(JSON.stringify({ error: "unknown_action" }), { status: 400 });
});
