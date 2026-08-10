# APP v25 — THE SYSTEM · the founder's brief (verbatim, 2026-08-10)

This file preserves the era-opening directive word for word. It is
the source law for v25. `00_THE_SYSTEM.md` (the master product plan)
is its executed answer; `99_WORKING.md` is the era ledger.

---

APP v25 — THE SYSTEM

This is a PRODUCT ARCHITECTURE era before it is an implementation era.

Do not immediately start adding features.

Do not interpret this prompt as a checklist of things the founder has already decided.

The founder is describing problems, ambitions, and hypotheses.

Your job is to research them, challenge them, simplify them, and turn them into one coherent product.

You have permission to disagree with specific feature ideas if research, user value, product coherence, safety, or retention suggests a better solution.

Use your judgment.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THE PRODUCT

Jeni is evolving from a consumer weight-loss app into one adaptive weight-loss system with two modes:

CONSUMER
and
CLINIC-CONNECTED.

These must NOT become two separate apps.

They must feel like the same product and the same Jeni.

The difference is authority.

For a consumer:

Jeni + the user determine the program.

For a clinic-connected patient:

the clinician can prescribe or configure parts of the program,
and Jeni helps the patient actually live it.

This distinction should become structural throughout the product.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THE PRODUCT THESIS

Jeni should eventually answer one question extraordinarily well:

"What should I do today to lose weight safely and sustainably?"

The answer should become better as Jeni learns more.

Food.
Weight.
Medication.
Steps.
Sleep.
Activity.
Adherence.
Symptoms.
Behavior.
Progress.
Clinician instructions.

These should NOT become ten dashboards.

They are signals feeding ONE adaptive program.

Today is where the program becomes action.

Jeni is where the program becomes understanding.

Becoming is where the program becomes evidence.

The clinician dashboard is where care becomes configurable.

Preserve that simplicity.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FIRST: UNDERSTAND THE EXISTING PRODUCT

Before proposing anything:

Read the entire canonical product state.

Read:

CLAUDE.md
docs/STATE.md

and all relevant recent era documents, especially v21–v24.

Inspect the actual implementation.

Do not infer the current product from documentation alone.

Walk the app.

Record it.

Understand every existing major system:

onboarding
cohort routing
Today
Jeni
Scan
Becoming
food
medication
weight
body
method
breathwork
workout
steps
sleep
notifications
settings
authentication
sync
analytics

Understand what is actually shipping versus what merely exists in documentation.

Also inspect:

/Users/bko/jeni-health-web

This is the clinician web project.

Understand its current architecture and capabilities.

Do not modify it yet.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECOND: RESEARCH THE CATEGORY

Use the web extensively.

Do not rely on memory.

Study current 2025–2026 products and research across:

consumer weight loss
GLP-1 companion apps
food logging
AI food recognition
behavior-change programs
activity coaching
sleep and weight management
digital obesity management
telehealth weight management
remote patient monitoring
clinician obesity workflows
patient adherence
notification design
health-app retention

Study products including but not limited to:

MeAgain
Shotsy
Noom
WeightWatchers
MyFitnessPal
Lose It
MacroFactor
Cronometer
Cal AI
Oura
WHOOP
Apple Health
Fitbit
Omada
Virta
Twin Health
Ro
Hims & Hers

These are references, not a copying list.

Look beyond them.

Find smaller products doing unusually good work.

Read reviews and community discussions.

Look specifically for:

what people love
what they abandon
what becomes tedious
what they repeatedly request
what users pay for
what clinicians actually need
what patients fail to report
what creates adherence
what creates retention
what creates notification fatigue
what information changes decisions
what information merely creates dashboard clutter

Separate:

proven patterns
promising ideas
marketing claims
medical evidence
category conventions
gimmicks

Cite the research in the product document.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THIRD: AUDIT JENI AS A SYSTEM

For every existing feature ask:

1. What user problem does this solve?

2. For whom?

3. How frequently does that problem occur?

4. Does solving it improve:
   weight-loss outcome,
   adherence,
   understanding,
   retention,
   or clinician efficiency?

5. Is Jeni uniquely positioned to solve it?

6. Does it deserve a permanent surface?

7. Could Jeni solve it automatically instead?

8. Could it simply become intelligence feeding Today or Jeni?

9. Does it create user work without enough value?

10. Should it exist at all?

Be ruthless.

More features is not the goal.

Less user work with more intelligence is the goal.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THE CONSUMER PRODUCT

The current hypotheses are below.

Do NOT blindly implement them.

Research and improve them.

