// food-vision — Supabase Edge Function (Deno runtime)
//
// V1.0.7 — DIRECT-KCAL REWRITE (2026-06-07). The legacy "Honesty
// Doctrine" architecture (LLM returns only portion grams + USDA
// search terms, app-side joins authoritative numbers) is retired.
//
// Reasoning for the retirement:
//   1. GPT-5 vision is materially more accurate on food kcal than
//      the USDA-lookup chain — published head-to-head benchmarks
//      (Cal AI, Foodvisor, LogMeal, JFB) all favor frontier LLM
//      over text-search-USDA for cohort-typical meals.
//   2. USDA's Branded category had a real failure mode (the
//      lemon=360 kcal bug — Branded entries for "lemon-flavored"
//      products outranked Foundation lemons). The fix (filter to
//      Foundation/SR Legacy/Survey) bandaided one case but the
//      class of bug remains for every other ambiguous food.
//   3. The USDA cascade adds 400-800ms latency per scan + an
//      extra failure mode (USDA unreachable, no match found,
//      ambiguous match) that surfaces to the user as "reading
//      the plate…" stuck states.
//   4. The cohort doesn't need USDA's macro precision — they
//      need confident kcal in 2 seconds. Modern frontier vision
//      delivers that; USDA delivers a longer wait + occasional
//      wrong number.
//
// What this function now returns:
//   - items[]: name + kcal (midpoint) + kcal_low / kcal_high
//     (uncertainty band) + macros (P/C/F/fiber) + portion_grams
//     + confidence + notes + preparation + cuisine_hint
//   - plate_type, needs_second_photo, second_photo_hint (unchanged)
//   - _meta: cost_usd, model, duration_ms, scan_id
//
// The iOS NutritionLookupService can SKIP the USDA join when
// item.kcal is non-nil from the LLM response (already the case;
// CapturedItem.kcal is Optional<Double> and the result card only
// triggers USDA lookup when nil). Backwards-compatible.
//
// Layers (in order):
//   1. Auth   — verify JWT, extract user_id
//   2. Limit  — per-user cap (30/day) + global budget cap ($50/day)
//   3. LLM    — GPT-5 call with direct-kcal schema + cuisine prior
//   4. Log    — append telemetry row, return structured response
//
// Deploy:
//   supabase functions deploy food-vision --no-verify-jwt
//
// Secrets required (Supabase Dashboard → Edge Functions → Secrets):
//   OPENAI_API_KEY              — OpenAI account key with GPT-5 access
//   FOOD_VISION_MODEL           — optional; defaults "gpt-5". Override
//                                 to "gpt-4o" if Tier 5 access is not
//                                 granted (will surface lower accuracy
//                                 but functional).
//   SUPABASE_URL                — auto-set by Supabase
//   SUPABASE_SERVICE_ROLE_KEY   — auto-set by Supabase
//   SUPABASE_ANON_KEY           — auto-set by Supabase (for JWT verification)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

// ---------- Config ----------

const DAILY_BUDGET_USD = 50;        // global cap per v3 D26
// 2026-06-08 — bumped 30 → 200. Founder hit the 30/day cap during
// device testing (each test scan counted against the limit, and
// the `error` rows also counted — compounding the problem). 200
// gives real headroom for testing + edge cases without softening
// the budget cap (which is the real cost guardrail).
const PER_USER_DAILY_LIMIT = 200;

// Model name. v1.0.8 Phase G (2026-06-08) — default flipped back
// from gpt-5 to gpt-4o after device testing showed real-world
// latency of 8-15s per scan with gpt-5 (reasoning tokens dominate
// the wall-clock). gpt-4o lands at 3-5s with slightly lower
// accuracy on transparent-cup drinks; the iOS saliency crop +
// auto-retry + "correct me ♥" pill loop compensate for the
// accuracy gap. Cohort patience > marginal accuracy lift.
//
// To re-test gpt-5 (or try gpt-5-mini) without a code change,
// set FOOD_VISION_MODEL=gpt-5 in the Supabase Dashboard's Edge
// Function secrets. The conditional max_completion_tokens /
// max_tokens path below handles both model families correctly.
const MODEL_NAME = Deno.env.get("FOOD_VISION_MODEL") ?? "gpt-4o";

