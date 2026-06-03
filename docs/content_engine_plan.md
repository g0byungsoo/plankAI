# JeniFit Content Engine — Plan (2026-06-01)

Semi-autonomous AI-persona content pipeline for TikTok + Instagram, scaling
from 5–10 accounts → 25+ with a virality + conversion feedback loop. Budget:
<$150/mo recurring; upgrade path to higher tiers as ROI proves out.

Companion to: `docs/onboarding_conversion_pass_2026.md`,
`docs/first_screen_marketing.md`.

---

## 1. Decision summary

**Shape**: Lean Python + cron + Supabase + Claude API + Flux 1.1 Pro (Fal) +
one-time persona LoRA on Replicate + official TikTok Content Posting API
(Upload-to-Inbox = draft mode) + official Instagram Graph API (container-
create-without-publish = effective draft).

**Why not local Flux on the M1 iMac**: 16 GB forces Q4 quantization, no real
LoRA training on Apple Silicon, 90–180 s/image vs 3 s in cloud. Use the iMac
for cron + Supabase mirror + Postiz if needed — not generation.

**Why not an agent framework** (OpenClaw, Hermes, Claude Agent SDK, LangGraph):
The pipeline is deterministic (gather signals → generate slides → queue draft →
poll metrics → re-rank). Agent loops add token spend without accuracy on linear
flows. "Learning" is a nightly SQL aggregate + few-shot injection, not a loop.

**Why not SaaS** (Predis, Captions Ditto, Higgsfield-only, Arcads): none expose
the format-winner loop, none scale to 25 accounts under our budget. Generation-
only category; ignores the learning + attribution problem.

---

## 2. Stack comparison

Volume basis: 10 accounts × 5 posts/wk × 10 slides ≈ 800 images/mo + 800
captions/hashtag sets.

| Layer | A — Lean Python (rec.) | B — n8n self-hosted | C — SaaS hybrid |
|---|---|---|---|
| Image gen | Flux 1.1 Pro on Fal + 1× LoRA ($2 one-time) | Same | Higgsfield Plus |
| Slide-1 hook typography | Ideogram 3.0 ($0.04/img, ~20/mo) | Same | Built-in |
| Orchestration | Python 3.12 + cron on M1 iMac | n8n self-host on M1 | Make.com |
| LLM (caption/format) | Claude Sonnet 4.6 + prompt cache | Same | Claude via Make |
| Queue | Supabase Postgres | Supabase | Make data store |
| TikTok posting | Official Content Posting API (Inbox) | Official API via n8n | Ayrshare |
| IG posting | Official Graph API (container, no publish) | Same | Ayrshare |
| Analytics | Apify clockworks/tiktok-scraper + IG Insights | Same | EnsembleData |
| Attribution | ASC campaigns + TikTok Pixel + Branch via RC | Same | Same |
| **Monthly cost (10 accts)** | **~$70** | **~$65** | **~$390** |
| Time to v1 | ~2 weekends | ~1 weekend | ~1 day |
| Scale to 25 accts | Add rows | Workflow duplication friction | Per-seat pricing balloons |
| Loop sophistication | High (full SQL + pgvector) | Medium (DAG limits) | Low (vendor opaque) |

Recommendation: **A**. B is tempting for a weekend prototype, but the moment
the loop needs `last_week_format_score > 0.7 AND niche_match` style logic
you're writing JS in n8n Code nodes — Python beats that. Build A from day 1.

### Detailed monthly cost (Stack A, 10 accounts)

| Line item | Cost |
|---|---|
| Fal.ai Flux 1.1 Pro — 800 imgs @ $0.04 | $32 |
| Ideogram 3.0 — 20 hook slides @ $0.04 | $0.80 |
| Replicate persona LoRA training (one-time) | $2 |
| Claude Sonnet 4.6 (captions + format ranking + cache) | ~$15 |
| Apify TikTok scraper @ $1.70 / 1 k results | ~$10 |
| Supabase (free tier covers it until ~25 accts) | $0 → $25 |
| Cloudflare R2 (image hosting for PULL_FROM_URL) | ~$3 |
| Beacons Creator (smart-link UTM) | $10 |
| **Total at 10 accounts** | **~$71/mo** |
| Projected at 25 accounts | ~$155–$190/mo |