━━━━━━━━━━━━━━━━━━

JENI

Jeni should become the intelligence layer across the product.

Today it must not feel like a chatbot bolted onto a tracker.

Jeni should understand the user's real longitudinal data where appropriate:

food
nutrition
weight trend
steps
sleep
medication
dose timing
symptoms
activity
program adherence
recent behavior
progress

A user should naturally be able to ask things such as:

"Why did my weight stall?"

"How did I eat this week?"

"Am I getting enough protein?"

"What should I eat tonight?"

"I feel nauseous after my shot."

"Should I walk more today?"

"Why am I more hungry this week?"

"What changed since last month?"

Jeni should use tools and structured data rather than inventing answers.

Research how to make this useful without creating unsafe medical advice.

Determine what belongs in:
conversation,
proactive insight,
Today,
Becoming,
or notification.

━━━━━━━━━━━━━━━━━━

FOOD

Treat food as a flagship capability.

It may be one of the strongest acquisition and retention loops in the entire product.

Audit:

photo capture
camera
barcode
nutrition label
recognition
portion estimation
nutrition lookup
result correction
meal editing
food journal
history
search
favorites/repeat meals if appropriate
error handling
confidence
offline behavior
sync

Nutrition currently matters beyond calories.

At minimum investigate:

calories
protein
carbohydrates
fat
fiber
sugar
sodium

But do not assume every metric deserves equal visual weight.

Research what weight-loss users and GLP-1 users actually benefit from seeing.

Accuracy is more important than visual theater.

Investigate ways to combine:

vision
barcode databases
nutrition labels
food databases
user history
portion context
targeted clarification

to improve accuracy.

A beautiful wrong answer is a product failure.

Food data must then create downstream value.

Explore how the journal can generate useful:

daily reads
weekly patterns
protein/fiber guidance
meal suggestions
repeat-meal intelligence
progress correlations
Jeni context
Today actions
notifications

Do not turn this into obsessive nutrition policing.

━━━━━━━━━━━━━━━━━━

MEDICATION

v24 built THE REGIMEN.

Do not rebuild it because competitors have more screens.

Audit it against current GLP-1 products and real user needs.

Investigate:

dose adherence
dose changes
oral vs injectable
injection rotation
side effects
hydration
protein/fiber relevance
constipation / GI context
missed doses
travel/timezones
progress across dose eras
questions worth bringing to clinicians
clinician-shareable summaries
medication changes
stopping/pausing
compounded medication realities

Determine what v24 already solves beautifully.

Find genuine gaps.

Only recommend additions with strong user value.

Never fabricate pharmacokinetic precision.

Never cross from tracking/education into unsupported medical advice.

━━━━━━━━━━━━━━━━━━

THE METHOD

Assume the current Method is NOT sacred.

It was designed for an earlier product and an earlier female-focused positioning.

Users currently do not meaningfully engage with it.

Research what content or intervention belongs inside a modern weight-loss companion.

Do not assume CBT lessons are the answer.

Investigate:

behavior change
implementation intentions
habit formation
environment design
emotional eating
cravings
mindful eating
relapse recovery
maintenance
GLP-1 adaptation
protein and muscle preservation
sleep
movement
food literacy
weight plateaus
self-efficacy
motivational interviewing
micro-learning

Study how successful apps deliver education without making the app feel like homework.

Perhaps Method should remain.

Perhaps it should become something completely different.

Decide.

The unit of content should earn the user's attention.

━━━━━━━━━━━━━━━━━━

MOVEMENT / WORKOUT

Jeni used to be a workout app.

That history should not dictate the future.

Research whether the current workout sessions deserve to exist.

Possible futures include:

5-minute movement
10-minute movement
walking
mobility
stretching
Pilates-inspired sessions
strength-preservation sessions
post-meal walks
exercise logging
Apple Health automatic recognition
or something else.

Do not choose based on founder suggestion alone.

Determine what best complements weight loss rather than trying to compete with dedicated fitness apps.

We should probably not build a mediocre Nike Training Club.

Find Jeni's wedge.

━━━━━━━━━━━━━━━━━━

STEPS

Apple Health should minimize manual work.

Investigate:

step history
walking distance
active energy where scientifically appropriate
goal setting
adaptive goals
progression
rest/recovery
streak psychology
post-meal walking
sedentary patterns

The founder hypothesis:

Today should be able to create a walking action.

Example concept:

"2,100 steps left"

But research whether steps, minutes walking, or another representation is behaviorally superior.

The default goal should not simply be an arbitrary 10,000.

