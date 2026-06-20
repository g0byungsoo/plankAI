import SwiftUI
import StoreKit

// MARK: - TrialNudge
//
// Sprint A (2026-06-15) — in-app trial-conversion nudges.
//
// The RC funnel says 23.1% of yearly trials convert to paid (6/26 with 8
// pending), below the 30-35% benchmark for 3-day iOS trials. Phase F
// already ships a trial-end PUSH notification (24h before renew). This
// adds the IN-APP companion beats — the users who open the app in their
// trial window but ignore the push.
//
// Two beats, both one-shot per trial (UserDefaults flag keyed to the
// trial expiration date — a fresh trial regenerates the keys):
//
//   Day 2 ("almost done"): fires when 24h ≤ hoursUntilExpiration ≤ 48h
//     AND the user has opened the app in that window. Reflective beat —
//     acknowledges where she is, no sales pitch. Two CTAs: "back to today"
//     (primary, dismisses) + "manage subscription" (deeplinks to Apple
//     subscription settings via storefront).
//
//   Day 3 ("trial ending"): fires when 0 < hoursUntilExpiration < 18h.
//     Apple-compliant transparency about the auto-conversion: clear
//     statement that billing happens tomorrow, calm permission-frame
//     copy ("cancel in settings if you like"), CTAs include the
//     manage-subscription deeplink. No urgency theatrics.
//
// Voice locked: lowercase casual, italic Fraunces on punch words,
// hearts as terminal punctuation, no labor verbs, NO scarcity copy
// (per [[feedback-no-em-dash]] / brand voice locks), NO scatter
// stickers (re-engagement isn't an "earned moment" per
// [[feedback-scatter-milestone-rule]]).

// MARK: - Public coordinator

@MainActor
@Observable
final class TrialNudgeCoordinator {
    static let shared = TrialNudgeCoordinator()

    /// What's currently being presented (drives the RootView sheet).
    private(set) var pending: TrialNudgeKind?
    /// Trial expiration date that backed the most recent `evaluate` call
    /// — surfaced for the modal so it can format the trial-end stamp
    /// without re-reading RevenueCat entitlement state from the view.
    private(set) var expirationDate: Date?

    private init() {}

    /// Pump-the-coordinator entry point. Called by PaymentService on
    /// each customerInfoStream emit AND by RootView when the scene
    /// returns to .active. The customerInfo is the source of truth —
    /// when the user isn't in trial we present nothing.
    ///
    /// Idempotent: same purchaseDate + expirationDate → same one-shot
    /// flag → no re-fire. Cancelling/restoring a trial regenerates
    /// the expirationDate, which invalidates the prior flags.
    func evaluate(
        purchaseDate: Date?,
        expirationDate: Date?,
        isTrial: Bool,
        now: Date = Date()
    ) {
        self.expirationDate = expirationDate
        guard isTrial,
              let purchaseDate,
              let expirationDate,
              expirationDate > now,
              now > purchaseDate else {
            pending = nil
            return
        }

        let hoursUntilEnd = expirationDate.timeIntervalSince(now) / 3600

        // Day 3 has precedence over Day 2 (final beat wins if user
        // opens during the overlap window, e.g. they ignored Day 2
        // entirely and we're already inside the Day 3 window).
        if hoursUntilEnd > 0 && hoursUntilEnd < 18 {
            if !UserDefaults.standard.bool(forKey: Self.day3Key(expirationDate)) {
                pending = .day3
                return
            }
        }
        if hoursUntilEnd >= 24 && hoursUntilEnd <= 48 {
            if !UserDefaults.standard.bool(forKey: Self.day2Key(expirationDate)) {
                pending = .day2
                return
            }
        }
        pending = nil
    }

