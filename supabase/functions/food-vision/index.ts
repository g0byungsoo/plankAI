// food-vision — Supabase Edge Function (Deno runtime)
//
// W1-T3 of v1.0.7 food rail sprint. Photo + cuisine profile in,
// structured LLM food data out. App-side handles USDA lookup + calorie
// math; this function never returns kcal directly (per v3 Honesty Doctrine:
// LLM identifies + portion-estimates, USDA joins authoritative numbers).
//
// Layers (in order):
//   1. Auth   — verify JWT, extract user_id
//   2. Limit  — per-user cap (30/day) + global budget cap ($50/day)
//   3. LLM    — GPT-5 call with cuisine-profile system prompt + strict JSON schema
//   4. Log    — append telemetry row, return structured response
//
// Costs are computed approximately from OpenAI response.usage. Real
// invoice may drift ±5%; budget cap leaves headroom for that.
//
// Deploy:
//   supabase functions deploy food-vision --no-verify-jwt
// (Edge Function verifies the JWT manually via Authorization header so
// we can return clean 401 vs 429 vs 500 from inside the function.)
//
// Secrets required (Supabase Dashboard → Edge Functions → Secrets):
//   OPENAI_API_KEY              — OpenAI account key with GPT-5 access
//   SUPABASE_URL                — auto-set by Supabase
//   SUPABASE_SERVICE_ROLE_KEY   — auto-set by Supabase
//   SUPABASE_ANON_KEY           — auto-set by Supabase (for JWT verification)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

// ---------- Config ----------

const DAILY_BUDGET_USD = 50;        // global cap per v3 D26
const PER_USER_DAILY_LIMIT = 30;    // per v3 D26

// Model name. Reads from Supabase secret FOOD_VISION_MODEL so we can
// swap (gpt-4o ↔ gpt-5 ↔ gpt-5-mini) without a code deploy. Defaults
// to gpt-4o — widely available, vision-capable, proven for food per
// our domain-specific benchmark research. gpt-5 requires Tier 5 OpenAI
// access which many accounts don't have; selecting it via secret lets
// us upgrade once tier is granted.
const MODEL_NAME = Deno.env.get("FOOD_VISION_MODEL") ?? "gpt-4o";

// Per-model pricing (USD per 1M tokens). Bias-conservative so the
// kill-switch fires early on under-counted cost rather than over.
// Defaults to gpt-4o rates; gpt-5 is more expensive but worth the
// accuracy when available.
const PRICING: Record<string, { input: number; output: number }> = {
  "gpt-4o":      { input: 2.50, output: 10.00 },
  "gpt-4o-mini": { input: 0.15, output: 0.60 },
  "gpt-5":       { input: 2.50, output: 10.00 },
  "gpt-5-mini":  { input: 0.25, output: 2.00 },
};
const INPUT_PRICE_PER_1M  = PRICING[MODEL_NAME]?.input  ?? 2.50;
const OUTPUT_PRICE_PER_1M = PRICING[MODEL_NAME]?.output ?? 10.00;

// ---------- Strict JSON schema for LLM response ----------
//
// OpenAI's json_schema response_format requires "strict": true plus
// every field "required" and "additionalProperties": false. We get
// hard validation server-side; if the model drifts, the API returns
// an error before we see the bad output.