Design a safe evidence-informed adaptive goal system.

Users may override it.

━━━━━━━━━━━━━━━━━━

SLEEP

Do not add a sleep dashboard merely because Apple Health exposes sleep.

Research what sleep information actually changes a weight-management decision.

Ask:

What can Jeni infer responsibly?

What should influence Today?

What belongs in Becoming?

What belongs in Jeni context?

What is actionable?

If sleep adds no useful action, reduce its surface.

━━━━━━━━━━━━━━━━━━

BREATHWORK

Audit the existing feature.

Determine its actual role in this product.

If it remains, redesign it into the current Jeni visual system.

But first establish why it deserves to exist.

Potential roles might include:

stress
craving interruption
sleep transition
emotional eating
pre-meal regulation

Research instead of assuming.

━━━━━━━━━━━━━━━━━━

NOTIFICATIONS

Treat notifications as a product system, not reminders sprinkled across features.

Research modern notification retention practices.

Design a notification intelligence model.

Potential sources:

medication
meal rhythm
protein/fiber gaps
walking
weigh-ins
weekly review
clinician instructions
unfinished actions
meaningful milestones
re-engagement

But notification volume must be constrained.

Every notification should answer:

Why now?

Why this user?

Why is opening Jeni valuable right now?

Determine intelligent defaults.

Users must have understandable controls.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THE CLINIC-CONNECTED PRODUCT

Do not create a second app inside Jeni.

The clinic-connected patient should still experience Jeni.

But establish a hierarchy of authority.

Think in terms of:

CLINICIAN PRESCRIBED
JENI RECOMMENDED
USER PREFERRED

These must not silently overwrite one another.

Research the right model.

Potential clinician-configurable areas include:

medication regimen
step/activity target
program actions
educational content
breathwork availability
movement
notifications
check-ins
nutrition priorities
Jeni behavior/context

But clinicians should NOT be forced to configure everything.

Defaults must be excellent.

The clinic should intervene only where intervention creates value.

A clinic-connected patient without custom configuration should still have a complete product.

━━━━━━━━━━━━━━━━━━

CLINICIAN-TUNED JENI

Research how this should actually work.

Do not expose a giant raw prompt textbox unless that is truly the best design.

Consider structured controls such as:

care philosophy
approved education
priorities
patient instructions
escalation rules
tone
prohibited advice
clinic resources
program templates

Determine the safest and most usable architecture.

The clinician should be able to shape Jeni without destroying Jeni.

━━━━━━━━━━━━━━━━━━

CLINICIAN DASHBOARD

Inspect:

/Users/bko/jeni-health-web

Research what an obesity / GLP-1 clinician actually needs to know.

Do not simply mirror every patient metric.

The dashboard should reduce clinical work.

Investigate whether clinicians need:

patient roster
attention queue
adherence
weight trajectory
medication history
side-effect changes
nutrition risk signals
activity
patient questions
check-ins
program configuration
notes
messaging
export/report
trend summaries
exceptions requiring review

The key question is:

"What deserves the clinician's attention?"

Design around that.

Not around charts.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THE ADAPTIVE PROGRAM

This may become the most important architecture in Jeni.

Investigate creating one central system that converts longitudinal signals into a small number of useful daily actions.

Inputs may include:

goal
weight trend
food
protein
fiber
steps
sleep
activity
medication
symptoms
recent adherence
clinician instructions
preferences

Outputs should remain SMALL.

Perhaps 1–3 meaningful actions.

Never produce a 14-item health checklist.

The system should understand uncertainty.

It should know:

what we know
what we infer
what the clinician prescribed
what Jeni recommends
what the user changed

Define this architecture carefully.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RETENTION

Do not use dark patterns.

Research healthy retention loops.

Find Jeni's natural loops.

Possible examples:

SNAP → UNDERSTAND → NEXT ACTION

DOSE → OBSERVE → PATTERN

WALK → CLOSE THE LOOP

WEEK → REVIEW → ADAPT

ASK JENI → UNDERSTAND → ACT

CLINICIAN PLAN → DAILY ACTION → EVIDENCE → CLINICIAN

Determine which loops deserve to define the product.

The goal is not app opens.

The goal is useful repeated behavior that makes the product increasingly valuable.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESIGN

The current Jeni visual identity matters.

Do not redesign Home or Becoming casually.

Study the existing design language before extending it.

Every new surface must feel unmistakably Jeni.

Premium.

Modern.

Minimal.

Warm without being feminine-coded.

Clinical without becoming hospital software.

Calm without becoming boring.