// Per-model pricing (USD per 1M tokens). Source: OpenAI pricing
// docs as of 2026-06. Bias-conservative — if pricing drifts, the
// kill-switch fires early on under-counted cost rather than over.
//
// GPT-5 pricing assumes the standard chat completions tier; if
// you're on a discounted enterprise tier, update these constants.
const PRICING: Record<string, { input: number; output: number }> = {
  "gpt-4o":      { input: 2.50, output: 10.00 },
  "gpt-4o-mini": { input: 0.15, output: 0.60 },
  // GPT-5 is more expensive per token but materially more accurate
  // on food vision per JFB + PMC head-to-head benchmarks. Bumping
  // to 5/15 conservative pricing so the budget cap fires earlier
  // — actual gpt-5 may be lower than this estimate.
  "gpt-5":       { input: 5.00, output: 15.00 },
  "gpt-5-mini":  { input: 0.50, output: 4.00 },
};
const INPUT_PRICE_PER_1M  = PRICING[MODEL_NAME]?.input  ?? 5.00;
const OUTPUT_PRICE_PER_1M = PRICING[MODEL_NAME]?.output ?? 15.00;

// ---------- Strict JSON schema for LLM response (direct-kcal) ----------
//
// OpenAI's json_schema response_format requires "strict": true plus
// every field "required" and "additionalProperties": false. We get
// hard validation server-side; if the model drifts, the API returns
// an error before we see the bad output.
//
// Per-item fields (NEW vs Honesty Doctrine):
//   - kcal:        midpoint kcal estimate (integer; rounded to bucket)
//   - kcal_low:    lower uncertainty bound (rounded to bucket)
//   - kcal_high:   upper uncertainty bound (rounded to bucket)
//   - protein_g, carbs_g, fat_g, fiber_g: integer grams (rounded)
//
// Rounding buckets (per WL program expert ED-cohort guidance):
//   <200 kcal: round to 10
//   200-600 kcal: round to 25
//   >600 kcal: round to 50
// Display ranges, not exact numbers (MacroFactor 2024 data: ranges
// reduce log abandonment 18% in ED-history cohorts).

// v1.0.8 Phase F (2026-06-08) — REVERTED Phase A schema trim.
// The 2026-06-07 trim moved `notes`, `preparation`, `cuisine_hint`
// out of `required` to save output tokens, but THIS WAS WRONG.
// OpenAI's Structured Outputs documentation is explicit: in strict
// mode, EVERY field in `properties` MUST be in `required`. Optional
// fields must be modeled via union with null instead.
//
// Symptom of the bug (founder log 2026-06-08 02:56:34Z):
//   502 from EF, detail: "SyntaxError: Unexpected end of JSON input"
// repeating on every retry. OpenAI was returning truncated/non-JSON
// output because the schema was rejected at validation time.
//
// Restored all fields to `required`. The ~20% token savings was not
// worth a 100% scan failure rate.
//
// Reference: https://platform.openai.com/docs/guides/structured-outputs
// "With strict: true, all fields must be specified as required."

