# Onboarding v7 — Research Digest (four lanes, distilled)

2026-08-02. Four independent web-research lanes run before any design
decision, per the founder's brief ("Research the best onboarding and
subscription flows… extract the underlying principles, then improve
upon them"). Full lane reports with citations: `research/lane1_clinical_
products.md` (Noom/Ro/Calibrate/Found/Omada/Sequence/Virta) ·
`research/lane2_subscription_mechanics.md` (Cal AI/PrayerLock/Blinkist/
Oura/Flo + RevenueCat/Adapty/Superwall data) · `research/lane3_trust_
register.md` (Monzo/Trading212/Hinge/Feeld/NHS/GOV.UK/Stripe) ·
`research/lane4_behavioral_science.md` (primary literature). This
digest keeps only what CHANGES v7 decisions. It extends — does not
repeat — `docs/onboarding_v6/02_RESEARCH.md`, which remains valid.

## The eleven findings that fund v7's workstreams

1. **The question-audit lens is unanimous across lanes.** Kristen
   Berman (GLP-1 funnel work): "Ask the one question that changes the
   journey, not ten that change nothing." growth.design: every question
   asked is a personalization debt that must be visibly repaid. Named
   anti-pattern (Noom critique): "medical-looking questions that only
   serve segmentation — if a clinical-feeling question never changes
   the plan, users eventually feel it." Noar 2007 meta-analysis:
   tailoring persuades only when downstream content actually varies.
   → The founder's rule ("if a question changes nothing, remove it")
   is the literature's rule. W3 executes it with the data-flow audit.

2. **"Why we ask" belongs ON the question.** GOV.UK sensitive-question
   pattern; Noom's rationale lines ("Sex and hormones impact how our
   bodies metabolize food"); Dillon-Mansfield's golden rule (if nobody
   can answer why we ask, don't ask). v6 put provenance on ANSWERS
   (number + unit + basis); v7 extends provenance to QUESTIONS — a
   one-line mechanism clause on every sensitive or clinical ask.

3. **Sex/gender: ask where physiology needs it, explain right there,
   and the branch must be real.** GOV.UK two-question model; consensus
   rule (sex only for clinical relevance — a weight app has the
   legitimate claim, "which is precisely why it must show its work").
   Jeni's branch IS real (Mifflin-St Jeor sex term, ~230 kcal/day).
   Prefer-not-to-say routes to a stated default, never a silent one.
   → Funds W1: gender early, explained, and consequential — and the
   flow downstream of the answer must stop assuming "her" for male
   users (the founder's own male walk hit "sign her in").

4. **The falsifiability test for personalization.** Barnum effect
   (Forer 1949): copy that would survive any set of answers is a
   horoscope, and it detonates trust when spotted. Hawkins/Kreuter:
   feedback (her data played back) and content-matching (routed
   content) are the heavy levers; the name is the lightest.
   → W4's audit test for every receipt/reveal/wall line: "would a
   different answer have produced a different line?"

5. **Concreteness IS the warmth.** Packard & Berger (JCR 2021, five
   studies): concrete language makes customers measurably more
   satisfied and more likely to buy because it signals being heard;
   "your money back" beats "your refund". NHS/Monzo/Mailchimp voice
   guides converge: clear beats entertaining as a WRITTEN tiebreaker,
   plain term first then the clinical term, no metaphors, active
   voice, warmth-placement matrix (zero wit on operational surfaces).
   → W2's mechanical law. "you've got this ❤" loses to "your first
   check-in takes about 90 seconds" on BOTH warmth and credibility.

6. **Autonomy-supportive language predicts weight-loss adherence;
   controlling language and shame measurably backfire.** Williams/
   Grow/Ryan/Deci 1996 (JPSP): autonomous motivation predicted
   attendance, loss, and 23-month maintenance. Puhl & Heuer 2010:
   stigma predicts increased eating and dropout. Gallagher &
   Updegraff 2012: gain frames beat loss frames for prevention
   behaviors. MI/OARS: reflect the disclosure back before asking the
   next thing.
   → W2 bans controlling verbs (must/should/need to), keeps the
   anti-shame law, frames past attempts as method failures, and makes
   the act receipts do reflective listening with plan consequences.

7. **Hedged, two-sided claims INCREASE trust.** Jensen 2008 (N=601):
   sources hedging their own claims were rated MORE trustworthy.
   Eisend 2006 meta-analysis: two-sided messages outperform one-sided
   on credibility, most for skeptics. Trading212's mandated 79%-lose-
   money disclosure correlates with HIGHER reviewer trust; Wise built
   the brand on unprompted honesty.
   → "an estimate, not a promise." is validated law. v7 extends the
   stated-refusal register: the honest floor spoken unprompted
   (slowest-first-week truth, what the program will not do) is a
   conversion asset, not a concession.

8. **Every disclosure needs a visible downstream consequence.**
   Noom's diabetes answer triggers tailored follow-ups; the ONE
   branch that didn't follow up was flagged by reviewers as a broken
   promise. Reciprocity law: never ask twice without giving once; no
   more than ~4-5 consecutive asks without a give-back.
   → W3/W4 meter the acts and wire silent answers into acks,
   receipts, or plan deltas — or cut the question.

9. **Show the product; sell the program object; deliver the verdict
   free.** The sharpest documented critique of the category's best
   funnel (Noom): "I still don't know what the app experience
   actually looks like." Calibrate sells a named program with a term
   and phases, not a subscription. WW Clinic determines eligibility
   before payment details.
   → v6's Day-1 mock + curve-first reveal are validated; W5 sharpens
   the wall's program-object framing (her plan on one page, named
   term, what each surface does) without touching structure.

10. **The outcome-selling register (Hinge) is the category's unmade
    move.** "Designed to be deleted" is operational philosophy, not
    slogan — and no weight app credibly says "built to be outgrown."
    Jeni's product truth supports the SOFT claim (the program has a
    last day; the keeping chapter exists; maintenance is the
    destination). The HARD claim (citing hold rates) is founder-gated
    on real instrumentation (the "did it hold?" loop).
    → W5 candidate copy: name the end state at the wall. Never cite
    uninstrumented outcomes.

11. **Compliance floors moved again (2026).** Apple rejects trial-
    toggle mechanics under 3.1.2 (Jan 2026) and rating prompts inside
    onboarding under 5.6.3; FTC v. NextMed (2025) is the enforcement
    template for fabricated weight-loss proof; weight loss is a
    priority FTC category. Jeni's laws already sit on the right side
    of every line. The pre-wall reviewGate stays a SENTIMENT ask
    only (F1) — it must never become a StoreKit prompt pre-purchase.

## Benchmarks (unchanged targets, richer context)

Hard-paywall D35 download→paid: 10.7% median, >20% top quartile, no
1-yr retention penalty vs freemium (RevenueCat SOSA 2026). Multi-page
value-recap paywalls: 12.41% vs 9.07% single-page (Superwall, 40M+
opens). 50-80% of subscription revenue lands in the first hour
(Phiture) — the wall IS the business. PrayerLock's founder-reported
~43% and Noom's 10%+ quiz-completer conversion are pre-sold-traffic
ceilings, not cold-install targets. v6's target band (paywall-view →
purchase toward 12.4%) stands; v7 adds no new metric contract —
measurement rides the v6 funnel (03_RELEASE.md) so before/after reads
directly in PostHog under `onboarding_version`.

## The ethical constitution (consolidated, all four lanes)

Refuse: fabricated statistics/citations/testimonials · fake timers,
scarcity, or labor theater over templated output · Barnum copy sold as
analysis · shame as a lever · hidden totals, drip pricing, fake "was"
prices · manufactured sunk cost (questions the plan never uses) ·
lying progress bars · blocking or guilt-tripping the exit · weaponized
intake data (using her disclosed fears/medication to pressure). The
literature's through-line: the honest variant of every mechanism is
also the durable high-converting one; disclosed nudges remain
effective (Cambridge BPP). Jeni's existing constitution already
matches — v7 changes register and wiring, not ethics.