At 25 accounts the budget tips just over $150 — that's the natural moment to
re-evaluate paid scheduler (Ayrshare) vs continued in-house, and to consider
Flux Schnell ($0.003/img) for B-tier accounts.

---

## 3. Compliance + ban-risk checklist

- **TikTok Content Posting API audit** = critical path. 1–4 weeks, multi-round.
  Until cleared: SELF_ONLY visibility, 5 users / 24 h. Submit before writing
  any code. Need: privacy policy URL (we have `docs/privacy_policy.md`), demo
  video of OAuth + upload, data-handling write-up.
- **AI-content disclosure**: pass the platform's "is AI" flag manually on every
  upload. Auto-detected labels (TikTok's C2PA scanner hits 94.7 % on synthetic
  faces; Meta auto-applies "AI Info") are reach-suppressed; manual disclosure
  is not.
- **Persona authenticity**: original character; cannot resemble a real public
  figure. Document the seed-prompt + LoRA reference set internally so we can
  prove originality if challenged.
- **Posting cadence per account**: TikTok ≤25 videos/account/day (real limit
  far lower for organic safety — keep ≤3/day per account); IG 100/24 h cap.
- **OAuth + IP hygiene at 25 accounts**: rotate residential IPs at scale
  (Bright Data / Iproyal ~$15/mo / GB tier). Don't co-locate 25 logins on one
  iMac IP.
- **No unofficial scraper APIs** on accounts we care about. Apify on our own
  logged-in business accounts only.
- **TikTok Pixel on jenifit.app**: keep `ttclid` in cookie + post server-side
  via Events API; EMQ ≥ 7 needed for usable match rate.

---

## 4. Persona spec

Single AI character (working name TBD), original, not a real person's likeness:

- Late-20s woman, fit-not-shredded, soft-pink coquette wardrobe palette
  matching `docs/THEME.md`, warm-cool skin, brown-blonde hair.
- 15–20 reference images for the LoRA: portrait + 3/4 + side, varied lighting,
  no extreme poses. Generate the seed set with Flux 1.1 Pro + a tight prompt,
  hand-curate, then train.
- Voice in captions = our `feedback_voice_signals.md` rules: lowercase casual,
  italic-Fraunces punch words, no AI-language, hearts as terminal punctuation
  only.
- Persona file lives at `content_engine/personas/jeni_v1.md` with the
  canonical prompt + LoRA trigger token + variant guidelines.

Plan for the 25-account future: 3–5 persona variants (different ethnicity,
hair, vibe) with **shared voice + format library** but distinct LoRAs. Avoids
the "ten accounts, same face" tell that gets flagged as a network.

---

## 5. Feedback loop schema (Supabase)

Lives in a new Supabase project — not the JeniFit user-data project — to keep
content-engine ops isolated from production user data.

```
accounts            (account_id, platform, handle, persona_id, oauth_json,
                     created_at, status)

personas            (persona_id, name, lora_url, reference_image_urls[],
                     voice_rules_md, created_at)

formats             (format_id, archetype, slot_count, hook_pattern,
                     cta_pattern, example_post_ids[], score, last_used_at)

posts               (post_id, account_id, platform, persona_id, format_id,
                     posted_at, asset_urls[], hook_text, caption,
                     gen_params jsonb, branch_link, asc_campaign_token,
                     ai_label_flag bool, status)
                    -- status: draft|queued|posted|failed

post_metrics        (post_id, snapshot_at, views, watch_time_s,
                     completion_rate, saves, shares, profile_visits,
                     comments, follows_attributed)

attribution         (post_id, day, asc_downloads, asc_ppv, branch_clicks,
                     branch_installs, rc_trials, rc_paid)

generations         (gen_id, persona_id, format_id, parent_post_ids[],
                     embedding vector(1024), prompt, model, output_asset_url,
                     created_at)

learnings           (cohort, signal, lift_pct, p_value, period,
                     summary_md, applied_to_format_id)
```

pgvector + Jina CLIP v2 embeddings on `generations` for retrieval-augmented
prompts. Top-N viral by `saves/views` → seed next-day generation.

---

## 6. Phased build plan

Each phase ends with a working, observable artifact. Build + commit between
phases; do not bundle.

