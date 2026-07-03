# 23 — Setup ritual (v2.6 RC)

The enrollment subflow's redesign, staged-safe across v2.3 + v2.6.
Data bindings and ProgramService.startProgram writes byte-identical
throughout; everything below is chrome, order, and language.

## What shipped
- v2.3: scrapbook chrome → hairline register (borders, shadows,
  progress bar, chevron) across all three pages.
- v2.6: the commitment page became the ritual close:
  - "make it *official*." hero (kept) over "day one is *today*." —
    the old "starts tomorrow" contradicted the mechanics
    (startDate = startOfDay(.now)) and surrendered day-0 activation,
    the exact cliff in the retention data (44% D1).
  - "today, day one" preview (numbered stickies, real tier numbers).
  - NEW "jeni carries" block: your protein number, sized to you ·
    your trend line, read weekly, never daily · your plan, resized
    when life happens. (The program watches FOR her.)
  - NEW doable line: "sized to your floor, not your best day.
    that's why it holds."
  - CTA: "i'm in".

## The six questions, answered on-screen
what is my program → the window + pace pages · what am I committing
to → "i'm in" under the day-one preview · what happens today → the
preview rows · what will jeni track → "jeni carries" · why different
→ carries + the doable line · why doable → floor-sizing line + the
safety-capped pace math underneath it.

## Review note
Shot 91_setup_commitment.png. If any copy line misses your register,
they're all in ProgramSetupSubflow.swift marked "v2.6 RC".
Deliberately NOT changed: page order (window → pace → commit is
sound), the safety-cap math, the ACSM citation chip.
