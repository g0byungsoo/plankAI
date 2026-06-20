import Foundation
import Observation
import HealthKit

// MARK: - SleepService
//
// HealthKit-backed last-night sleep source for the Becoming bento.
// Read-only — JeniFit never writes sleep samples back.
//
// Why a service singleton (mirrors StepsService): sleep samples already
// live in Apple Health (every Apple Watch, every iOS auto-sleep mode,
// every 3rd-party tracker that writes there). Re-storing in Supabase
// would double the source of truth and add a privacy surface for
// data that doesn't need to leave the device. The Becoming card reads
// live; cached for the day so re-renders skip the HK round-trip.
//
// What we read:
//   HKCategoryType .sleepAnalysis with values:
//     - inBed          (Apple Watch + manual logging)
//     - asleepUnspecified (pre-iOS-16 / 3rd-party trackers)
//     - asleepCore     (iOS 16+ "core sleep" stage)
//     - asleepDeep     (iOS 16+ "deep sleep")
//     - asleepREM      (iOS 16+ "REM")
//     - awake          (mid-night awakenings)
//
// What we compute (LastNightSleep):
//   - bedtime + wakeTime — bounds of the most recent sleep session
//   - inBed duration — wakeTime − bedtime
//   - asleep duration — sum of any asleep* sample within bounds
//   - stages timeline — chronologically-sorted bands for the visual arc
//
// "Last night" definition: the most recent continuous sleep session
// ending within the last 18 hours. A gap of >1 hour breaks the session
// (handles e.g. a 6am wake-up followed by a 7am nap — we want the main
// session, not the nap concatenated on).
//
// Permission model: same tri-state as StepsService — HealthKit returns
// .notDetermined for both "never asked" and "user denied read" to
// preserve privacy. We infer .denied only when a fresh post-request
// query returns nil. (See StepsService docstring for the founder-bug
// recovery flow this pattern fixed.)
//
// Sim note: HealthKit on iOS Simulator returns empty data by default.
// Add samples via the Health app on the sim (Browse → Sleep → Add Data)
// to test the populated states. For the design-verification harness,
// `LastNightSleep.sample()` returns a synthesized last-night that
// renders the card without HK at all.

@MainActor
@Observable
final class SleepService {
    static let shared = SleepService()

    enum Authorization: Equatable {
        case unavailable    // HealthKit isn't supported on this device
        case notDetermined  // never asked, or user opened Health and reset
        case requesting     // user tapped connect, awaiting iOS sheet result
        case authorized     // share access granted (may still have no data yet)
        case denied         // explicit deny inferred from no data + post-ask
    }

    private(set) var authStatus: Authorization
    /// Most recent sleep session within the last 18 hours. `nil` when
    /// the user has nothing logged (fresh phone, denied access, or
    /// genuinely no sample yet for the day).
    private(set) var lastNight: LastNightSleep?
    /// Most recent successful refresh, used as a freshness guard.
    private(set) var lastSyncedAt: Date?

    private let healthStore = HKHealthStore()

    private init() {
        self.authStatus = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    }

    // MARK: - Bootstrap

