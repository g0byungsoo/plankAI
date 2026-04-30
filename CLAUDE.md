## Project status (2026-04-30)

- **Auth + sync**: functional end-to-end. Anonymous-first Supabase auth, Apple + email
  upgrade, sign-in recovery. Profile + session_logs + day_progress sync via typed
  Codable upserts; cross-account isolation enforced via @Query userId filters in
  HomeView/AnalyticsView; UUID case normalized at hydrate boundaries. Verified on
  device with two distinct Apple IDs (test 1/2/3 in commit 2d9c34c).
- **Payment (RevenueCat)**: next major work block. Not started. New Claude Code
  session will own this.
- **Phase G (end-to-end smoke test on physical device)**: pending. Includes
  DebugAuthView removal once production surfaces are stable.
- **Open items**: Camera permission flow + v1.1 anon→auth data-preservation
  (see TODOS.md).

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
