import SwiftUI
import SwiftData
import PlankSync
import Auth

// MARK: - MigrationMomentView
//
// App v2 (docs/app_v2/08_MIGRATION.md). The one-time "the new
// jenifit" moment for existing paid users with a legacy program
// footprint. Everything on it is provenance-true (her real day
// number, her real counts). Completing stamps `appV2SeenAt`, which
// flips the phase machine to .main forever.
//
// P2 ships the single-beat version; P5 expands to the three-beat
// moment (meet jeni properly · today redesigned) with the device
// frame + hold-to-continue seal.

struct MigrationMomentView: View {
    @AppStorage("appV2SeenAt") private var appV2SeenAt = ""
    @AppStorage("userName") private var userName = ""
    @Environment(\.modelContext) private var modelContext

    @State private var planDay: Int? = nil
    @State private var showedUp: Int = 0
    @State private var lessonCount: Int = 0

    var body: some View {
        JKScreenChrome {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Space.md) {
                    ItalicAccentText(
                        "jeni grew up",
                        italic: ["grew up"],
                        baseFont: Typo.heroHeadline,
                        italicFont: Typo.heroHeadlineItalic,
                        alignment: .center
                    )
                    .lineSpacing(Typo.heroHeadlineLineGap)
                    .kerning(-0.4)
                    .jkBeat1()

                    Text(subline)
                        .font(Typo.teachSub)
                        .lineSpacing(Typo.teachSubLineSpacing)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg + Space.sm)
                        .jkBeat2()
                }

                VStack(spacing: 0) {
                    if let planDay {
                        JKReceiptRow(
                            lead: "your plan",
                            punch: "continues at day \(planDay)",
                            punchItalic: ["continues"],
                            showsRule: false
                        )
                    }
                    if showedUp > 0 {
                        JKReceiptRow(
                            lead: "you showed up",
                            punch: "\(showedUp) times, all kept",
                            punchItalic: ["kept"],
                            showsRule: planDay != nil
                        )
                    }
                    JKReceiptRow(
                        lead: "new",
                        punch: "jeni, your coach, in chat",
                        punchItalic: ["jeni"],
                        showsRule: planDay != nil || showedUp > 0
                    )
                }
                .padding(.horizontal, Space.lg + Space.sm)
                .padding(.top, Space.xl)
                .jkBeat2(extraDelay: 0.15)

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "open the new jeni",
                action: complete
            )
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.sm)
            .jkBeat2(extraDelay: 0.3)
        }
        .task { loadReceipts() }
        .onAppear {
            Analytics.track(.migrationMomentViewed)
        }
    }

    private var subline: String {
        let name = userName.isEmpty ? "" : "\(userName), "
        return "\(name)your plan, plates, and trend came along. the app around them is new."
    }

    private func complete() {
        Haptics.success()
        appV2SeenAt = ISO8601DateFormatter().string(from: .now)
        Analytics.track(.migrationMomentCompleted)
    }

    private func loadReceipts() {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return }
        if let plan = ProgramService.shared.activePlan(userId: uid, in: modelContext) {
            let schedule = ProgramScheduleCalculator.compute(
                ProgramScheduleCalculator.Inputs(
                    startDate: plan.startDate, totalDays: plan.totalDays
                )
            )
            planDay = min(schedule.programDay, plan.totalDays)
        }
        showedUp = UserDefaults.standard.integer(forKey: "stats.shown_up_count")
    }
}