    /// Called once at launch from PlankAIApp. Silent: if the user has
    /// already granted (or denied) sleep access, no re-prompt — we
    /// just try to read.
    func bootstrap() async {
        guard case .notDetermined = authStatus else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = .unavailable
            return
        }
        await refresh()
        if lastNight != nil {
            authStatus = .authorized
        }
        // Else stay .notDetermined; the Becoming card's "connect" CTA
        // will trigger requestAccess() on user tap.
    }

    // MARK: - Request access

    /// Triggered by the user tapping "connect" on the Becoming sleep
    /// card's empty state. Surfaces the iOS HealthKit share-data sheet
    /// for sleep analysis. After the user decides, we run one refresh
    /// — and infer .denied if we still read nothing.
    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = .unavailable
            return
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            authStatus = .unavailable
            return
        }

        // Surface the in-flight state immediately so the card shows
        // a visible "trying to connect ♥" beat — without it, a no-op
        // permission call (iOS suppresses the sheet on re-ask after
        // explicit grant/deny) leaves the card looking unresponsive
        // to the tap.
        authStatus = .requesting

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
        } catch {
            #if DEBUG
            print("[SleepService] requestAuthorization failed: \(error)")
            #endif
            authStatus = .notDetermined  // let the user retry
            return
        }

        // Force-refresh: the 5-minute cache from `bootstrap()` would
        // otherwise short-circuit this read and we'd never observe
        // the post-grant data state.
        await refresh(force: true)
        if lastNight != nil {
            authStatus = .authorized
        } else {
            // No samples post-ask. Two possibilities (iOS won't tell
            // us which for read-only permissions, by design):
            //   (a) user denied in the system sheet → genuine .denied
            //   (b) user granted but has no sleep data synced yet
            //       (fresh device, no Apple Watch, first-night user)
            // The card's empty-state copy names both possibilities
            // so the user has a clear next step in either case.
            authStatus = .denied
        }
    }

    // MARK: - Refresh

    /// Re-reads the most recent sleep session from Apple Health. Cheap
    /// enough to call from any view's `.task`/`.onAppear`. Skips the HK
    /// round-trip when the cache is younger than 5 minutes.
    func refresh(force: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !force, let synced = lastSyncedAt, Date().timeIntervalSince(synced) < 300 {
            return  // cache is fresh
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        // Pull every sleep sample from the last 36 hours. Gives us
        // enough headroom to find a session that started yesterday
        // evening AND any naps after, so the session-segmenter has
        // full context. 36h is small (Apple Watch logs ~10-50 samples
        // for a full night); no perf concern.
        let now = Date()
        guard let windowStart = Calendar.current.date(byAdding: .hour, value: -36, to: now) else { return }
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: now,
            options: .strictStartDate
        )
        let sortByStart = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 500,
                sortDescriptors: [sortByStart]
            ) { _, results, _ in
                let cast = (results as? [HKCategorySample]) ?? []
                continuation.resume(returning: cast)
            }
            healthStore.execute(query)
        }

        lastNight = LastNightSleep.segment(from: samples, asOf: now)
        lastSyncedAt = now
    }
}

// MARK: - LastNightSleep

/// One night's worth of sleep, segmented from raw HK samples.
struct LastNightSleep: Sendable {
    let bedtime: Date
    let wakeTime: Date
    /// Total time the user was actually asleep — sum of any asleep*
    /// stage within bounds. Excludes inBed-only spans + awake spans.
    /// For pre-iOS-16 / 3rd-party logs that only record `inBed`, falls
    /// back to the inBed sum (best-effort interpretation).
    let asleepDuration: TimeInterval
    /// bedtime → wakeTime. The visual arc's full extent.
    let inBedDuration: TimeInterval
    /// Chronological timeline of stage bands. Used by the card's
    /// hand-drawn stage timeline. Each band has a stage kind, start,
    /// and end relative to bedtime.
    let stages: [Stage]

    /// Sleep efficiency = asleep / inBed. Clamped 0…1.
    var efficiency: Double {
        guard inBedDuration > 0 else { return 0 }
        return min(1, asleepDuration / inBedDuration)
    }

    struct Stage: Sendable, Hashable {
        let kind: Kind
        /// Seconds from bedtime to band start. 0 = bedtime exactly.
        let startOffset: TimeInterval
        let duration: TimeInterval

        enum Kind: String, Sendable {
            case inBed       // bed only — pre-sleep, transitions, or legacy
            case asleepCore  // light/core sleep (iOS 16+)
            case asleepDeep  // deep sleep (iOS 16+)
            case asleepREM   // REM (iOS 16+)
            case asleep      // legacy unspecified asleep
            case awake       // mid-night awakening
        }
    }

    // MARK: - Segmenter