Native without becoming generic SwiftUI.

Every screen should be recognizable as Jeni even if:

the logo is hidden
the title is hidden
the tab bar is hidden.

Use:

spacing
typography
material
motion
cards
charts
photography
micro-interactions
visual rhythm

to create identity.

Avoid:

generic gradients
dashboard soup
excessive cards
random pills
gratuitous glass
AI-looking decoration
emoji as design
gamification without purpose

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DO NOT START BUILDING THE WHOLE THING.

This era's primary deliverable is the MASTER PRODUCT PLAN.

Create:

docs/app_v25/00_THE_SYSTEM.md

It should become the canonical specification for the next several product eras.

It must contain:

1. PRODUCT THESIS — What Jeni is. What Jeni is not.

2. USER MODES — Consumer. Clinic-connected. Authority hierarchy.

3. RESEARCH — Competitors. Research. User pain. Market patterns. Sources.

4. CURRENT PRODUCT AUDIT — Keep. Improve. Rebuild. Remove.

5. INFORMATION ARCHITECTURE — What belongs in: Today, Jeni, Scan,
   Becoming, Settings, Clinician dashboard.

6. DATA ARCHITECTURE — How the major signals connect.

7. ADAPTIVE PROGRAM — Inputs. Rules. Uncertainty. Outputs. Overrides.

8. JENI INTELLIGENCE — Tools. Context. Safety. Proactivity.

9. FEATURE STRATEGY — Food, Medication, Movement, Steps, Sleep,
   Method, Breathwork, Notifications, Weight/body, and anything
   important discovered through research.

10. B2B CONTROL MODEL — What clinicians can prescribe. What they can
    configure. What they can observe. What they should NOT control.

11. CLINICIAN DASHBOARD — The minimum lovable clinical product.

12. RETENTION LOOPS — Why people return.

13. SAFETY / PRIVACY / MEDICAL BOUNDARIES

14. ANALYTICS — How we know each system is working.

15. ROADMAP — Break implementation into independent eras. For each
    era specify: goal, user problem, scope, non-goals, dependencies,
    data changes, tests, success criteria.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRIORITIZE.

Use something stronger than a feature wishlist.

Score major opportunities by:

user value
frequency
retention potential
weight-loss relevance
B2C value
B2B value
differentiation
evidence
implementation complexity
clinical/safety risk

Then recommend the order.

It is acceptable to say: do not build this.

It is acceptable to merge features.

It is acceptable to radically simplify an existing feature.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERY IMPORTANT:

Do not optimize for the number of things Jeni can do.

Optimize for:

VALUE / USER EFFORT.

Every additional tap is a cost.

Every manual log is a cost.

Every notification is a cost.

Every dashboard is cognitive cost.

Apple Health, camera intelligence, existing history, clinician
configuration, and Jeni's own data should eliminate work whenever
possible.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WHEN THE PLAN IS COMPLETE

Do NOT immediately implement all eras.

Instead:

walk the existing product again.

Compare every major screen and flow against THE SYSTEM.

Create a visual/product gap map.

Rank the gaps.

Then choose ONLY the highest-leverage first implementation era.

Write its detailed brief.

Stop there and present:

WHAT JENI BECOMES

WHAT WE KEEP

WHAT WE KILL

WHAT WE BUILD

WHY

THE IMPLEMENTATION ERAS

THE FIRST ERA TO EXECUTE

and the biggest product insight discovered during research.

Do not ask the founder routine questions.

Research and make decisions.

Ask only when a decision truly cannot be recovered from:

the codebase
the existing docs
the clinician web project
research
or product judgment.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WORKING METHOD

Keep yourself organized with documentation so intent survives context compaction and future sessions.

Commit documentation as you go.

Do not overwrite historical product intent.

Record decisions and rejected alternatives.

And throughout all future implementation eras:

Build the real feature.

Then manipulate the simulator yourself.

Walk every state.

Record the simulator.

Dump animation frames.

Inspect transitions.

Inspect pixels.

Test accessibility sizes.

Test empty data.

Test realistic data.

Test malformed data.

Test offline states.

Test old accounts.

Test new accounts.

Test consumer accounts.

Test clinic-connected accounts.

Test clinician overrides.

Find your own mistakes.

Fix them.

Repeat.

Pixel-perfect means verified, not claimed.

Functional means exercised, not compiled.

Integrated means downstream data was observed, not merely written.

Do not stop because the build succeeded.

Do not stop because tests passed.

Do not stop because one screenshot looks beautiful.

The product is finished only when the loop works.