const FOOD_VISION_SCHEMA = {
  name: "food_vision_response",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["items", "plate_type", "needs_second_photo", "second_photo_hint", "total_kcal_low", "total_kcal_high"],
    properties: {
      items: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "name",
            "preparation",
            "cuisine_hint",
            "portion_grams",
            "portion_grams_low",
            "portion_grams_high",
            "kcal",
            "kcal_low",
            "kcal_high",
            "protein_g",
            "carbs_g",
            "fat_g",
            "fiber_g",
            "confidence",
            "notes",
          ],
          properties: {
            name: { type: "string" },
            preparation: {
              type: "string",
              enum: ["raw", "grilled", "fried", "boiled", "baked", "sauteed", "unknown"],
            },
            cuisine_hint: { type: "string" },
            portion_grams: { type: "number" },
            portion_grams_low: { type: "number" },
            portion_grams_high: { type: "number" },
            kcal: { type: "integer" },
            kcal_low: { type: "integer" },
            kcal_high: { type: "integer" },
            protein_g: { type: "integer" },
            carbs_g: { type: "integer" },
            fat_g: { type: "integer" },
            fiber_g: { type: "integer" },
            confidence: { type: "number" },
            notes: { type: "string" },
          },
        },
      },
      plate_type: {
        type: "string",
        enum: ["single", "mixed", "bowl", "charcuterie", "shared", "restaurant_range"],
      },
      total_kcal_low: { type: "integer" },
      total_kcal_high: { type: "integer" },
      needs_second_photo: { type: "boolean" },
      second_photo_hint: { type: "string" },
    },
  },
};

// ---------- System prompt builder ----------
//
// Cuisine profile is the JeniFit-specific wedge per v3. Inject the
// user's onboarding cuisine selection so the model's prior matches
// what the user actually eats. Closes the "When Tom Eats Kimchi"
// 58% cultural-bias gap (arXiv 2503.16826).

function buildSystemPrompt(cuisineProfile: string | null): string {
  const cuisineLine = cuisineProfile && cuisineProfile.trim().length > 0
    ? `the user usually eats: ${cuisineProfile}. weight estimates accordingly when ambiguous.`
    : "no cuisine profile available; use neutral priors.";

  return [
    "you are a food vision model for a weight-loss app serving gen-z women.",
    "identify the foods in this photo, estimate portion size in grams, AND estimate calories + macros directly.",
    "",
    cuisineLine,
    "",
    "calorie estimation rules:",
    "- kcal is your MIDPOINT estimate. integer only. account for preparation (fried adds ~80-150 kcal of oil per serving; sauces/dressings add 50-200).",
    "- kcal_low / kcal_high are HONEST uncertainty bounds, not a tight confidence interval. for a typical confident estimate, ±15%. for ambiguous portions, ±25-30%. for guesses, ±40%.",
    "- ROUND kcal + bounds to buckets per shame-risk research: <200 kcal round to nearest 10; 200-600 round to nearest 25; >600 round to nearest 50. example: 347 → 350, 423 → 425, 712 → 700.",
    "- protein_g / carbs_g / fat_g / fiber_g: integer grams, rounded to nearest 1g. use cohort norms when uncertain (chicken breast 25g protein per 100g, rice 28g carbs per 100g cooked, avocado 15g fat per 100g, etc.).",
    "- total_kcal_low / total_kcal_high: sum of items' kcal_low / kcal_high. integer.",
    "",
    "portion + identification rules:",
    "- portion_grams is your midpoint. portion_grams_low / high are honest bounds (typical ±15-25%).",
    "- confidence ∈ [0, 1]: 1.0 = obvious single dish; 0.5 = ambiguous; <0.5 = guess.",
    "- preparation: best guess from visual cues.",
    "- cuisine_hint: short string like 'thai', 'mexican', 'mediterranean', 'american', 'japanese', etc.",
    "- needs_second_photo: true ONLY if portion estimate is >40% uncertain (e.g. rice depth in opaque bowl) OR the plate has hidden items.",
    "- second_photo_hint: one short sentence with the angle that would resolve the uncertainty.",
    "- plate_type: 'single' for one dish, 'mixed' for separated items, 'bowl' for layered (smoothie/poke/acai), 'charcuterie' for snack plate, 'shared' for restaurant table.",
    "",
    "common cohort foods to recognize confidently (gen-z women weight-loss context):",
    "- drinks: iced matcha latte (oat 200 kcal / almond 150 / whole 240), oat milk latte (180), cold brew black (5), boba brown sugar (380), boba taro (350), americano (15), chai latte oat (230), pink drink (140)",
    "- breakfast: avocado toast (280), avocado toast + egg (350), greek yogurt + berries (200), overnight oats (380), acai bowl (480), smoothie bowl (420), magic spoon cereal + milk (140)",
    "- lunch: chipotle chicken bowl (700), sweetgreen harvest (700), cava bowl (700), chick-fil-a sandwich (440), salmon rice bowl (600), sushi roll 8pc (400)",
    "- dinner: pad thai (700), pizza slice (320), pasta plate (700), burger (550), tacos (450 for 2)",
    "- snacks: crumbl cookie (700), halo top pint (280-360), popcorn (150 / cup), string cheese (80), apple (95)",
    "- if you recognize a chain item, prefer the chain's published kcal over your prior.",
    "",
    "respond in the structured JSON schema only. no prose."
  ].join("\n");
}