    /// Called by the modal on dismiss. Records the one-shot flag so we
    /// don't re-fire on the next foreground.
    func dismiss(_ kind: TrialNudgeKind, expirationDate: Date?) {
        if let expirationDate {
            let key: String
            switch kind {
            case .day2: key = Self.day2Key(expirationDate)
            case .day3: key = Self.day3Key(expirationDate)
            }
            UserDefaults.standard.set(true, forKey: key)
        }
        if pending == kind { pending = nil }
    }

    /// Sheet-binding handle. SwiftUI sheets call the setter on swipe-down
    /// dismissal — we forward to dismiss() so the one-shot flag is
    /// recorded consistently with the explicit "back to today" path.
    func clearPending() {
        guard let kind = pending else { return }
        dismiss(kind, expirationDate: expirationDate)
    }

    /// Keys are scoped to the trial's expirationDate (millisecond-precise
    /// string) so a re-bought trial (different expiration) starts fresh.
    private static func day2Key(_ d: Date) -> String {
        "trialNudge.day2.\(Int(d.timeIntervalSince1970))"
    }
    private static func day3Key(_ d: Date) -> String {
        "trialNudge.day3.\(Int(d.timeIntervalSince1970))"
    }

    // MARK: - Debug seed

    #if DEBUG
    /// Force a specific modal for the debug harness. Clears any one-shot
    /// flags so the modal renders even after a prior dismiss.
    func debugForce(_ kind: TrialNudgeKind) {
        pending = kind
    }
    #endif
}

enum TrialNudgeKind: Equatable, Sendable {
    case day2
    case day3
}

// MARK: - Day 2 modal — reflective beat

