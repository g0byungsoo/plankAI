// food-photo-cleanup — Supabase Edge Function (Deno runtime)
//
// SKELETON ONLY for v1.0.7 W1-T3. Real implementation lands by W5 if
// photo retention opt-in launches in v1.0.7 (else defers to v1.0.8).
//
// Purpose: scheduled job (cron, daily at 03:00 UTC) that deletes opt-in
// food photos past their 30-day retention window. Per v3 §Privacy +
// Apple compliance + v5 D42 Honesty Doctrine: "photo's gone after."
//
// W5 deliverable (NOT in this skeleton):
//   - Query food_corrections WHERE photo_retention_expires_at < now()
//     AND image_url IS NOT NULL
//   - For each row:
//       1. Delete image from Supabase Storage bucket
//       2. NULL out image_url + photo_retention_expires_at in DB
//   - Emit telemetry: deleted count + bytes freed
//
// Scheduled invocation via Supabase cron (pg_cron) or external scheduler.
// At launch scale this runs in <5s; trigger from a Postgres function
// or external cron.
//
// Auth: JWT verified via getUser() BEFORE the 501 (same layer-1 as
// jeni-chat / food-vision), so the skeleton is never an open endpoint.
// When the cron implementation lands, swap/extend this gate for a
// service-role or shared-secret check appropriate to scheduled calls —
// do NOT remove it.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

Deno.serve(async (req: Request) => {
  // 1 — auth (mirrors jeni-chat / food-vision)
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      error: "not_implemented",
      detail: "food-photo-cleanup is a W5 deliverable; this is a skeleton.",
    }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  );
});
