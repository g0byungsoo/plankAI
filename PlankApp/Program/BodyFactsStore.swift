import Foundation
import SwiftData
import PlankSync

/// THE ONE WRITER for the two body facts that build the energy target and
/// had no repair path at all: **height** and **how much she moves**.
///
/// `GoalWeightStore` (2026-08-13) closed the same hole for the goal
/// weight. These two were left, and they are not decorative:
///
/// - **height** is a hard input. `TargetsService.calorieTarget` returns
///   nil below 100 cm, so an absent height does not skew her number, it
///   DELETES it — and until now the only way to put one back was to
///   delete the account. 6.25 kcal per centimetre says a wrong one is
///   worth correcting too.
/// - **activity** moves the target by the whole span of the factor, 1.2
///   to 1.725. For the 5'3" 124 lb persona (BMR 1,232) that is **647
///   kcal** between "barely, honestly" and "very active" — larger than
///   any deficit the app would ever choose.
///
/// ## What it will not do
///
/// - **It never touches her weights.** Height and movement are not
///   weights; the 2026-08-13 report is what it looks like when body
///   facts get substituted for one another.
/// - **It never restarts her program.** Neither fact appears in the plan
///   record. A height change re-applies the goal through
///   `GoalWeightStore`, which mutates the active plan in place — so a
///   corrected height cannot leave a goal sitting under BMI 18.5 for the
///   new height, and cannot reset her day count either.
/// - **It writes BOTH activity vocabularies.** The raw answer is what
///   every live reader resolves first; the alias is the only one
///   `UserRecord` can carry through a sign-out. Writing one and not the
///   other is how the drift in `docs/app_v25/30` started.
enum BodyFactsStore {

    // MARK: - Height

    @MainActor
    static func setHeightCm(
        _ cm: Double,
        userId: String,
        in context: ModelContext,
        defaults d: UserDefaults = .standard
    ) {
        guard cm > 100, cm < 260 else { return }
        d.set(cm, forKey: "onboardingHeightCm")
        d.set(cm, forKey: "onb_v5_height_cm")

        mirror(userId: userId, in: context) { $0.onboardingHeightCm = cm }

        // A corrected height changes the healthy floor, so the goal she
        // already holds is re-run through the clamp that produced it.
        // Nothing else about the plan moves: same id, same start date.
        let storedGoal = d.double(forKey: "onboardingGoalWeightKg")
        if storedGoal > 30 {
            GoalWeightStore.setGoalWeightKg(
                storedGoal, userId: userId, in: context, defaults: d
            )
        }
    }

    // MARK: - Activity

    /// `raw` is a movement-baseline key: barely · walks · regular_ish ·
    /// very_active. Anything else is refused rather than stored, because
    /// an unrecognised activity key silently becomes 1.375.
    @MainActor
    static func setActivityBaseline(
        _ raw: String,
        userId: String,
        in context: ModelContext,
        defaults d: UserDefaults = .standard
    ) {
        guard let alias = Self.alias(forBaseline: raw) else { return }
        d.set(raw, forKey: "onb_v4_movement_baseline")
        d.set(alias, forKey: "activityLevel")
        mirror(userId: userId, in: context) { $0.onboardingActivityLevel = alias }
    }

    /// The completion-time alias for a raw baseline answer — the same
    /// mapping `OV5Store.assembleData` writes, kept in one place so the
    /// two can never drift again. nil = not a baseline key.
    static func alias(forBaseline raw: String) -> String? {
        switch raw {
        case "barely": return "sedentary"
        case "walks": return "walks"
        case "regular_ish": return "moderate"
        case "very_active": return "athlete"
        default: return nil
        }
    }

    /// Her answer in her own words, for a row that has to state what we
    /// hold. nil = nothing on file, which reads as "not set" and never as
    /// a guess.
    static func activityWords(_ d: UserDefaults = .standard) -> String? {
        switch TargetsService.activityKey(d) {
        case "barely", "sedentary": return "barely, honestly"
        case "walks", "light", "lightly_active": return "walks here and there"
        case "regular_ish", "moderate", "moderately_active": return "regular-ish"
        case "very_active", "active", "athlete": return "very active"
        default: return nil
        }
    }