### Phase 0 — Critical-path unblock (week 1)

- [ ] Submit TikTok Content Posting API audit (privacy policy + demo video).
- [ ] Apply for Meta Developer + Instagram Graph API access (business verification).
- [ ] Pick + register persona name; decide on @handle availability across 10
  TikTok + 10 IG accounts (reserve them now).
- [ ] Create Supabase project `jenifit-content`. Run schema in §5.
- [ ] Provision Cloudflare R2 bucket for image hosting; verify domain.
- [ ] Train v1 persona LoRA on Replicate ($2). Curate 15–20 references.
  Validate identity lock across 5 test prompts.

**Exit**: TikTok audit in flight, persona LoRA trained, Supabase queue ready.

### Phase 1 — Generation pipeline, no posting yet (week 2)

- [ ] `content_engine/generate.py` — Claude Sonnet 4.6 picks format from the
  `formats` table, drafts hook + caption + 10-slide concept JSON.
- [ ] `content_engine/render.py` — Fal Flux 1.1 Pro renders 10 slides, Ideogram
  renders slide-1 typography overlay, composites with PIL.
- [ ] Outputs land in Supabase `posts` with `status='draft'`, asset URLs on R2.
- [ ] Local-only review CLI: `content_engine/review.py` prints + opens drafts.

**Exit**: end-to-end generation produces 10-slide carousels we'd actually
post. Hand-validate aesthetic, voice, and persona identity on 20 sample posts
before continuing.

### Phase 2 — Draft posting + analytics polling (week 3)

- [ ] `content_engine/publisher.py` — pushes Supabase drafts to TikTok Inbox
  via Content Posting API (`PULL_FROM_URL` on R2 image URLs); creates IG
  containers via Graph API without publishing. Slack/email DM to user with
  the inbox-ready signal so user attaches sound + publishes.
- [ ] `content_engine/poll_metrics.py` — daily cron polls TikTok (Apify) + IG
  (Graph Insights) into `post_metrics`.
- [ ] `content_engine/attribution.py` — nightly join of ASC campaign tokens
  + Branch webhook events into `attribution`.

**Exit**: 5 real accounts each posting 2 drafts/day; metrics + attribution
landing in Supabase.

### Phase 3 — Feedback loop closure (week 4)

- [ ] `content_engine/learn.py` — nightly: ranks formats by saves/views +
  completion + profile-visit rate, updates `formats.score`, embeds top
  performers into `generations`.
- [ ] `generate.py` retrieves top-N similar viral posts from pgvector and
  injects as few-shot examples in the Claude prompt.
- [ ] Simple Streamlit dashboard at `content_engine/dash.py` for the user to
  watch the loop work.

**Exit**: format ranking visibly shifts week-over-week; new posts inherit
winners.

### Phase 4 — Scale to 25 accounts (month 2+)

- [ ] Account onboarding script: OAuth handshake per account stored
  encrypted; persona assignment.
- [ ] Residential proxy rotation (Iproyal/Bright Data).
- [ ] Cron parallelism via APScheduler with per-account rate limits.
- [ ] Re-evaluate Ayrshare vs in-house posting (budget tipping point).

**Exit**: 25 accounts running on $150–200/mo with no manual touch beyond
draft approval + sound selection.

### Phase 5 — Video (month 3+)

- [ ] Add Higgsfield Ultra or Veo 3 / Runway Gen-4 to render 8-12s talking-
  head / B-roll clips from persona LoRA stills.
- [ ] `render.py` branches by `format.media_type`.
- [ ] Repeat the validation cycle: 10 sample videos hand-reviewed before
  enabling.

---

## 7. Tutorial — Phase 0 + 1 step-by-step

### 7.1 Submit TikTok Content Posting API audit

1. Create a TikTok for Developers account (use your bay82 studio email).
2. Create a new app. Add scopes: `user.info.basic`, `video.upload`,
   `video.publish`.
3. Fill the privacy policy + terms URLs from `docs/privacy_policy.md` +
   `docs/terms_of_service.md` (hosted at jenifit.app/privacy + /terms).
4. Record a 60-90 s demo video: OAuth login → trigger inbox upload → show the
   draft landing in the TikTok app.
