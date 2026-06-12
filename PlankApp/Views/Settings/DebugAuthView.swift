#if DEBUG
import SwiftUI
import Auth  // MemberImportVisibility: User.id / .email are defined in Supabase's Auth submodule
import PlankFood  // FoodFlags constants for the food rail debug toggle

/// Temporary scaffolding for testing Phase B (email/password upgrade) and
/// Phase C (Apple Sign-In) before the real onboarding/settings UI lands.
/// Delete this file when Phase D + E ship the production surfaces.
struct DebugAuthView: View {
    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared

    @State private var email = ""
    @State private var password = ""

    @State private var status = ""
    @State private var working = false

    // Phase 7 dev tooling — present lessons + re-read index without
    // going through paywall purchase + HomeView card unlock paths.
    @State private var showingJeniReReadDebug = false
    /// Phase 9.4 — preview the new ritual view side-by-side with the
    /// existing card flow. Set to a lesson to open the ritual; nil to
    /// dismiss.
    @State private var debugRitualToPresent: LessonID? = nil
    // Observe the flag's underlying UserDefaults key so the toggle and
    // state row stay in sync without manual refresh.
    @AppStorage("jenimethod.feature_enabled") private var jeniMethodFlag = false
    // Same observer pattern for the state rows so the debug screen
    // re-renders when an in-app action (Reset, Mark complete, etc.)
    // mutates UserDefaults.
    @AppStorage("jenimethod.last_lesson_completed_id") private var jeniMethodLastCompleted = 0

    // W1-T4 — food rail dev override. Drives FoodFlags layer #1
    // (short-circuit to true even without paid entitlement). Compiled
    // out of Release via the file-level #if DEBUG. Key MUST match
    // FoodFlags.devOverrideKey — the FoodFlagsTests pin this constant.
    @AppStorage("food_rail_dev_override") private var foodRailDevOverride = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Debug · Auth")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                stateCard

                credentialFields

                actionButtons

                jeniMethodSection

                foodRailSection

