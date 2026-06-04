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

Deno.serve((_req: Request) => {
  return new Response(
    JSON.stringify({
      error: "not_implemented",
      detail: "food-photo-cleanup is a W5 deliverable; this is a skeleton.",
    }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  );
});