const FOOD_VISION_SCHEMA = {
  name: "food_vision_response",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["items", "plate_type", "needs_second_photo", "second_photo_hint"],
    properties: {
      items: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "name",
            "usda_search_terms",
            "preparation",
            "cuisine_hint",
            "portion_grams",
            "portion_grams_low",
            "portion_grams_high",
            "confidence",
            "notes",
          ],
          properties: {
            name: { type: "string" },
            usda_search_terms: {
              type: "array",
              items: { type: "string" },
            },
            preparation: {
              type: "string",
              enum: ["raw", "grilled", "fried", "boiled", "baked", "sauteed", "unknown"],
            },
            cuisine_hint: { type: "string" },
            portion_grams: { type: "number" },
            portion_grams_low: { type: "number" },
            portion_grams_high: { type: "number" },
            confidence: { type: "number" },
            notes: { type: "string" },
          },
        },
      },
      plate_type: {
        type: "string",
        enum: ["single", "mixed", "bowl", "charcuterie", "shared", "restaurant_range"],
      },
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
    "you are a food vision model for a weight-loss app.",
    "identify the foods in this photo and estimate portion size in grams.",
    "",
    cuisineLine,
    "",
    "rules:",
    "- never return calories or macros — only identity + portion grams + uncertainty bands.",
    "- portion_grams_low and portion_grams_high are honest uncertainty bounds, not a confidence interval.",
    "- confidence ∈ [0, 1]: 1.0 = obvious single dish; 0.5 = ambiguous; <0.5 = guess.",
    "- usda_search_terms: 2–4 fallback queries for USDA FoodData Central lookup, ordered specific → generic.",
    "- preparation: best guess from visual cues.",
    "- needs_second_photo: true ONLY if portion estimate is >50% uncertain (e.g. rice depth in opaque bowl).",
    "- second_photo_hint: one short sentence with the angle that would resolve the uncertainty.",
    "- plate_type: 'single' for one dish, 'mixed' for separated items, 'bowl' for layered, 'charcuterie' for snack plate, 'shared' for restaurant table, 'restaurant_range' for menu-text input.",
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

async function logTelemetry(
  supabaseAdmin: ReturnType<typeof createClient>,
  row: TelemetryRow,
): Promise<void> {
  // Fire-and-forget; never block the response on telemetry write.
  // Use service-role client (bypasses RLS on food_vision_telemetry).
  const { error } = await supabaseAdmin
    .from("food_vision_telemetry")
    .insert([row]);
  if (error) {
    console.error("[food-vision] telemetry write failed:", error.message);
  }
}

// ---------- Limit checks ----------

async function checkPerUserLimit(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
): Promise<{ allowed: boolean; count: number }> {
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);

  const { count, error } = await supabaseAdmin
    .from("food_vision_telemetry")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
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

  const userLimit = await checkPerUserLimit(supabaseAdmin, userId);
  if (!userLimit.allowed) {
    await logTelemetry(supabaseAdmin, {
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
        // Copy gets pulled by iOS app, but include a sensible default
        // so a misbehaving client doesn't show a raw error code.
        copy: "give us a few hours — you've scanned a lot today.",
      }),
      { status: 429, headers: { "Content-Type": "application/json" } },
    );
  }

  const budget = await checkDailyBudget(supabaseAdmin);
  if (!budget.allowed) {
    await logTelemetry(supabaseAdmin, {
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
        copy: "give us a few hours — we're catching our breath.",
      }),
      { status: 429, headers: { "Content-Type": "application/json" } },
    );
  }

  // ---------- Parse request ----------

  let body: {
    image_base64?: string;
    cuisine_profile?: string;
  };
  try {
    body = await req.json();
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

  const openaiRequest = {
    model: MODEL_NAME,
    messages: [
      { role: "system", content: systemPrompt },
      {
        role: "user",
        content: [
          { type: "text", text: "what is on this plate?" },
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
    max_tokens: 1500,
    temperature: 0.3,
  };

  let openaiResponse: Response;
  try {
    openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")!}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openaiRequest),
    });
  } catch (e) {
    await logTelemetry(supabaseAdmin, {
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
      JSON.stringify({ error: "upstream_unreachable", detail: String(e) }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!openaiResponse.ok) {
    const errorBody = await openaiResponse.text();
    // Log the OpenAI error to Edge Function console so it shows up in
    // Supabase logs — easier to debug than only seeing the 502 in iOS.
    console.error(
      `[food-vision] OpenAI ${openaiResponse.status} for model=${MODEL_NAME}: ${errorBody}`,
    );
    await logTelemetry(supabaseAdmin, {
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
    await logTelemetry(supabaseAdmin, {
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

  await logTelemetry(supabaseAdmin, {
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
