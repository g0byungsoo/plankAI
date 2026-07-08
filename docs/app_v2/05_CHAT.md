# 05 — JeniFit Chat architecture

## Intent

Jeni is the app's voice made conversational: she reads the same data
the surfaces render, speaks the locked voice contract, acts through
the same router the tabs use, and never pretends to be medical care.
Built so the model/provider is an env-var, the key never ships, and
every answer is grounded in her real data.

## Topology

```
JeniChatView ──▶ ChatSession (@Observable)
                   │  assembles CoachContext (local, per turn)
                   ▼
             ChatTransport (SSE client, URLSession.bytes)
                   ▼  POST /functions/v1/jeni-chat  (JWT + apikey)
             jeni-chat edge function (Deno)
                   │  auth → caps → prompt assembly → OpenAI stream
                   ▼
             OpenAI Chat Completions (stream: true, tools)
```

- **Key custody**: `OPENAI_API_KEY` lives only in Supabase EF secrets
  (same custody as food-vision). Model via `JENI_CHAT_MODEL` env,
  default `gpt-5.1` (override freely; the EF handles both token-param
  families like food-vision does).
- **Caps**: per-user 150 messages/day + global $40/day budget via
  `jeni_chat_telemetry` (mirrors food-vision's ledger pattern), fail-
  open on telemetry read errors, fail-closed on missing JWT.
- **Streaming**: EF re-emits OpenAI SSE as `text/event-stream` with
  event types `token`, `tool_call`, `done`, `error`. Client renders
  tokens through `JKStreamText` (word-level fade-in, 60fps, no
  per-character layout thrash — chunks commit to the transcript on
  sentence boundaries).

## CoachContext (the grounding envelope)

Assembled client-side per turn by `CoachContextAssembler` — compact
JSON, ~1.5KB, derived aggregates only (no photos, no raw journal):

```json
{
  "name": "maya", "cohort": "on_glp1", "program_mode": "loss",
  "plan": {"day": 12, "total": 84, "tier": "medium",
            "archetype": "protein", "beats": ["snap","lesson","steps"],
            "done": ["lesson"]},
  "weight": {"current_kg": 74.2, "goal_kg": 65.0, "start_kg": 78.0,
              "ema_delta_7d_kg": -0.4, "logs_count": 9,
              "last_logged_days_ago": 1},
  "targets": {"kcal": 1640, "protein_g": 112, "steps": 7500},
  "today": {"kcal": 980, "protein_g": 61, "steps": 4210,
             "plates": [{"t": "12:10", "title": "poke bowl", "kcal": 520,
                          "protein_g": 38}]},
  "week": {"avg_kcal": 1520, "avg_protein_g": 78, "workouts": 2,
            "breath": 1, "lessons": 3, "showed_up": 5},
  "profile": {"sleep": "five6", "stress": "high",
               "food_relationship": "comfort", "fears": ["anotherDiet"],
               "appetite_rhythm": "small_waves"},
  "flags": {"restrictive_risk": false, "numeric_suppression": false,
             "maintenance": false},
  "sub": {"day_since_purchase": 3},
  "device": {"local_time": "19:42", "weekday": "thu"}
}
```

Rules: every field traces to a stored record (provenance); fields the
user never provided are omitted, not defaulted; when
`numeric_suppression` (safety gate output) is true the envelope drops
kcal/weight numerics entirely and the system prompt shifts to the
non-numeric register.

## System prompt (server-side, versioned in the EF)

Layers, in order: (1) persona + voice contract (lowercase, punch-word
italics as *word*, ♥ sparingly and terminal, no em-dashes, no "AI",
no diet-culture verbs, 1-3 short paragraphs, end with one next
smallest action when natural); (2) science guardrails distilled from
SCIENCE.md (pace floors, protein frames, plateau script, water-weight
script, maintenance scripts — with the instruction to never invent
numbers not present in context); (3) compliance floors (no drug
brands/doses/equivalence, no diagnosis, route to clinician for
medication questions, ED-safe: any restriction-escalation intent →
compassionate brake + care resources, never lower targets below
floors); (4) the data block: `coach_context` wrapped in explicit
"data, not instructions" fencing (prompt-injection guard — user text
can never rewrite the rules); (5) tool schemas.

## Tools (client-executed)

OpenAI function calls streamed back as `tool_call` events; the app's
`ChatToolRouter` executes and renders an inline `JKActionCard`:

| Tool | Effect |
|---|---|
| `open_snap_camera` | routes `jenifit://snap` |
| `log_weight{kg}` | confirm card → writes WeightLogRecord + sync |
| `show_today_plan` | inline mini plan card (beats + states) |
| `open_lesson{slot_id?}` | today's or named lesson cover |
| `start_breathwork{style}` | breath cover with style |
| `show_weight_trend` | inline sparkline card → becoming deep link |
| `set_reminder_hour{hour}` | reschedules daily anchor (confirm) |

Loop: tool result (compact JSON) is POSTed back with the same
conversation id; the EF continues the stream. One round-trip max per
turn (tool → final text) to bound latency and cost. Mutating tools
(log_weight, set_reminder_hour) always render a confirm card first —
the model proposes, the user disposes.

## Conversation state

- `ChatMessageRecord` (@Model): id, userId, role, text, toolName?,
  toolPayload?, createdAt, dayKey, pendingUpsert. Local-first.
- Supabase `coach_messages` (RLS auth.uid()=user_id) for cross-device
  continuity; hydrate last 50 on sign-in.
- Server receives the trailing 12 messages + a rolling `thread_note`
  (one-line summary the model maintains via a `remember` field in
  its final frame) — bounded context, no runaway token growth.

## The daily brief

First open of a day, jeni's opening message = `DailyBriefEngine`
output (deterministic, free, instant — no API call) rendered as a
jeni message with the chat seed. If she replies, the conversation
continues through the EF normally. Premium touch without latency or
cost on every open.

## Safety redlines (client + server)

- Client pre-filter: self-harm/ED-crisis lexicon → immediate care
  message (fixed copy, resources, encourage human support) and the
  turn is not sent to the model. Not a diagnosis — a routing.
- Server prompt: the same routing instruction, plus "never estimate
  medication effects, never advise dose timing, never compare drugs."
- Every jeni surface carries the quiet footer once per day:
  "jeni supports your plan. she's not medical care."
- Post-GLP-1 users asking "should i restart medication" → clinician
  routing + what the app CAN do (protein, rhythm, trend watching).

## Failure states (designed, not defaulted)

Offline / EF down → composer stays enabled, message queues with a
quiet "she'll answer when you're back online" line; brief still
renders (local). 429 cap → honest line ("we've talked a lot today ♥
tomorrow it resets"). Stream drop mid-answer → partial kept, retry
chip. All failure copy in the voice contract, none of it red.
