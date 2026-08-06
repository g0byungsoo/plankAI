import SwiftUI
import SwiftData
import PlankSync

// MARK: - RegimenSheet
//
// App v8 — her regimen, one small sheet. Two faces by authority:
//   · SELF (v8 S1): the shot-day weekday picker she owns.
//   · CARE_TEAM (v8 S4): read-only assigned facts + a correction
//     door. She never edits a clinician plan; she reports if it
//     looks wrong (a 164.526-shaped request, never a mutation).
// Generic wording only — no drug names authored by the app (Apple
// 5.2.1). The clinical register throughout: ink, hairlines, no
// hearts, no rose, no celebration.

struct RegimenSheet: View {
    let userId: String
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var plan: RegimenPlanRecord?
    @State private var pickedWeekday: Int?
    @State private var showCorrection = false

    private static let weekdays: [(iso: Int, word: String)] = [
        (1, "monday"), (2, "tuesday"), (3, "wednesday"), (4, "thursday"),
        (5, "friday"), (6, "saturday"), (7, "sunday"),
    ]

    private var isCareTeam: Bool {
        guard let plan else { return false }
        return RegimenService.isManagedByCareTeam(plan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCareTeam, let plan {
                careTeamFace(plan)
            } else {
                selfFace
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .background(Palette.bgPrimary)
        .onAppear {
            let resolved = RegimenService.activeMedicationPlan(userId: userId, in: modelContext)
            plan = resolved
            pickedWeekday = resolved?.anchorWeekday
        }
        .sheet(isPresented: $showCorrection) {
            if let plan {
                CorrectionSheet(userId: userId, plan: plan, onDone: { showCorrection = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.bgPrimary)
            }
        }
    }

    // MARK: care-team face (read-only, S4)

    @ViewBuilder
    private func careTeamFace(_ plan: RegimenPlanRecord) -> some View {
        Text("your medication")
            .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)

        Text("recorded by your care team.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 4)

        VStack(spacing: 0) {
            factRow("medication", plan.displayName.isEmpty ? "your medication" : plan.displayName)
            if let v = plan.strengthValue {
                factRow("dose", "\(formatDose(v)) \(plan.strengthUnit ?? "mg")")
            }
            if let wd = plan.anchorWeekday, let word = Self.weekdays.first(where: { $0.iso == wd })?.word {
                factRow("schedule", "weekly · \(word)s")
            }
            if let inst = plan.instruction, !inst.isEmpty {
                factRow("how", inst)
            }
        }
        .padding(.top, Space.lg)

        Button {
            Haptics.soft()
            showCorrection = true
        } label: {
            Text("something look wrong?")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
                .underline()
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.lg)

        Text("only you see this. never named in notifications. this is the plan your clinic recorded, not a prescription.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Text(value)
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    private func formatDose(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%g", v)
    }

    // MARK: self face (the shot-day picker, S1)

    @ViewBuilder
    private var selfFace: some View {
        Text("your medication")
            .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)

        Text("dose days shape themselves around your shot. no names, no doses. just the day.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)

        Text("which day is your shot, usually?")
            .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
            .foregroundStyle(Palette.cocoaSecondary)
            .padding(.top, Space.lg)
            .padding(.bottom, 4)

        VStack(spacing: 0) {
            ForEach(Self.weekdays, id: \.iso) { day in
                weekdayLine(day.iso, day.word)
            }
        }

        if plan != nil {
            Button {
                RegimenService.endMedicationPlan(userId: userId, in: modelContext)
                Haptics.soft()
                onDone()
            } label: {
                Text("not on medication right now")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .underline()
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.lg)
        }

        Text("only you see this. never named in notifications.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, plan != nil ? 10 : Space.lg)
            .padding(.bottom, Space.xl)
    }

    private func weekdayLine(_ iso: Int, _ word: String) -> some View {
        Button {
            RegimenService.setShotDay(iso, userId: userId, in: modelContext)
            withAnimation(Motion.entranceSoft) { pickedWeekday = iso }
            Haptics.soft()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onDone() }
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Text(word)
                        .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                        .foregroundStyle(
                            pickedWeekday == nil || pickedWeekday == iso
                                ? Palette.textPrimary
                                : Palette.textPrimary.opacity(0.35)
                        )
                    Spacer()
                    if pickedWeekday == iso {
                        Text("your shot day")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 10)
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(word)
        .accessibilityAddTraits(
            pickedWeekday == iso ? [.isButton, .isSelected] : .isButton
        )
    }
}