    /// Walks raw HK samples and identifies the most-recent continuous
    /// session, defined as the densest cluster of sleep samples ending
    /// within the last 18 hours. A gap > 60 minutes between samples
    /// breaks the session (handles "main sleep + morning nap" → we
    /// pick the main).
    static func segment(from samples: [HKCategorySample], asOf now: Date) -> LastNightSleep? {
        guard !samples.isEmpty else { return nil }

        // Filter to "sleep-y" samples (any value we care about). Sorted
        // by start time ascending — same order as the HK query.
        let relevant = samples.filter { isSleepValue($0.value) }
        guard !relevant.isEmpty else { return nil }

        // Walk from the most-recent sample backward, growing the session
        // as long as the next-earlier sample's END is within 60 min of
        // the current session's START. Stop on the first big gap.
        let sessionGap: TimeInterval = 60 * 60
        var sessionSamples: [HKCategorySample] = [relevant.last!]
        var i = relevant.count - 2
        while i >= 0 {
            let candidate = relevant[i]
            let nextSampleStart = sessionSamples.first!.startDate
            let gap = nextSampleStart.timeIntervalSince(candidate.endDate)
            if gap > sessionGap { break }
            sessionSamples.insert(candidate, at: 0)
            i -= 1
        }

        // Bounds: session start = earliest sample start, session end =
        // latest sample end. (Some samples overlap; max() handles it.)
        let bedtime = sessionSamples.map(\.startDate).min() ?? sessionSamples.first!.startDate
        let wakeTime = sessionSamples.map(\.endDate).max() ?? sessionSamples.last!.endDate
        guard wakeTime > bedtime else { return nil }
        let inBed = wakeTime.timeIntervalSince(bedtime)

        // Don't surface a session that ended >18 hours ago — that's not
        // "last night" anymore, that's "two nights ago" data leaking
        // through. Returning nil so the card stays in its empty state.
        if now.timeIntervalSince(wakeTime) > 18 * 60 * 60 { return nil }

        // Stage bands — convert each sample's value to a Stage.Kind +
        // compute the offset from bedtime. Overlapping samples produce
        // overlapping bands, which is fine: the card renders them as
        // stacked color bands so the deepest-stage signal wins
        // visually (deep > rem > core > asleep > inBed > awake).
        let stages: [Stage] = sessionSamples.compactMap { sample in
            guard let kind = Stage.Kind(rawHK: sample.value) else { return nil }
            let offset = sample.startDate.timeIntervalSince(bedtime)
            let dur = sample.endDate.timeIntervalSince(sample.startDate)
            guard dur > 0 else { return nil }
            return Stage(kind: kind, startOffset: offset, duration: dur)
        }

        // Asleep = sum of any asleep* stage. Falls back to inBed sum
        // when the user's tracker only records inBed (Apple Watch
        // before iOS 16, some 3rd-party loggers).
        let asleepKinds: Set<Stage.Kind> = [.asleepCore, .asleepDeep, .asleepREM, .asleep]
        let asleepSum = stages
            .filter { asleepKinds.contains($0.kind) }
            .map(\.duration)
            .reduce(0, +)
        let inBedSum = stages
            .filter { $0.kind == .inBed }
            .map(\.duration)
            .reduce(0, +)
        let asleepDuration = asleepSum > 0 ? asleepSum : inBedSum

        return LastNightSleep(
            bedtime: bedtime,
            wakeTime: wakeTime,
            asleepDuration: asleepDuration,
            inBedDuration: inBed,
            stages: stages.sorted { $0.startOffset < $1.startOffset }
        )
    }

    private static func isSleepValue(_ raw: Int) -> Bool {
        // Any value mapping to a Stage.Kind counts; awake samples are
        // kept so the timeline can render mid-night awakenings.
        Stage.Kind(rawHK: raw) != nil
    }
}

// MARK: - Stage.Kind ← raw HK value

private extension LastNightSleep.Stage.Kind {
    init?(rawHK value: Int) {
        guard let raw = HKCategoryValueSleepAnalysis(rawValue: value) else { return nil }
        switch raw {
        case .inBed:               self = .inBed
        case .asleepUnspecified:   self = .asleep
        case .asleepCore:          self = .asleepCore
        case .asleepDeep:          self = .asleepDeep
        case .asleepREM:           self = .asleepREM
        case .awake:               self = .awake
        @unknown default:          return nil
        }
    }
}

// MARK: - Sample data (DEBUG harness / previews)

