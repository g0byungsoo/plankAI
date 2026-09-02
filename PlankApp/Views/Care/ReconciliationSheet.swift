import SwiftUI
import SwiftData
import PlankSync

// MARK: - ReconciliationSheet (app v8 S4 — FR2)
//
// The calm, clinically-neutral moment when a clinic has assigned a
// medication plan and the patient already had one of her own. Short:
// what the clinic set, that her earlier records stay, that future
// check-ins follow this plan, and two acts. No database or merge
// vocabulary; no medication advice. Confirm retires the self plan
// (history intact); "something's off" opens the correction sheet and
// leaves the plan flagged-not-confirmed (still composing).

struct ReconciliationSheet: View {
    let userId: String
    let plan: RegimenPlanRecord
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCorrection = false
    /// p63 — the app's highest-priority self-presenting surface used
    /// to land five blocks in one frame, then lock dismissal. A
    /// clinical statement is speech: the claim, then the facts, then
    /// the decision — three acts on the speech beat, tap to land all.
    @State private var act = 0

    private static let weekdayWords = [
        1: "monday", 2: "tuesday", 3: "wednesday", 4: "thursday",
        5: "friday", 6: "saturday", 7: "sunday",
    ]

    private var line: String {
        var parts: [String] = [plan.displayName.isEmpty ? "your medication" : plan.displayName]
        if let v = plan.strengthValue {
            parts.append("\(v == v.rounded() ? String(Int(v)) : String(format: "%g", v)) \(plan.strengthUnit ?? "mg") weekly")
        }
        if let wd = plan.anchorWeekday, let word = Self.weekdayWords[wd] {
            parts.append("\(word)s")
        }
        return parts.joined(separator: " · ")
    }

    private var hadSelfPlan: Bool {
        CareReconciliation.priorSelfPlan(userId: userId, in: modelContext) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("from your care team")
                .font(Typo.caption)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, Space.xl)

            Text("your clinic set your medication plan")
                .font(.custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // the assigned facts, quietly
            Text(line)
                .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
                .foregroundStyle(Palette.textPrimary)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Palette.hairlineCocoa, lineWidth: 0.5))
                .padding(.top, Space.lg)
                .jeniAct(1, current: act)

            VStack(alignment: .leading, spacing: 10) {
                bullet(hadSelfPlan
                    ? "your earlier records stay in your chart."
                    : "everything you record stays in your chart.")
                bullet("your check-ins will follow this plan now.")
                bullet("if anything looks wrong, tell your care team.")
            }
            .padding(.top, Space.lg)
            .padding(.bottom, Space.lg)
            .jeniAct(2, current: act)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        // Pass 57 (D2) — this is the app's only `interactiveDismissDisabled`,
        // which is defensible (a clinical confirmation should be answered,
        // not swiped away) ONLY while both exits are guaranteed reachable.
        // The old body was a fixed VStack: at accessibility sizes on a
        // small phone the copy grew past the sheet and the two decision
        // buttons — the only ways out — could sit beyond reach. The copy
        // scrolls now and the decisions are pinned to the bottom edge.
        .modifier(JeniScrollingSheetBody())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    CareReconciliation.confirm(plan: plan, userId: userId, in: modelContext)
                    Haptics.soft()
                    onClose()
                } label: {
                    Text("looks right")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Palette.cocoaPrimary)
                        .clipShape(Capsule())
                }
                // p63 — the clinical confirm was the one ink capsule
                // in the app with no press response.
                .buttonStyle(JKPress())

                Button {
                    CareReconciliation.markFlagged(plan: plan, userId: userId, in: modelContext)
                    Haptics.soft()
                    showCorrection = true
                } label: {
                    Text("something's off")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                        .underline()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .buttonStyle(JKPress())
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
            .background(Palette.bgPrimary)
            .jeniAct(2, current: act)
        }
        .background(Palette.bgPrimary)
        .simultaneousGesture(TapGesture().onEnded {
            if act < 2 { Analytics.track(.arrivalSkipped, properties: ["surface": "reconcile"]) }
            JeniActs.complete($act, to: 2)
        })
        .task { await JeniActs.run($act, to: 2, reduceMotion: reduceMotion) }
        .interactiveDismissDisabled(true)
        .jeniSheet(isPresented: $showCorrection, detents: JeniSheetHeight.full) {
            CorrectionSheet(userId: userId, plan: plan, onDone: {
                showCorrection = false
                onClose()
            })
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(Palette.cocoaTertiary).frame(width: 4, height: 4)
                .offset(y: -3)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