                onboardingResetSection

                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .fullScreenCover(item: $debugRitualToPresent) { lesson in
            // Phase 9.19 — debug test path uses the same flag-based
            // hand-off as PlankAIApp's post-paywall flow. HomeView
            // reads `pendingPostRitualWorkoutLaunch` on its next
            // appear and launches the routine session. From debug
            // this lets us phone-test the full Day-1 → workout flow.
            JeniMethodRitualView(
                lesson: lesson,
                user: .fromAppStorage(),
                onComplete: { debugRitualToPresent = nil },
                onSkip:     { _ in debugRitualToPresent = nil },
                onCompleteAndStartWorkout: {
                    UserDefaults.standard.set(
                        true,
                        forKey: "pendingPostRitualWorkoutLaunch"
                    )
                    // Dismiss in place (setAnimationsEnabled is the reliable
                    // no-slide path; Transaction wasn't). NOTE: this is a
                    // dev-only test path. The workout cover is owned by
                    // HomeView and only launches when Home next becomes
                    // active — so launched from Settings/debug, the workout's
                    // present happens off-Home where the pink splash can't
                    // mask it. The real Home flow (daily card / auto lesson)
                    // is fully slide-free; test the transition from there.
                    UIView.setAnimationsEnabled(false)
                    debugRitualToPresent = nil
                    DispatchQueue.main.async {
                        UIView.setAnimationsEnabled(true)
                    }
                }
            )
        }
        .sheet(isPresented: $showingJeniReReadDebug) {
            JeniMethodReReadView()
        }
    }

    // MARK: - State header

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CURRENT STATE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            row("user_id", auth.currentUser?.id.uuidString ?? "—")
            row("isAnonymous", String(auth.isAnonymous))
            row("authMethod", auth.authMethod.rawValue)
            row("email", auth.currentUser?.email ?? "—")
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    // MARK: - Inputs

    private var credentialFields: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("CREDENTIALS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            TextField("email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .padding(12)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            SecureField("password", text: $password)
                .padding(12)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            actionButton("Sign up with email (upgrade anon)", color: Palette.accent) {
                try await auth.signUpWithEmail(email, password: password)
                return "signed up · user_id \(auth.currentUser?.id.uuidString ?? "?")"
            }

            actionButton("Sign in with email", color: Palette.bgInverse) {
                try await auth.signInWithEmail(email, password: password)
                return "signed in · user_id \(auth.currentUser?.id.uuidString ?? "?")"
            }

            actionButton("Sign in with Apple", color: Color.black) {
                try await auth.signInWithApple()
                return "apple sign-in · user_id \(auth.currentUser?.id.uuidString ?? "?")"
            }

            actionButton("Send password reset", color: Palette.stateGood) {
                try await auth.sendPasswordReset(email: email)
                return "reset email sent to \(email)"
            }

            // Paywall force-toggle — QA the paywall without revoking the
            // RC entitlement or signing out. Flipping this re-evaluates
            // PlankAIApp's fullScreenCover gate on the next render.
            Button {
                payment.debugForcePaywall.toggle()
                status = "debugForcePaywall = \(payment.debugForcePaywall) · hasProAccess = \(payment.hasProAccess) · effective = \(payment.effectiveHasProAccess)"
            } label: {
                Text(payment.debugForcePaywall ? "Force paywall: ON (tap to disable)" : "Force paywall: OFF (tap to enable)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(payment.debugForcePaywall ? Palette.accent : Palette.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - JeniFit Method debug controls (Phase 7)

    private var jeniMethodSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("JENIFIT METHOD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            // Flag toggle — flipping this enables the feature flag, which
            // is what guards the post-purchase trigger AND the HomeView
            // card AND the Settings re-read entry. Off by default in
            // production; this toggle is per-device.
            Toggle("Enable JeniFit Method flag", isOn: $jeniMethodFlag)
                .tint(Palette.accent)
                .padding(.vertical, 4)

            // Live state — re-renders on @AppStorage changes.
            VStack(alignment: .leading, spacing: 4) {
                row("flag",          "\(JeniMethodFeatureFlag.isEnabled)")
                row("enrolled_at",   JeniMethodState.enrolledAt().map { shortDate($0) } ?? "—")
                row("days_enrolled", JeniMethodState.daysSinceEnrolled().map { "\($0)" } ?? "—")
                row("last_done",     "\(jeniMethodLastCompleted)")
                row("skip_count",    "\(JeniMethodState.skipCount)")
                row("enrolled",      JeniMethodState.enrolledAt() != nil ? "yes" : "no")
            }
            .padding(12)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Phase 9.22 — production now ships the ritual view
            // (old card-based JeniMethodLessonView deleted). One
            // entry point: pick any day to launch the live ritual
            // with full analytics + state mutations + workout hand-off.
            Text("present ritual")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)
            HStack(spacing: 6) {
                ForEach(LessonID.allCases) { lesson in
                    Button(lesson == .generic ? "Daily" : "Day \(lesson.rawValue)") {
                        // Phase 9.27 — fade-in appear instead of slide-up.
                        UIView.setAnimationsEnabled(false)
                        debugRitualToPresent = lesson
                        DispatchQueue.main.async {
                            UIView.setAnimationsEnabled(true)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Button("Open re-read index") { showingJeniReReadDebug = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Palette.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // State manipulation — exercise the HomeView card across
            // calendar-day boundaries without waiting overnight.
            Text("state controls")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)
            HStack(spacing: 6) {
                Button("Enroll now") {
                    JeniMethodState._debugReset()
                    JeniMethodState.markEnrolled()
                    status = "enrolled at now · last_completed = \(JeniMethodState.lastCompletedLessonId)"
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Palette.stateGood)
                .foregroundStyle(Palette.textInverse)
                .font(.system(size: 13, weight: .semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Enroll 2d ago") {
                    JeniMethodState._debugReset()
                    JeniMethodState.markEnrolled(now: Date().addingTimeInterval(-2 * 86_400))
                    status = "enrolled 2d ago · last_completed = \(JeniMethodState.lastCompletedLessonId)"
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Palette.stateGood)
                .foregroundStyle(Palette.textInverse)
                .font(.system(size: 13, weight: .semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Enroll 5d ago") {
                    JeniMethodState._debugReset()
                    JeniMethodState.markEnrolled(now: Date().addingTimeInterval(-5 * 86_400))
                    status = "enrolled 5d ago · last_completed = \(JeniMethodState.lastCompletedLessonId)"
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Palette.stateGood)
                .foregroundStyle(Palette.textInverse)
                .font(.system(size: 13, weight: .semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 6) {
                Button("Mark all done") {
                    JeniMethodState.markLessonCompleted(5)
                    status = "marked all 5 complete · re-read entry unlocked in Menu"
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Palette.textSecondary)
                .foregroundStyle(Palette.textInverse)
                .font(.system(size: 13, weight: .semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Reset all") {
                    JeniMethodState._debugReset()
                    status = "JeniMethod state cleared"
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Palette.stateBad)
                .foregroundStyle(Palette.textInverse)
                .font(.system(size: 13, weight: .semibold))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Food rail (W1-T4)
    //
    // Single toggle that drives FoodFlags.isEnabled layer #1
    // (force-on, bypasses paid + PostHog checks). Compiled out of
    // Release via the file-level #if DEBUG. UserDefaults key MUST
    // match FoodFlags.devOverrideKey — FoodFlagsTests pins the value.
    private var foodRailSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("FOOD RAIL")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            Toggle("Force food_rail_dev_override (DEBUG only)",
                   isOn: $foodRailDevOverride)
                .tint(Palette.accent)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                row("dev_override",   "\(foodRailDevOverride)")
                row("pro_access",     "\(PaymentService.shared.hasProAccess)")
                row("isEnabled",      "\(FoodFlags.isEnabled)")
                row("flag_name",      FoodFlags.postHogFlagName)
            }
            .padding(12)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("when override is OFF, isEnabled requires Pro entitlement + PostHog \(FoodFlags.postHogFlagName) flag on")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
    }

    // MARK: - Onboarding reset (delta v7 validation aid)
    //
    // Flips hasCompletedOnboarding back to false so the next app
    // launch routes to OnboardingView again. Lets us validate
    // onboarding-only features (plan reveal calorie hero D68,
    // commitment confidence screen D67) without delete + reinstall.
    // DEBUG-only via file-level guard.
    private var onboardingResetSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("ONBOARDING")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            let d = UserDefaults.standard
            VStack(alignment: .leading, spacing: 4) {
                row("hasCompleted", "\(d.bool(forKey: "hasCompletedOnboarding"))")
                // v3 dead-code rip (2026-06-10) — v2_enabled row removed.
                // v1 flow is gone; the flag is no longer read by the app.
            }
            .padding(12)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                UserDefaults.standard.removeObject(forKey: "onboardingCompletedAt")
                // Founder QA 2026-06-11: re-runs must show the rating
                // ask (case 215) again. Production users keep the
                // once-per-install gate; this is the DEBUG escape.
                UserDefaults.standard.removeObject(forKey: "ratingPrompt.postPlanReveal.shown")
                UserDefaults.standard.removeObject(forKey: "ratingPrompt.lastDate")
                UserDefaults.standard.removeObject(forKey: "onboardingReviewPromptShown")
                status = "onboarding reset — relaunch app to re-run."
            } label: {
                Text("Reset onboarding (DEBUG only)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("flips hasCompletedOnboarding → false. force-quit + relaunch to see the onboarding flow again.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: date)
    }

    private func actionButton(
        _ title: String,
        color: Color,
        action: @escaping () async throws -> String
    ) -> some View {
        Button {
            Task { await run(action) }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(working)
        .opacity(working ? 0.5 : 1)
    }

    private func run(_ action: () async throws -> String) async {
        working = true
        status = "running…"
        defer { working = false }
        do {
            status = try await action()
        } catch {
            status = "error: \(error.localizedDescription)"
        }
    }
}
#endif