struct TrialDay2Modal: View {
    let expirationDate: Date?
    var onDismiss: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TrialNudgeShell {
            VStack(alignment: .leading, spacing: 24) {
                eyebrow
                heroLine
                subhead
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
        } footer: {
            VStack(spacing: 8) {
                primaryCTA
                manageLink
            }
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.08)) {
                    hasAppeared = true
                }
            }
        }
    }

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.accent).frame(width: 5, height: 5)
            Text("day two")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.8)
                .textCase(.uppercase)
        }
    }

    private var heroLine: some View {
        // her75 hero — JeniHeroSerif at heroHeadline (38pt) with
        // heroHeadlineLineGap (-19) so the 2 lines visually clamp.
        // Hand-stacked Text + italic punch on "there". `.kerning(-0.4)`
        // per the her75 spec (measured -1% tracking on Playfair).
        VStack(alignment: .leading, spacing: Typo.heroHeadlineLineGap) {
            Text("halfway")
                .font(Typo.heroHeadline)
                .foregroundStyle(Palette.textPrimary)
            (
                Text("there")
                    .font(Typo.heroHeadlineItalic)
                    .foregroundStyle(Palette.textPrimary)
                +
                Text(" ♥")
                    .font(Typo.heroHeadline)
                    .foregroundStyle(Palette.textPrimary)
            )
        }
        .kerning(-0.4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var subhead: some View {
        // Body stays in Fraunces — her75 doesn't shift body copy, only
        // heroes. Italic punch on "nothing" so the permission frame
        // ("nothing changes about today") lands as a reassurance, not
        // a marketing line.
        ItalicAccentText(
            "trial wraps in 24 hours. nothing changes about today — keep going at the pace you've been going.",
            italic: ["nothing"],
            baseFont: .custom("Fraunces72pt-Regular", size: 15),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 15),
            color: Palette.textSecondary,
            alignment: .leading
        )
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
            onDismiss()
        } label: {
            Text("back to today")
                .font(.custom("DMSans-SemiBold", size: 15))
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Palette.textPrimary))
        }
        .buttonStyle(.plain)
    }

    private var manageLink: some View {
        Button {
            openManageSubscription()
        } label: {
            Text("manage subscription →")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day 3 modal — emotional reframe + Apple-compliant disclosure

struct TrialDay3Modal: View {
    let expirationDate: Date?
    var onDismiss: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TrialNudgeShell {
            VStack(alignment: .leading, spacing: 24) {
                eyebrow
                heroLine
                disclosureLine
                whatHappensTomorrow
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
        } footer: {
            VStack(spacing: 8) {
                primaryCTA
                manageLink
            }
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.08)) {
                    hasAppeared = true
                }
            }
        }
    }

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.accent).frame(width: 5, height: 5)
            Text("trial ending")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.8)
                .textCase(.uppercase)
        }
    }

    private var heroLine: some View {
        // her75 hero — JeniHeroSerif at heroHeadline (38pt) with
        // heroHeadlineLineGap (-19) so the 2 lines visually clamp.
        // Italic punch on "tonight". `.kerning(-0.4)` per the her75
        // spec.
        VStack(alignment: .leading, spacing: Typo.heroHeadlineLineGap) {
            Text("your trial")
                .font(Typo.heroHeadline)
                .foregroundStyle(Palette.textPrimary)
            (
                Text("wraps ")
                    .font(Typo.heroHeadline)
                    .foregroundStyle(Palette.textPrimary)
                +
                Text("tonight")
                    .font(Typo.heroHeadlineItalic)
                    .foregroundStyle(Palette.textPrimary)
                +
                Text(" ♥")
                    .font(Typo.heroHeadline)
                    .foregroundStyle(Palette.textPrimary)
            )
        }
        .kerning(-0.4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var disclosureLine: some View {
        // Apple 3.1.2(a)-compliant disclosure. Plain, clear, no marketing.
        // Body stays Fraunces; her75 typography is hero-only.
        Text("your plan continues automatically. you'll see the annual charge you picked at signup.")
            .font(.custom("Fraunces72pt-Regular", size: 15))
            .foregroundStyle(Palette.textPrimary.opacity(0.85))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var whatHappensTomorrow: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(stamp: stampText, line: "annual rate begins")
            row(stamp: "anytime", line: "cancel in settings · keep access through tonight")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.accentSubtle.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.accent.opacity(0.3), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func row(stamp: String, line: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(stamp)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 64, alignment: .leading)
            Text(line)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var stampText: String {
        guard let d = expirationDate else { return "tomorrow" }
        return Self.dayFormatter.string(from: d).lowercased()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var primaryCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
            onDismiss()
        } label: {
            Text("stay open ♥")
                .font(.custom("DMSans-SemiBold", size: 15))
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Palette.textPrimary))
        }
        .buttonStyle(.plain)
    }

    private var manageLink: some View {
        Button {
            openManageSubscription()
        } label: {
            Text("manage subscription →")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shell
//
// her75 register: flat `bgPrimary` background, hero typography directly
// on the canvas (NO scrapbook chrome — no shadow, no accent border, no
// rounded card wrapping the hero). Matches the production pattern in
// `ProgramIntroFullScreenCover` + `ChapterCompleteView`. The shadow +
// accent-border combo on a rounded rect is the food-card idiom, NOT
// her75; using it on hero surfaces casts a visible drop-shadow on the
// text glyphs and reads as the pre-her75 register.
//
// Layout: ScrollView for body content (handles narrow phones gracefully)
// + dockable footer for the CTAs. Footer paints `bgPrimary` so scrolled
// content slides under, never through.

private struct TrialNudgeShell<Content: View, Footer: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, Space.hero)
                        .padding(.bottom, 24)
                }

                footer()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .background(Palette.bgPrimary)
            }
        }
    }
}

// MARK: - Open manage subscription

/// Opens the iOS Manage Subscriptions sheet for this app. Uses
/// AppStore.showManageSubscriptions on iOS 15+. Falls back to the
/// itms-apps:// settings URL on simulator (where the sheet is a no-op).
@MainActor
private func openManageSubscription() {
    Task {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            #if DEBUG
            print("[TrialNudge] showManageSubscriptions failed: \(error)")
            #endif
            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
            }
        }
    }
}
