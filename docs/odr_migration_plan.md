# On-Demand Resources migration plan

JeniFit's iOS bundle is currently ~176 MB after music compression. Apple's
200 MB cellular-download threshold is the conversion cliff: cross it and
users see a "WiFi required" warning before install (~30% abandon in
international markets). Adding AI calorie tracking even cloud-based could
nudge over the line; on-device Core ML models definitely will.

On-Demand Resources (ODR) is Apple's free CDN-backed mechanism for
shipping app assets that download AFTER install. Tagged resources don't
count against the install download. Supported since iOS 9; well-documented.

## Target

| Phase | Bundle install size | Headroom for AI features |
|---|---|---|
| Current | ~176 MB | ~24 MB before cellular cliff |
| After Phase 1 (music ODR) | ~163 MB | ~37 MB |
| After Phase 2 (per-coach voice ODR) | ~135 MB | ~65 MB |
| After Phase 3 (lesson illustrations + lottie ODR) | ~120 MB | ~80 MB |

Phase 2 alone gets us under 150 MB. That's the realistic minimum-effort
state to ship before any major AI feature lands.

## Phase 1 — Music ODR (~13 MB savings)

**Effort:** ~2 hours. Lowest risk.

### Implementation

1. **Tag music files in Xcode:**
   - Select each `.mp3` in `PlankApp/Resources/Music/` in project navigator
   - File Inspector → "On Demand Resource Tags" → add tag `music-pack-1`
   - All 9 files get the same tag (small set, no per-file granularity needed)
   - The files are now stripped from the install bundle; downloaded on demand

2. **Refactor `BackgroundMusicService` to request before play:**
   ```swift
   private var resourceRequest: NSBundleResourceRequest?

   func start() {
       guard !isMuted else { return }
       guard player == nil else { return }

       // Phase 1: ensure music pack is downloaded
       if resourceRequest == nil {
           let request = NSBundleResourceRequest(tags: ["music-pack-1"])
           request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
           request.beginAccessingResources { [weak self] error in
               guard error == nil else {
                   #if DEBUG
                   print("[BackgroundMusicService] ODR fetch failed: \(String(describing: error))")
                   #endif
                   return
               }
               // Resources now available in the bundle path. Pick a random track.
               DispatchQueue.main.async { self?.startPlayingNow() }
           }
           self.resourceRequest = request
       } else {
           startPlayingNow()
       }
   }

   private func startPlayingNow() {
       // existing logic that finds a track + creates the AVAudioPlayer
   }
   ```

3. **First-launch UX:** the first workout will spend 1-3s downloading music
   on cellular before BGM starts. Voice cues + workout proceed normally.
   Subsequent sessions are instant (Apple caches the pack).

4. **Prefetch hook:** add `request.beginAccessingResources()` in `PlankAIApp`
   `.task` on first launch so the music pack starts downloading in the
   background WHILE the user is in onboarding — they don't notice the wait.

### Testing
- Fresh install on TestFlight: confirm music plays in first workout
- Airplane mode + first workout: confirm graceful degradation (workout continues, no music)
- Background → foreground after pack purged: confirm re-fetch

## Phase 2 — Per-coach voice clips ODR (~25-30 MB savings)

**Effort:** ~6-10 hours. Medium complexity.

### Implementation

1. **Tag voice clips by coach prefix in Xcode:**
   - All `jeni_*.m4a` files → tag `voice-jeni`
   - All `matson_*.m4a` files → tag `voice-matson`
   - All non-prefixed files (Kira base) → tag `voice-kira`
   - Generic non-coach clips (countdown_beep, etc.) stay bundled (small, always needed)

2. **Refactor `RoutineAudioManager` to fetch the user's coach pack on app launch:**
   ```swift
   func prefetchCoachVoicePack() {
       let pref = UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging"
       let tag: String
       switch pref {
       case "encouraging": tag = "voice-jeni"
       case "balanced":    tag = "voice-matson"
       default:            tag = "voice-kira"
       }
       let request = NSBundleResourceRequest(tags: [tag])
       request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
       request.beginAccessingResources { error in
           // Pack now available for play() lookups
       }
   }
   ```