// ---------- Cost computation ----------

function computeCost(
  usage: { prompt_tokens: number; completion_tokens: number } | undefined,
): number {
  if (!usage) return 0;
  const inputCost = (usage.prompt_tokens / 1_000_000) * INPUT_PRICE_PER_1M;
  const outputCost = (usage.completion_tokens / 1_000_000) * OUTPUT_PRICE_PER_1M;
  return Number((inputCost + outputCost).toFixed(6));
}

// ---------- Telemetry ----------

interface TelemetryRow {
  id: string;
  user_id: string | null;
  model: string;
  cost_usd: number;
  tokens_in: number | null;
  tokens_out: number | null;
  duration_ms: number;
  status: "success" | "rate_limit" | "budget_cap" | "error";
}

function logTelemetry(
  supabaseAdmin: ReturnType<typeof createClient>,
  row: TelemetryRow,
): void {
  // 2026-06-08 — ACTUALLY fire-and-forget. Previously this was
  // `await`ed at every callsite — if the INSERT hung (slow table /
  // RLS issue / connection stall), the whole function hung and
  // surfaced as 504 Gateway Timeout. Now we drop the await: the
  // INSERT runs as an unawaited Promise; the function returns
  // immediately; any insert error logs to console but doesn't
  // delay the response.
  //
  // Use service-role client (bypasses RLS on food_vision_telemetry).
  supabaseAdmin
    .from("food_vision_telemetry")
    .insert([row])
    .then(({ error }: { error: { message: string } | null }) => {
      if (error) {
        console.error("[food-vision] telemetry write failed:", error.message);
      }
    });
}

// ---------- Limit checks ----------

async function checkPerUserLimit(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
): Promise<{ allowed: boolean; count: number }> {
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);

  // 2026-06-08 — only count SUCCESSFUL scans against the limit.
  // Founder hit the cap during testing because errors + rate_limit
  // rows were also counted, which compounded: once over the cap,
  // every new request logged another "rate_limit" row, pushing the
  // count further over. With this filter, only paid LLM calls
  // (status=success) count — which is what the limit is intended
  // to gate (LLM cost), not test failures.
  const { count, error } = await supabaseAdmin
    .from("food_vision_telemetry")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("status", "success")
    .gte("requested_at", startOfDay.toISOString());

  if (error) {
    // Fail-open on telemetry errors — don't lock the user out of the app
    // because the counter table is unavailable. Log and proceed.
    console.error("[food-vision] per-user limit check failed:", error.message);
    return { allowed: true, count: 0 };
  }

  const c = count ?? 0;
  return { allowed: c < PER_USER_DAILY_LIMIT, count: c };
}

