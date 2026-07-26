// nutrition-lookup — Supabase Edge Function (Deno runtime)
//
// SKELETON ONLY for v1.0.7 W1-T3. Real implementation lands W2-T4
// (NutritionLookupService).
//
// Purpose: server-side cache layer over USDA FoodData Central + Open
// Food Facts queries. The iOS app could call USDA directly, but USDA's
// free tier rate-limits to 1k req/hr per IP — at 10k DAU × 2 scans/day
// on a single egress IP this will throttle. This Edge Function caches
// in front of USDA so duplicate queries (matcha latte logged by many
// users) hit the cache instead of USDA every time.
//
// W2-T4 deliverable (NOT in this skeleton):
//   - Accept POST { search_terms: string[], user_id: string }
//   - For each search term:
//       1. Check Postgres cache table for recent hit (TTL ~30 days)
//       2. If miss: query USDA FDC v1/foods/search, take highest-score result
//       3. Fall through to Open Food Facts (barcode endpoints if numeric term)
//       4. Fall through to canonical_pantry GIN search on search_terms
//       5. Cache the result with TTL
//   - Return: { matches: [{ source, fdc_id, kcal_per_100g, protein, ... }] }
//
// Secrets required (when implemented):
//   USDA_API_KEY                — FoodData Central data.gov key
//   SUPABASE_URL                — auto-set
//   SUPABASE_SERVICE_ROLE_KEY   — auto-set
//
// Deploy:
//   supabase functions deploy nutrition-lookup
//
// Auth: JWT verified via getUser() BEFORE the 501 (same layer-1 as
// jeni-chat / food-vision), so the skeleton is never an open endpoint
// and the real implementation inherits the gate.

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
      detail: "nutrition-lookup is a W2-T4 deliverable; this is a skeleton.",
    }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  );
});
