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
            "name_native",
            "english_name",
            "count",
            "unit",
            "servings_in_dish",
            "is_shareable",
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
            // 2026-06-23 — accuracy rewrite. Three founder complaints:
            //   (1) quantity blindness → count + unit force a count-first
            //       estimate; portion_grams must equal count × per-unit.
            //   (2) cultural naming → name_native carries the authentic
            //       dish name (the headline the user sees); english_name a
            //       short plain gloss. `name` is ALSO set to the authentic
            //       name so the iOS decoder stays backward-compatible.
            //   (3) shared food → kcal/macros describe the WHOLE visible
            //       food; servings_in_dish + is_shareable let the USER
            //       resolve their personal share in the app afterward (the
            //       model never guesses how many people ate it).
            // STRICT MODE: every property here is also in `required`.
            name_native: { type: "string" },
            english_name: { type: "string" },
            count: { type: "integer" },
            unit: { type: "string" },
            servings_in_dish: { type: "integer" },
            is_shareable: { type: "boolean" },
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

function buildSystemPrompt(
  cuisineProfile: string | null,
  dietaryProfile: string | null,
): string {
  const cuisineLine = cuisineProfile && cuisineProfile.trim().length > 0
    ? `the user usually eats: ${cuisineProfile}. lean on this for BOTH calorie priors AND naming — if a dish matches this cuisine, name it the way someone from that food culture would.`
    : "no cuisine profile available; use neutral priors, but still prefer authentic dish names over generic descriptions.";

  // v1.1.3 (2026-06-29) — dietary pattern + restrictions + allergies
  // (onboarding case 170, CSV of keys like vegetarian, dairy_free,
  // nut_allergy, halal, low_carb, none). Helps the model name dishes
  // consistently with the user's pattern and, when an allergen is
  // present, surface it in notes. NOT medical advice and NOT a hard
  // safety guarantee — the model flags what it can see; the app copy
  // carries the disclaimer.
  const dietaryLine = dietaryProfile && dietaryProfile.trim().length > 0
    && dietaryProfile.trim() !== "none"
    ? `the user's dietary pattern / restrictions / allergies: ${dietaryProfile}. respect this when naming and when offering any guidance; if a visible item plausibly conflicts with a stated allergy or restriction (e.g. nuts, shellfish, dairy, gluten, egg), call it out plainly in the notes field so they can double-check. never claim a dish is safe.`
    : "no dietary restrictions provided; do not assume any.";

  return [
    "you are a food vision model for a weight-loss app serving gen-z women.",
    "your job: name the food authentically, COUNT what is visibly present, anchor portion mass to a scale reference, and estimate calories + macros for the WHOLE visible food.",
    "",
    cuisineLine,
    dietaryLine,
    "",
    "=== STEP 1 — COUNT FIRST (before any gram or kcal number) ===",
    "for EACH item decide discrete vs continuous, then size it:",
    "- DISCRETE (countable units): count EVERY visible unit including ones partly hidden behind others (stacked fried chicken, a pile of dumplings). set count = the integer and unit = the singular noun ('piece','slice','wing','dumpling','nugget','taco','egg','shrimp','meatball','cookie','roll'). portion_grams = count × per-unit grams. NEVER collapse a multi-piece plate into one averaged blob — five pieces of chicken is count=5, not 'a serving'.",
    "- CONTINUOUS (scooped/piled, not counted): rice, noodles, salad, stew, smoothie, fries-as-a-pile. set count = 1 and unit = 'serving'; size comes from volume, not a count.",
    "- per-unit gram anchors (edible cooked weight): fried drumstick ~85g, fried wing ~50g, fried thigh ~125g, fried breast ~180g, nugget ~18g, dumpling ~30g, pizza slice (1/8 of 14in) ~120g, street taco ~95g, maki piece ~30g, nigiri ~35g, large egg ~50g, shrimp ~8g, meatball ~30g, bakery cookie ~120g, sausage link ~28g.",
    "",
    "=== STEP 2 — ANCHOR TO A SCALE REFERENCE (never size in a vacuum) ===",
    "find a known-size object in frame and reason from it: dinner plate ~27cm, side plate ~20cm, bowl rim ~15cm, fork ~19cm, chopsticks ~23cm, soda can 12.2cm tall / 355ml, adult fist ~1 cup, adult palm (no fingers) ~85-110g of cooked meat. compare the food's footprint to the reference to get real size. if NO usable reference is in frame, say so in notes, widen portion_grams_low/high, and lower confidence — do not fake precision.",
    "for piled/amorphous foods: volume = footprint area × mound height (a heap ≈ 0.5 × its peak height), then grams = volume × bulk density. densities g/ml: cooked rice 0.80, pasta 0.65, leafy salad 0.20, soup 1.0, ice cream 0.55, yogurt 1.03, mashed potato 1.0, fried rice 0.85. a MOUNDED bowl is 1.5-2.5× a flat bowl of the same width — scale up for mounding.",
    "",
    "=== STEP 3 — SHARED / WHOLE-DISH FRAMING (never guess how many people ate) ===",
    "the photo may show a whole dish meant to be shared (a full pizza, a platter, family-style). RULES:",
    "- kcal / kcal_low / kcal_high / portion_grams / macros ALWAYS describe the ENTIRE visible food. a whole 12-inch pizza → kcal for the whole pizza.",
    "- servings_in_dish = how many normal human servings the WHOLE visible food is (whole large pizza ~8; a single avocado toast 1; a platter of bulgogi for the table ~4; a personal poke bowl 1). integer, minimum 1.",
    "- is_shareable = true for a dish multiple people plausibly share (whole pizza, platter, large-format, family-style, pitcher, shareable dessert); false for an obvious single serving (one bowl, one sandwich, one latte).",
    "- DO NOT pre-divide and DO NOT estimate headcount. the app divides by the user's own input. for a normal single plate set servings_in_dish=1, is_shareable=false (the common case).",
    "",
    "=== STEP 4 — NAME IT AUTHENTICALLY ===",
    "- name_native = the name a person from that food's culture uses. korean bbq beef => 'bulgogi' (NOT 'stir-fried beef with onions'). examples: bibimbap, japchae, tteokbokki, kimchi jjigae, sundubu, pho, banh mi, bun cha, pad thai, tom yum, khao soi, biryani, dal, dosa, tacos al pastor, birria, chilaquiles, congee, mapo tofu, char siu, ramen, katsu curry, onigiri, shakshuka, falafel, shawarma.",
    "- english_name = a short plain-english gloss ('bulgogi' => 'marinated grilled beef'). if the dish is already plain english (e.g. 'avocado toast'), set english_name equal to name_native.",
    "- name = set this to the SAME value as name_native (kept for backward compatibility).",
    "- when unsure which specific dish it is, name the closest authentic dish and note the uncertainty rather than retreating to a generic description.",
    "- cuisine_hint: short string like 'korean','thai','mexican','japanese','mediterranean','american'.",
    "",
    "=== STEP 5 — CALORIES + MACROS (for the whole visible food) ===",
    "- kcal is your MIDPOINT for the WHOLE visible food. integer. it MUST be consistent with count × portion (5 fried pieces ≈ 5× one piece). account for prep: deep-fried/breaded adds ~10-20% oil weight (~80-150 kcal per fist-size serving); a glossy sauce/dressing adds 50-200 kcal and MUST be counted (a dressed salad's dressing is often most of its kcal); cheese finish ~110 kcal/30g.",
    "- kcal_low / kcal_high are HONEST bounds: ±15% confident & counted; ±20% amorphous in a shallow bowl; ±30% opaque/deep bowl; +10% each for occlusion, hidden oil/sauce, or no scale reference; ±40% a guess. cap ±50%.",
    "- ROUND kcal + bounds to buckets: <200 round to 10; 200-600 round to 25; >600 round to 50. e.g. 347→350, 423→425, 712→700.",
    "- protein_g / carbs_g / fat_g / fiber_g: integer grams for the WHOLE visible food (chicken breast ~25g protein/100g, cooked rice ~28g carb/100g, avocado ~15g fat/100g).",
    "- total_kcal_low / total_kcal_high: sum of items' kcal_low / kcal_high. integer.",
    "",
    "=== OTHER FIELDS ===",
    "- confidence ∈ [0,1]: 1.0 obvious single dish with a clear scale ref; 0.5 ambiguous count/portion; <0.5 guess. LOWER it when you couldn't count cleanly or had no scale reference.",
    "- needs_second_photo: true ONLY when a 2nd angle would materially cut the error — opaque-bowl depth on the dominant-kcal item, a stack whose count you can't resolve, hidden oil/sauce volume, or food cropped off-frame. otherwise false.",
    "- second_photo_hint: one short sentence with the angle that resolves it.",
    "- plate_type: 'single' one dish, 'mixed' separated items, 'bowl' layered (smoothie/poke/acai), 'charcuterie' snack plate, 'shared' a table/platter for several, 'restaurant_range' a menu-described estimate.",
    "",
    "common cohort foods to recognize confidently (gen-z women weight-loss context):",
    "- drinks: iced matcha latte (oat 200 kcal / almond 150 / whole 240), oat milk latte (180), cold brew black (5), boba brown sugar (380), boba taro (350), americano (15), chai latte oat (230), pink drink (140)",
    "- breakfast: avocado toast (280), avocado toast + egg (350), greek yogurt + berries (200), overnight oats (380), acai bowl (480), smoothie bowl (420), magic spoon cereal + milk (140)",
    "- lunch: chipotle chicken bowl (700), sweetgreen harvest (700), cava bowl (700), chick-fil-a sandwich (440), salmon rice bowl (600), sushi roll 8pc (400)",
    "- dinner: pad thai (700), pizza slice (320), pasta plate (700), burger (550), tacos (450 for 2)",
    "- snacks: crumbl cookie (700), halo top pint (280-360), popcorn (150 / cup), string cheese (80), apple (95)",
    "- if you recognize a chain item, prefer the chain's published kcal over your prior.",
    "",
    "=== WORKED EXAMPLES (follow this reasoning, then emit only JSON) ===",
    "A — a plate of ~5 stacked fried chicken pieces, dinner plate, no rice: 5 discrete pieces (count even the partly-hidden one) → count=5, unit='piece', each ~palm-size ~90g → portion_grams≈450, deep-fried, one piece ~250 kcal → ~1250. single plate → servings_in_dish=1, is_shareable=false. name_native='fried chicken'.",
    "B — korean bbq beef with onions over rice: this is bulgogi, not 'stir-fried beef'. continuous → count=1, unit='serving', cuisine_hint='korean', servings_in_dish=1, is_shareable=false. name_native='bulgogi', english_name='marinated grilled beef'.",
    "C — a whole 12-inch pepperoni pizza on the table: kcal is for the WHOLE pizza (~2200), NOT a slice. count=8, unit='slice', servings_in_dish=8, is_shareable=true. the app lets the user say they ate 2 slices.",
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
    // 2026-06-23 — JSON, not plain text, so the iOS error decoder can
    // parse it (every response the client can receive is now JSON).
    return new Response(
      JSON.stringify({ error: "method_not_allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------- Auth ----------
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "missing_auth" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabaseUserClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authErr } = await supabaseUserClient.auth.getUser();
  if (authErr || !user) {
    return new Response(
      JSON.stringify({ error: "invalid_auth" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const userId = user.id;

  // Admin client for telemetry + limit checks (bypasses RLS).
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // ---------- Limit checks ----------

  // 2026-06-23 — run the two Supabase count/sum queries CONCURRENTLY
  // instead of sequentially. They're independent, and on a warm table
  // each is a round-trip; back-to-back they added ~2-4s of dead time to
  // every scan before OpenAI even started (part of the founder's "takes
  // a long time"). Promise.all overlaps them.
  const [userLimit, budget] = await Promise.all([
    checkPerUserLimit(supabaseAdmin, userId),
    checkDailyBudget(supabaseAdmin),
  ]);
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

  let body: {
    image_base64?: string;
    text?: string;
    cuisine_profile?: string;
    dietary_profile?: string;
  };
  try {
    body = await req.json();
  } catch (_e) {
    return new Response(
      JSON.stringify({ error: "invalid_body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  // v1.0.9 D1 — accept EITHER an image OR a free-text description.
  // Text-only requests cost ~5× less than vision (no image tokens),
  // route through the same JSON schema, and unlock the quick-add
  // surface where the user types "two slices pepperoni pizza" and
  // gets kcal + macros without taking a photo.
  const imageBase64 = body.image_base64;
  const textDescription = body.text?.trim();
  const hasImage = imageBase64 && imageBase64.length >= 100;
  const hasText = textDescription && textDescription.length >= 2;

  if (!hasImage && !hasText) {
    return new Response(
      JSON.stringify({ error: "missing_input", detail: "provide either image_base64 or text" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const cuisineProfile = body.cuisine_profile ?? null;
  const dietaryProfile = body.dietary_profile ?? null;

  // ---------- LLM call ----------

  const systemPrompt = buildSystemPrompt(cuisineProfile, dietaryProfile);

  // GPT-5 + o1-class reasoning models use `max_completion_tokens`
  // instead of the legacy `max_tokens`. gpt-4o still accepts
  // `max_tokens`. Detect by model name.
  const isGpt5OrReasoning = MODEL_NAME.startsWith("gpt-5") ||
                            MODEL_NAME.startsWith("o1") ||
                            MODEL_NAME.startsWith("o3");

  // GPT-5 reasoning models reject custom temperature; gpt-4o accepts
  // it. Drop temperature for gpt-5 to avoid API errors.
  // v1.0.9 D1 — branch the user content based on input type.
  // Image path stays unchanged. Text path drops image_url and sends
  // the typed description as the only content. System prompt is the
  // same — the model's macro-estimation rules apply identically to
  // text-described foods as to photographed ones.
  let userContent: unknown;
  if (hasImage) {
    userContent = [
      { type: "text", text: "what is on this plate? estimate kcal + macros directly." },
      {
        type: "image_url",
        image_url: {
          url: `data:image/jpeg;base64,${imageBase64}`,
          detail: "high",
        },
      },
    ];
  } else {
    // Text-only quick-add. Anchor the prompt so the model treats
    // the description as the SINGLE meal and returns one or more
    // items reconstructed from the user's words.
    userContent = [
      {
        type: "text",
        text:
          `the user ate: "${textDescription}". ` +
          `estimate kcal + macros directly. ` +
          `if the description is multi-item (e.g. "chicken bowl + iced latte"), ` +
          `return one item per food. ` +
          `if portion size isn't specified, assume one standard serving and reflect that in confidence + the kcal_low/high range.`,
      },
    ];
  }

  const openaiRequest: Record<string, unknown> = {
    model: MODEL_NAME,
    messages: [
      { role: "system", content: systemPrompt },
      {
        role: "user",
        content: userContent,
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
  // 2026-06-23 — the fetch AND the response-body read now run under ONE
  // AbortController. The old code cleared the timer BEFORE
  // `openaiResponse.json()`, leaving that body read unbounded — a stalled
  // body would hang to Supabase's ~150-160s kill and surface to iOS as a
  // 504 with a non-JSON HTML body (the opaque "very long hang"). Now the
  // body read is inside the abort budget.
  //
  // Lowered 90s → 26s so the server sits UNDER the iOS client's network
  // timeout (30s) + scan deadline (35s): the server aborts and returns a
  // structured `openai_timeout` envelope BEFORE the client gives up,
  // instead of the client timing out into a raw NSURLErrorTimedOut. gpt-4o
  // vision median is a few seconds, so 26s still clears the vast majority.
  const OPENAI_TIMEOUT_MS = 26_000;
  const openaiAbort = new AbortController();
  const openaiTimer = setTimeout(() => openaiAbort.abort(), OPENAI_TIMEOUT_MS);

  let openaiBody: {
    choices: { message: { content: string } }[];
    usage?: { prompt_tokens: number; completion_tokens: number };
  };
  try {
    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: openaiAbort.signal,
      headers: {
        "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")!}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openaiRequest),
    });

    if (!openaiResponse.ok) {
      const errorBody = await openaiResponse.text();  // still inside abort budget
      clearTimeout(openaiTimer);
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
      // Surface the OpenAI message (insufficient_quota / model_not_found)
      // instead of a bare 502. Falls back to raw text when not JSON.
      let userFacing = errorBody;
      try {
        const parsed = JSON.parse(errorBody);
        userFacing = parsed?.error?.message ?? parsed?.error?.code ?? errorBody;
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

    // THE read that used to hang — now covered by openaiTimer.
    openaiBody = await openaiResponse.json();
    clearTimeout(openaiTimer);
  } catch (e) {
    clearTimeout(openaiTimer);
    const isAbort = (e as Error)?.name === "AbortError";
    console.error(
      `[food-vision] OpenAI ${isAbort ? `TIMEOUT (${OPENAI_TIMEOUT_MS}ms)` : "failed"}: ${String(e)}`,
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
        code: isAbort ? "openai_timeout" : "upstream_unreachable",
        detail: String(e),
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

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