async function checkDailyBudget(
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<{ allowed: boolean; spentUsd: number }> {
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);

  const { data, error } = await supabaseAdmin
    .from("food_vision_telemetry")
    .select("cost_usd")
    .gte("requested_at", startOfDay.toISOString());

  if (error) {
    console.error("[food-vision] budget check failed:", error.message);
    return { allowed: true, spentUsd: 0 };
  }

  const spent = (data ?? []).reduce(
    (sum, row: { cost_usd: number }) => sum + (row.cost_usd ?? 0),
    0,
  );
  return { allowed: spent < DAILY_BUDGET_USD, spentUsd: spent };
}

// ---------- HTTP handler ----------

Deno.serve(async (req: Request) => {
  const t0 = performance.now();

  // 2026-06-08 — DIAGNOSTIC LOGGING for the founder's "scan hangs"
  // issue. Each await gets a console.log before AND after, so the
  // LAST log before a 504 timeout tells us exactly which step
  // stalled. Once scanning is healthy, these can come out.
  console.log("[food-vision] STEP 0: handler entered");

  // CORS preflight — Supabase Edge Functions are called from the iOS
  // app, but a preflight from web/SwiftUI Previews shouldn't bomb.
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  // ---------- Auth ----------
  console.log("[food-vision] STEP 1: auth header check");
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "missing_auth" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  console.log("[food-vision] STEP 2: creating user client");
  const supabaseUserClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  console.log("[food-vision] STEP 3: calling auth.getUser()");
  const { data: { user }, error: authErr } = await supabaseUserClient.auth.getUser();
  console.log(`[food-vision] STEP 3 DONE: user=${user?.id ?? "null"}`);
  if (authErr || !user) {
    return new Response(
      JSON.stringify({ error: "invalid_auth" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const userId = user.id;

  // Admin client for telemetry + limit checks (bypasses RLS).
  console.log("[food-vision] STEP 4: creating admin client");
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // ---------- Limit checks ----------

  console.log("[food-vision] STEP 5: checkPerUserLimit");
  const userLimit = await checkPerUserLimit(supabaseAdmin, userId);
  console.log(`[food-vision] STEP 5 DONE: allowed=${userLimit.allowed}`);
  if (!userLimit.allowed) {
    logTelemetry(supabaseAdmin, {
      id: crypto.randomUUID(),
      user_id: userId,
      model: MODEL_NAME,
      cost_usd: 0,
      tokens_in: null,
      tokens_out: null,
      duration_ms: Math.round(performance.now() - t0),
      status: "rate_limit",
    });
    return new Response(
      JSON.stringify({
        error: "rate_limited",
        code: "PER_USER_LIMIT",
        scans_today: userLimit.count,
        limit: PER_USER_DAILY_LIMIT,
        copy: `you've logged ${userLimit.count} plates today ♥ scan limit resets at midnight.`,
      }),
      { status: 429, headers: { "Content-Type": "application/json" } },
    );
  }

  console.log("[food-vision] STEP 6: checkDailyBudget");
  const budget = await checkDailyBudget(supabaseAdmin);
  console.log(`[food-vision] STEP 6 DONE: allowed=${budget.allowed}`);
  if (!budget.allowed) {
    logTelemetry(supabaseAdmin, {
      id: crypto.randomUUID(),
      user_id: userId,
      model: MODEL_NAME,
      cost_usd: 0,
      tokens_in: null,
      tokens_out: null,
      duration_ms: Math.round(performance.now() - t0),
      status: "budget_cap",
    });
    return new Response(
      JSON.stringify({
        error: "budget_cap",
        code: "DAILY_BUDGET",
        copy: "we're full for the day ♥ scan limit resets at midnight.",
      }),
      { status: 429, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------- Parse request ----------

  console.log("[food-vision] STEP 7: parsing request body");
  let body: {
    image_base64?: string;
    cuisine_profile?: string;
  };
  try {
    body = await req.json();
    console.log(`[food-vision] STEP 7 DONE: body parsed, image_base64.length=${body.image_base64?.length ?? 0}`);
  } catch (_e) {
    return new Response(
      JSON.stringify({ error: "invalid_body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const imageBase64 = body.image_base64;
  if (!imageBase64 || imageBase64.length < 100) {
    return new Response(
      JSON.stringify({ error: "missing_image" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const cuisineProfile = body.cuisine_profile ?? null;

  // ---------- LLM call ----------

  const systemPrompt = buildSystemPrompt(cuisineProfile);

  // GPT-5 + o1-class reasoning models use `max_completion_tokens`
  // instead of the legacy `max_tokens`. gpt-4o still accepts
  // `max_tokens`. Detect by model name.
  const isGpt5OrReasoning = MODEL_NAME.startsWith("gpt-5") ||
                            MODEL_NAME.startsWith("o1") ||
                            MODEL_NAME.startsWith("o3");

  // GPT-5 reasoning models reject custom temperature; gpt-4o accepts
  // it. Drop temperature for gpt-5 to avoid API errors.
  const openaiRequest: Record<string, unknown> = {
    model: MODEL_NAME,
    messages: [
      { role: "system", content: systemPrompt },
      {
        role: "user",
        content: [
          { type: "text", text: "what is on this plate? estimate kcal + macros directly." },
          {
            type: "image_url",
            image_url: {
              url: `data:image/jpeg;base64,${imageBase64}`,
              detail: "high",
            },
          },
        ],
      },
    ],
    response_format: {
      type: "json_schema",
      json_schema: FOOD_VISION_SCHEMA,
    },
  };

  if (isGpt5OrReasoning) {
    // v1.0.8 Phase F (2026-06-08) — bumped from 2500 → 8000.
    // GPT-5 is a reasoning model: internal reasoning tokens count
    // AGAINST max_completion_tokens before the JSON output even
    // starts. On complex food images (multi-item plates, mixed
    // cultural dishes like the Korean galbi-jjim the founder
    // scanned), reasoning can consume 1500-3000 tokens — leaving
    // the JSON output truncated mid-emit and the EF returning 502
    // with "Unexpected end of JSON input". 8000 gives headroom for
    // both deep reasoning AND the full schema response. Cost impact
    // is real (output tokens are $15/1M for GPT-5) but a 100%
    // failure rate is more expensive than ~2x the per-scan token
    // cost.
    //
    // reasoning_effort defaults to "medium" for GPT-5. We don't
    // set it explicitly — Apple's API surface for this is still
    // moving, and "medium" is the safer default for food vision
    // where some images benefit from deeper reasoning (mixed
    // plates, ambiguous portions).
    openaiRequest.max_completion_tokens = 8000;
    // temperature deliberately omitted — gpt-5 reasoning models
    // reject non-default values.
  } else {
    openaiRequest.max_tokens = 2500;
    openaiRequest.temperature = 0.3;
  }

  // 2026-06-08 — AbortController + 90s timeout on the OpenAI fetch.
  // Without this, a slow OpenAI response (or a hung connection) keeps
  // the EF blocked until Supabase's 150-160s hard kill, which surfaces
  // as 504 Gateway Timeout to iOS and the app sees a 180s hang.
  //
  // 90s is the cutoff because:
  //   - p99 gpt-4o vision response time is ~25s (per OpenAI status page)
  //   - 90s gives headroom for retry-after-network-blip behavior
  //   - leaves 60s budget for downstream parsing + supabase upserts
  //     before Supabase's 150s kill ceiling
  //
  // On abort, we return 502 with code=openai_timeout. iOS dispatcher's
  // retry layer treats 502 as transient and re-attempts, so a one-off
  // slow OpenAI response doesn't kill the user's scan — they just see
  // "scanning..." for a beat longer.
  console.log(`[food-vision] STEP 8: about to fetch OpenAI, model=${MODEL_NAME}`);
  const openaiAbort = new AbortController();
  const openaiTimer = setTimeout(() => openaiAbort.abort(), 90_000);

  let openaiResponse: Response;
  try {
    openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: openaiAbort.signal,
      headers: {
        "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")!}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openaiRequest),
    });
  } catch (e) {
    clearTimeout(openaiTimer);
    const isAbort = (e as Error)?.name === "AbortError";
    console.error(
      `[food-vision] OpenAI fetch ${isAbort ? "TIMEOUT (90s)" : "failed"}: ${String(e)}`,
    );
    logTelemetry(supabaseAdmin, {
      id: crypto.randomUUID(),
      user_id: userId,
      model: MODEL_NAME,
      cost_usd: 0,
      tokens_in: null,
      tokens_out: null,
      duration_ms: Math.round(performance.now() - t0),
      status: "error",
    });
    return new Response(
      JSON.stringify({
        error: isAbort ? "openai_timeout" : "upstream_unreachable",
        detail: String(e),
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  clearTimeout(openaiTimer);
  console.log(`[food-vision] STEP 9: OpenAI returned status=${openaiResponse.status}`);

  if (!openaiResponse.ok) {
    const errorBody = await openaiResponse.text();
    // Log the OpenAI error to Edge Function console so it shows up in
    // Supabase logs — easier to debug than only seeing the 502 in iOS.
    console.error(
      `[food-vision] OpenAI ${openaiResponse.status} for model=${MODEL_NAME}: ${errorBody}`,
    );
    logTelemetry(supabaseAdmin, {
      id: crypto.randomUUID(),
      user_id: userId,
      model: MODEL_NAME,
      cost_usd: 0,
      tokens_in: null,
      tokens_out: null,
      duration_ms: Math.round(performance.now() - t0),
      status: "error",
    });
    // Pull the OpenAI error message out of its envelope so the iOS
    // banner can surface it directly. Falls back to the raw body when
    // not JSON. The user sees "insufficient_quota" / "model_not_found"
    // / etc. instead of just "502".
    let userFacing = errorBody;
    try {
      const parsed = JSON.parse(errorBody);
      userFacing = parsed?.error?.message
        ?? parsed?.error?.code
        ?? errorBody;
    } catch (_e) { /* leave as raw text */ }
    return new Response(
      JSON.stringify({
        error: "upstream_error",
        status: openaiResponse.status,
        code: openaiResponse.status === 429 ? "openai_quota" : "openai_error",
        detail: userFacing,
        model: MODEL_NAME,
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  const openaiBody = await openaiResponse.json();

  // ---------- Parse + return ----------

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(openaiBody.choices[0].message.content);
  } catch (e) {
    logTelemetry(supabaseAdmin, {
      id: crypto.randomUUID(),
      user_id: userId,
      model: MODEL_NAME,
      cost_usd: computeCost(openaiBody.usage),
      tokens_in: openaiBody.usage?.prompt_tokens ?? null,
      tokens_out: openaiBody.usage?.completion_tokens ?? null,
      duration_ms: Math.round(performance.now() - t0),
      status: "error",
    });
    return new Response(
      JSON.stringify({ error: "parse_failed", detail: String(e) }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  const cost = computeCost(openaiBody.usage);
  const durationMs = Math.round(performance.now() - t0);

  logTelemetry(supabaseAdmin, {
    id: crypto.randomUUID(),
    user_id: userId,
    model: MODEL_NAME,
    cost_usd: cost,
    tokens_in: openaiBody.usage?.prompt_tokens ?? null,
    tokens_out: openaiBody.usage?.completion_tokens ?? null,
    duration_ms: durationMs,
    status: "success",
  });

  return new Response(
    JSON.stringify({
      ...parsed,
      _meta: {
        cost_usd: cost,
        model: MODEL_NAME,
        duration_ms: durationMs,
        scan_id: crypto.randomUUID(),
      },
    }),
    {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    },
  );
});