    /// True when the device holds only the collapsed alias and that alias
    /// cannot be inverted — "moderate" was written for BOTH "walks here
    /// and there" and "regular-ish" before 2026-08-14, so a row restored
    /// from an older account cannot know which she said. The surface says
    /// so instead of picking one.
    static func activityIsAmbiguous(_ d: UserDefaults = .standard) -> Bool {
        (d.string(forKey: "onb_v4_movement_baseline") ?? "").isEmpty
            && (d.string(forKey: "activityLevel") ?? "") == "moderate"
    }

    // MARK: - Sex (the BMR term)
    //
    // The consult asks *"which formula should i use for your calorie
    // math?"* and, when she answers non-binary or prefer-not-to-say,
    // acknowledges: **"we'll use the more conservative equation. you can
    // change this anytime."** Until 2026-08-14 there was no anytime and
    // no surface — the app printed a promise it could not keep, about the
    // input with the second-largest effect on her number.
    //
    // It is an energy-equation term and nothing else. Mifflin-St Jeor
    // carries exactly two constants (`-161` and `+5`), so the app knows
    // exactly two states plus "use the conservative one"; the editor
    // offers the consult's own four answers and says which equation each
    // one runs.

    /// `raw` is the consult's vocabulary: female · male · nonbinary ·
    /// private. Anything else is refused rather than stored.
    @MainActor
    static func setSex(
        _ raw: String,
        userId: String,
        in context: ModelContext,
        defaults d: UserDefaults = .standard
    ) {
        guard ["female", "male", "nonbinary", "private"].contains(raw) else { return }
        d.set(raw, forKey: "onboardingGender")
        d.set(raw, forKey: "onb_v5_gender")
        mirror(userId: userId, in: context) { $0.onboardingGender = raw }
    }

    /// Her answer, in the consult's own words. nil = nothing on file.
    static func sexWords(_ d: UserDefaults = .standard) -> String? {
        switch (d.string(forKey: "onboardingGender") ?? "").lowercased() {
        case "female": return "female"
        case "male": return "male"
        case "nonbinary": return "non-binary"
        case "private": return "prefer not to say"
        default: return nil
        }
    }

    /// True when the stored answer is one the equation cannot use
    /// directly, so the conservative (female) constants run. Said out
    /// loud rather than presented as neutral arithmetic.
    static func sexUsesConservativeEquation(_ d: UserDefaults = .standard) -> Bool {
        let raw = (d.string(forKey: "onboardingGender") ?? "").lowercased()
        return raw == "nonbinary" || raw == "private"
    }

    // MARK: - Age (the third BMR term)
    //
    // 5 kcal of BMR per year. The exact age lives in `onb_v5_age_years`,
    // which the `onb_v5_` prefix sweeps on sign-out, and `UserRecord`
    // carries only the BAND — so a returning user's age comes back as her
    // band's representative year and the target can move by up to ~35
    // kcal without her touching anything. There is no lossless fix
    // without a `users` column (see docs/app_v25/31 §5). What there can
    // be is: the number we are using, stated, marked approximate when it
    // came from a band, and correctable in one tap.

    @MainActor
    static func setAgeYears(
        _ years: Int,
        userId: String,
        in context: ModelContext,
        defaults d: UserDefaults = .standard
    ) {
        guard years >= 13, years <= 100 else { return }
        let band = TargetsService.ageBand(forYears: years)
        d.set(years, forKey: "onb_v5_age_years")
        // BOTH band keys, because the two are read by different readers
        // and writing one is how the activity drift in
        // docs/app_v25/30 §4 started.
        d.set(band, forKey: "ageRange")
        d.set(band, forKey: "onboardingAgeRange")
        mirror(userId: userId, in: context) { $0.onboardingAgeRange = band }
    }

    // MARK: - The sync mirror

    @MainActor
    private static func mirror(
        userId: String, in context: ModelContext, _ apply: (UserRecord) -> Void
    ) {
        guard !userId.isEmpty else { return }
        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        apply(record)
        record.pendingUpsert = true
        try? context.save()
        Task { await AppSync.shared.upsertUser(record) }
    }
}