#if DEBUG
extension LastNightSleep {
    /// A synthesized last-night that demonstrates a typical sleep
    /// architecture: ~8h 23m total in bed, ~7h 41m asleep (deep ratio
    /// ~28% → "deeply"), three deep cycles, four REM peaks, three
    /// brief mid-night awakenings. The stage script fills the full
    /// bedtime → wake window so the topography spans the card width.
    /// Used by the debug preview harness so the card renders without
    /// any real HK data.
    static func sample(asOf now: Date = Date()) -> LastNightSleep {
        let cal = Calendar.current
        // Wake at 7:08am today, bedtime at 10:45pm last night.
        let wake = cal.date(bySettingHour: 7, minute: 8, second: 0, of: now)
            ?? now.addingTimeInterval(-3600)
        let bedtime = wake.addingTimeInterval(-(8 * 3600 + 23 * 60))

        // Stage script (chronological, minutes). Sums to 503 min = 8h 23m
        // total in bed; 461 min = 7h 41m asleep; 130 min = 2h 10m deep
        // (28.2% deep ratio → "deeply"). Realistic Apple Watch sleep
        // architecture: settling → cycle 1 (deep peak) → cycle 2 (rem
        // peak) → cycle 3 → morning rem-heavy → wake.
        let script: [(LastNightSleep.Stage.Kind, Double)] = [
            (.inBed,       12),     // settling
            (.asleepCore,  22),
            (.asleepDeep,  50),     // first big deep cycle
            (.asleepCore,  25),
            (.asleepREM,   22),
            (.asleepCore,  18),
            (.asleepDeep,  40),     // second deep cycle
            (.asleepCore,  20),
            (.awake,        8),     // brief 2am wake
            (.asleepCore,  28),
            (.asleepREM,   28),
            (.asleepCore,  28),
            (.asleepDeep,  40),     // third deep cycle
            (.asleepCore,  16),
            (.awake,        6),     // brief 5am wake
            (.asleepREM,   30),
            (.asleepCore,  22),
            (.asleepREM,   30),     // morning rem peak
            (.awake,        4),
            (.asleepCore,  42),
            (.inBed,       12),     // pre-wake stretching
        ]
        var cursor: TimeInterval = 0
        var stages: [Stage] = []
        for (kind, mins) in script {
            stages.append(Stage(kind: kind, startOffset: cursor, duration: mins * 60))
            cursor += mins * 60
        }
        let inBed = wake.timeIntervalSince(bedtime)
        let asleep = stages
            .filter { [.asleepCore, .asleepDeep, .asleepREM, .asleep].contains($0.kind) }
            .map(\.duration)
            .reduce(0, +)

        return LastNightSleep(
            bedtime: bedtime,
            wakeTime: wake,
            asleepDuration: asleep,
            inBedDuration: inBed,
            stages: stages
        )
    }

    /// A "light night" companion to `sample()` — shorter total
    /// (5h 50m in bed, 4h 36m asleep), low deep ratio (~9% → "lightly"),
    /// more mid-night awakenings, single fragmented REM. For verifying
    /// the subhead qualifier branches + topography appearance with a
    /// less-restorative night.
    static func lightNightSample(asOf now: Date = Date()) -> LastNightSleep {
        let cal = Calendar.current
        let wake = cal.date(bySettingHour: 5, minute: 47, second: 0, of: now)
            ?? now.addingTimeInterval(-3600)
        let bedtime = wake.addingTimeInterval(-(5 * 3600 + 50 * 60))

        // Sum: 350 min = 5h 50m total. Asleep = 276 min = 4h 36m. Deep
        // = 25 min = ~9% deep ratio → "lightly" qualifier.
        let script: [(LastNightSleep.Stage.Kind, Double)] = [
            (.inBed,       16),     // long settle
            (.asleepCore,  38),
            (.awake,       12),     // restless
            (.asleepCore,  30),
            (.asleepDeep,  16),     // tiny deep
            (.asleepCore,  28),
            (.asleepREM,   14),
            (.awake,       8),
            (.asleepCore,  34),
            (.asleepCore,  30),
            (.asleepDeep,   9),     // sliver
            (.asleepREM,   18),
            (.awake,        6),
            (.asleepCore,  39),
            (.asleepREM,   18),
            (.awake,        4),
            (.asleepCore,   2),
            (.inBed,       28),     // pre-wake lying there
        ]
        var cursor: TimeInterval = 0
        var stages: [Stage] = []
        for (kind, mins) in script {
            stages.append(Stage(kind: kind, startOffset: cursor, duration: mins * 60))
            cursor += mins * 60
        }
        let inBed = wake.timeIntervalSince(bedtime)
        let asleep = stages
            .filter { [.asleepCore, .asleepDeep, .asleepREM, .asleep].contains($0.kind) }
            .map(\.duration)
            .reduce(0, +)

        return LastNightSleep(
            bedtime: bedtime,
            wakeTime: wake,
            asleepDuration: asleep,
            inBedDuration: inBed,
            stages: stages
        )
    }
}
#endif
