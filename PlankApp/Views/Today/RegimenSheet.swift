import SwiftUI
import SwiftData
import PlankSync

// MARK: - RegimenSheet
//
// App v8 (docs/app_v8/03_ARCHITECTURE.md §3c) — her regimen, one
// small sheet. The medication row's module: the shot-day anchor
// (the one field the engines read to shape dose days), changeable
// anytime, removable without ceremony. Generic wording only —
// no drug names, no doses, ever (Apple 5.2.1 + the app-authors-
// nothing law). Sheet contract: cream, grabber, content-fitted,
// no conditional-blank closures.

struct RegimenSheet: View {
    let userId: String
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var pickedWeekday: Int?
    @State private var hadPlan = false

    private static let weekdays: [(iso: Int, word: String)] = [
        (1, "monday"), (2, "tuesday"), (3, "wednesday"), (4, "thursday"),
        (5, "friday"), (6, "saturday"), (7, "sunday"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("your medication")
                .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Space.xl)

            Text("dose days shape themselves around your shot. no names, no doses — just the day.")
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

            if hadPlan {
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

            Text("kept in your private record. never named in notifications.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, hadPlan ? 10 : Space.lg)
                .padding(.bottom, Space.xl)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .background(Palette.bgPrimary)
        .onAppear {
            let plan = RegimenService.activeMedicationPlan(userId: userId, in: modelContext)
            pickedWeekday = plan?.anchorWeekday
            hadPlan = plan != nil
        }
    }

    /// A weekday as a hairline menu line — the rule is the row's
    /// only chrome; her shot day inks rose.
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
                            pickedWeekday == iso ? Palette.jeweledRose : Palette.textPrimary
                        )
                    Spacer()
                    if pickedWeekday == iso {
                        Text("your shot day")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.jeweledRose)
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