5. Submit. Expect 1–4 weeks. Audit status check via the developer console.

### 7.2 Provision Supabase + R2

```bash
# Supabase
supabase init jenifit-content
# paste §5 schema into supabase/migrations/0001_init.sql
supabase db push

# R2
brew install cloudflare-wrangler
wrangler r2 bucket create jenifit-content-assets
wrangler r2 bucket cors put jenifit-content-assets --rules cors.json
# set up a custom domain (cdn.jenifit.app/content/*) for PULL_FROM_URL
```

### 7.3 Train the persona LoRA on Replicate

1. Generate 15–20 candidate persona images with Flux 1.1 Pro and a tight
   prompt (see `content_engine/personas/jeni_v1.md`).
2. Hand-pick 12–15 with consistent face, varied angles + outfits.
3. Upload as a single zip to Replicate.
4. Train via `ostris/flux-dev-lora-trainer` or `replicate/fast-flux-trainer`.
   ~20 min, ~$2.
5. Save the LoRA URL + trigger token into `personas.lora_url`.
6. Validate: 5 prompts at varied scenes, check identity lock.

### 7.4 Phase-1 file layout

```
content_engine/
  README.md
  pyproject.toml
  .env.example
  config.py
  models/
    __init__.py
    db.py           # Supabase client
    schemas.py      # Pydantic models matching §5
  personas/
    jeni_v1.md
  formats/
    seed_formats.yaml
  generators/
    captions.py     # Claude Sonnet 4.6 prompts
    slides.py       # Fal Flux 1.1 Pro + Ideogram
    composite.py    # PIL compositing
  pipelines/
    generate.py
    render.py
    review.py
  publishers/       # phase 2
    tiktok.py
    instagram.py
  analytics/        # phase 2-3
    poll_metrics.py
    attribution.py
    learn.py
  cron/
    schedule.yaml
  tests/
```

### 7.5 First-run end-to-end

```bash
cd content_engine
uv sync                  # or poetry install
cp .env.example .env     # fill Fal, Ideogram, Anthropic, Supabase, R2 keys
python -m pipelines.generate --persona jeni_v1 --count 3
python -m pipelines.render --queue draft
python -m pipelines.review --status draft
```

Hand-review the 3 posts. Iterate persona prompt + format YAML until 80 %
land on-brand. Then enable Phase 2 posting.

---

## 8. Open decisions

- **Persona handle + visual identity** — needs founder pick before Phase 0.
- **Privacy policy hosting** — currently a draft in repo; needs to live at
  `jenifit.app/privacy` before TikTok audit submission.
- **Voice clip cross-pollination** — should the content engine reuse the
  voice tone from `docs/workout_session_rules.md`? Probably yes, but a single
  hand-curated `voice.md` co-located with the engine is cleaner than coupling.
- **Where does video sit on the timeline** — Phase 5 is "month 3+"; if early
  carousels hit a ceiling we accelerate.

---

## 9. Out of scope (this doc)

- Paid ads / Apple Search Ads strategy (separate concern; see
  `aso-skills:apple-search-ads`).
- The JeniFit app changes (deep links, attribution endpoints) — track
  separately in `TODOS.md` once Phase 2 lands.
- Founder-mode marketing channels beyond TikTok + Instagram.

---

## 10. Sources

Image gen: Fal.ai pricing; BFL Flux Kontext; Gemini 2.5 Flash Image
multi-ref; Higgsfield pricing; Ideogram 3.0 API; Replicate LoRA training;
Draw Things on Mac Mini benchmarks.

Posting: TikTok Content Posting API docs + Inbox upload; Instagram Graph
API publishing; Ayrshare + Blotato + Postiz; Meta AI labeling policy;
TikTok AI disclosure rules 2026.

Analytics + attribution: Apify clockworks/tiktok-scraper; EnsembleData;
Instagram Graph Insights + 2025 deprecations; Apple ASC campaign tokens;
RevenueCat ↔ Branch integration; TikTok Pixel + Events API + EMQ.

Orchestration: Hermes Agent + OpenClaw frameworks (June 2026 state);
Anthropic third-party agent billing change June 2026; Claude Agent SDK
billing; n8n vs Make pricing 2026; agent framework comparison
(LangGraph, PydanticAI, CrewAI).