3. **Coach-switch handling:** when the user changes coach preference (in
   Settings or via onboarding completion), trigger a new prefetch for the
   new coach. Apple keeps both coaches' packs cached locally for a while
   (purges only under storage pressure), so switching back-and-forth is fast.

4. **First-launch coordination:** prefetch the user's coach pack
   immediately after onboarding picks the coach (case 19 coach selector).
   By the time they hit the first workout, the pack is local.

### Risk
- If a user starts a workout offline before their pack downloads, voice
  cues fall back silently to the base Kira pack (via the existing fallback
  in `play(_:force:)` at line 91).
- Coach switching mid-session would need a re-fetch — gate the coach
  selector in Settings to "applies on next session" so this doesn't
  surprise the user.

### Testing
- Fresh install + pick Jeni in onboarding: confirm Jeni voice plays in
  first workout (no Sam clips needed locally)
- Switch to Sam in Settings, start new workout: confirm fetch + playback
- Airplane mode + first workout before any prefetch: confirm fallback to
  base clips (silence is acceptable, broken playback is not)

## Phase 3 — Lesson illustrations + Lottie ODR (~10-15 MB savings)

**Effort:** ~4-6 hours. Low risk (illustrations are sparse-use).

### Implementation

1. **Lesson illustrations** in `Assets.xcassets` — these are the JeniMethod
   lesson covers (lesson_d1_science, lesson_d2_paradox, etc.). Tag them
   `lessons-pack`. Prefetch when user reaches the JeniMethod tab for the
   first time.

2. **Lottie animations** — these power the exercise preview animations in
   `Views/Routine/`. Tag them `lottie-exercises`. Prefetch on workout-start
   (the workout screen knows which exercises it'll show; it can fetch the
   matching Lottie files).

3. **Granular vs single-tag tradeoff:** single tag `lessons-pack` is
   simpler. Per-lesson tagging (`lesson-d1`, `lesson-d2`, etc.) is more
   efficient if users only progress to certain lessons but adds complexity.
   Start with single-tag; refine later if needed.

## Migration order

Ship in this order to minimize risk and validate ODR is working in
production before relying on it for bigger features:

1. **v1.0.7:** Phase 1 only (music). Easy + low risk. Validates ODR
   infrastructure in production. Single tag, single service to refactor.

2. **v1.0.8:** Phase 2 (voice clips). Higher complexity but bigger payoff.
   Ship only after Phase 1 has been live for 1-2 weeks with no ODR-related
   issues in PostHog crash reports.

3. **v1.1.0:** Phase 3 (lessons + Lottie) bundled with the AI calorie
   tracking feature. The Core ML food model (if on-device) gets its own
   tag too — only downloaded after user signs up for Premium.

## Gotchas

- **ODR packs require network on first access.** Always plan for graceful
  degradation when packs aren't yet available.
- **Apple's ODR cache is opaque.** Don't assume tags persist forever — the
  OS may purge under storage pressure. Always call `beginAccessingResources`
  before use, even if the pack was fetched previously.
- **`NSBundleResourceRequest` retains the pack** for the lifetime of the
  request object. Hold onto it (e.g., as a stored property) for the
  duration of use, then release.
- **App Store size in Connect** reports both "App Size" (install) and
  "App Size with Resources" (everything including ODR). Monitor both.

## Telemetry

Add PostHog events:
- `odr_pack_fetch_started` (tag, source: "prefetch" | "on_demand")
- `odr_pack_fetch_completed` (tag, duration_ms)
- `odr_pack_fetch_failed` (tag, error_code)
- `odr_pack_fallback_used` (tag, reason)

These let you watch real-user ODR behavior post-launch.
