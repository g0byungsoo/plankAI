# app v8 — THE CARE PLATFORM (founder brief, 2026-07-28)

Founder: "Jeni is no longer a consumer calorie tracker. Jeni is
becoming the most beautiful AI care platform ever built." Today it
serves consumers; tomorrow it naturally serves obesity clinics,
GLP-1 practices, preventive medicine, longevity clinics, concierge
medicine, physician-led wellness — **without rebuilding the app**.
Every decision improves today's consumer experience while reducing
the work to ship tomorrow's configurable clinic platform. Optimize
for the company in three years, not for today's app.

This is a product evolution, not a design iteration. Research
precedes implementation; recommendations carry evidence; the
session documents decisions, tradeoffs, postponements, and
founder-approval items here in `docs/app_v8/`.

## 0. Doc set

| file | holds |
|---|---|
| `00_MISSION.md` | this brief digested; law reconciliation; the evolution ladder; tensions |
| `01_RESEARCH.md` | clinical/behavioral evidence synthesis (cited) |
| `02_COMPETITORS.md` | B2B clinic platforms + consumer program teardowns (cited) |
| `03_ARCHITECTURE.md` | the care-protocol data architecture + migration path |
| `04_DECISIONS.md` | decision log: choice · evidence · tradeoffs · postponed · needs-founder |
| `05_BUILD.md` | shipped record as phases land |

Lineage: this pulls **v7 thesis §11 phase 5** (ObservationStore ·
CareProtocol · BrandVoice — "the invisible white-label seam")
forward from last phase to center of the product, and extends
`04_CLINICAL_CHECKLIST.md` (the clinic data instrument) from
checklist items into a configurable protocol. Where older docs
disagree with this set, this set wins; where this set is silent,
STATE.md §-7 law stands.

## 1. The felt sentence

v7: *"I don't have to think about everything anymore. jeni is
already paying attention."* v8 keeps it and adds the platform
sentence beneath: **"my care plan for today"** — the same surface a
clinic patient will one day open, with her clinic's protocol
flowing through the same records. The consumer IS the default
tenant.

## 2. The evolution ladder (consumer → coach → patient → clinic)

Architecture stages; each stage ships consumer value alone:

- **S0 (yesterday):** protocol implicit — composition rules and
  clinical constants scattered in engine code.
- **S1 (this pass):** *protocol as data.* `CareProtocol` config +
  regimen (medication/supplement) plans + typed `ObservationStore`
  exist as records; `CarePlanEngine` composes the day FROM them;
  the consumer experience is the default protocol instance.
  Nothing clinic-shaped renders.
- **S2:** *protocol served.* The default protocol + content atoms
  hydrate from Supabase rows (still one tenant); notifications,
  education, chat prompts become authored data, not code.
- **S3:** *a human on the other end.* Care-team read surfaces:
  visit-prep packet, data export, roster view — the coach/patient
  chapter.
- **S4:** *tenancy.* Organizations author protocol templates,
  assign patients, re-voice `BrandVoice`. White-label.

Rule for S1: every table/record ships **tenant-friendly** (stable
ids, protocol/plan provenance on instances, org seam nullable) but
**no clinic configuration is exposed anywhere**.

## 3. What stands (law this pass does NOT reopen)

- The three tabs; the signals engine + its safety law (v6
  00_RESEARCH §4 — observed-never-prescribed; "fasting" never
  renders); provenance law (every number traces to a collected
  field); targets math + cohort pace floors; auth/sync isolation;
  paywall/pricing mechanics; the safety gate (SCOFF/pregnancy/BMI)
  and the wellness-side SaMD line (educate/track/behavioral —
  never diagnose, never dose, never interpret labs).
- The editorial constitution (03_EDITORIAL composition laws: one
  owner per page, bracketed emptiness, three tiers, controls
  dissolve into content, chrome ceiling) — the brief's design
  section ("less decoration, more typography, more restraint")
  is the SAME direction, pushed further.
- Compliance floors: no drug brand names on app-controlled
  surfaces (Apple 5.2.1); no drug-equivalence claims; no "GLP-1
  alternative" framing; no first-party numeric weight-loss claims;
  no feature promises until shipped.
- Founder-locked Home GRAMMAR (2026-07-27): sticker-badged
  checklist + day rail + tools rail + metric rings. v8 evolves
  what the rows ARE (features → protocol items), not the grammar
  they wear.

## 4. What this pass evolves

1. **The protocol object.** The day's checklist stops being an
   arrangement of app features (snap/weigh/move/method/breath) and
   becomes an instance of a care protocol (the shape research must
   confirm: medication → meals/protein → hydration → movement →
   reflection → sleep). CarePlanEngine keeps composing by state;
   the *vocabulary of composable items* becomes data.
2. **Medication first-class.** From a dose-day evening mark to a
   regimen model (medication + supplement plans), checklist
   presence, adherence-evidence-shaped reminders, side-effect
   tie-in. Supplements' relationship to medication and the
   consumer default (supplements-first?) are research questions,
   not assumptions.
3. **The database foundation.** Programs, phases, protocol items,
   medication/supplement plans, care-plan records, protocol
   rules, content atoms, knowledge docs — present in the schema,
   additively, multi-tenant-friendly, unexposed.
4. **Onboarding reframed.** From "downloading a calorie tracker"
   to "beginning care" — one intake architecture that a consumer
   self-serves today and a clinic patient enters tomorrow.
5. **The language register.** Every sentence audited toward
   clinical-calm (plain, professional, reassuring, zero
   diet-culture / influencer residue) inside the editorial voice.
6. **Interaction perfection + self-verification.** Handcrafted
   feel on every changed surface; a recorded-frames QA loop, not
   trust-by-eyeball.

## 5. Tension log (brief ↔ standing law), with resolutions

| # | tension | resolution |
|---|---|---|
| T1 | Clinical-calm register vs lowercase-casual + hearts voice | Typography/composition/lowercase stay; **vocabulary** completes the v6→v7 direct-register trajectory (plain verbs, zero cutesy). Hearts stay on jeni-authored lines only (v7 budget). Founder flag if research says hearts break clinical trust. |
| T2 | "Challenge the checklist" vs yesterday's checklist lock | The lock is the FORM (rows + stickers + check-off). The content evolves features → protocol. Research decides items; form persists. |
| T3 | Sticker badges vs "never look trendy" | v7 material law already splits daily (typographic) from earned (glossy). Stickers on rows are a founder lock — kept; flagged in 04_DECISIONS if evidence says clinical protocol reads demand quieter marks. |
| T4 | "AI care platform" mission vs "no AI word in user copy" | Both stand: AI is company/positioning language, never in-app copy. |
| T5 | Medication first-class vs Apple 5.2.1 / brand names | Generic surfaces app-authored ("your medication", "dose day"); her own entered names render display-only where SHE reads them, never in notifications, never app-authored claims. Verify against research + 5.2.1 precedent before shipping name display. |
| T6 | Multi-tenant schema vs HIPAA/BAA deferral (medical-grade spec) | S1-S2 stay consumer/wellness-side (no PHI custodianship claims, no clinic accounts). HIPAA/BAA + FHIR interop remain the S3/S4 gate — flagged, not built. |

## 6. Session honesty

One session cannot land S1-S4. The commitment: research synthesized
with citations; the S1 foundation (records + engine seam + regimen)
implemented and tested; Home protocol + language register evolved
behind the founder-locked grammar; onboarding rearchitected on
paper with the highest-leverage stage implemented; every
postponement and founder-approval item written down in
`04_DECISIONS.md`, not silently dropped.
