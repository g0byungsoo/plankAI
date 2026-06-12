import SwiftUI
import SwiftData
import PlankSync
import Auth

/// "your pace." — v1.1 clean-luxury pass. The old "your plan." sheet
/// edited focus area + session length, standalone-generator inputs the
/// program engine never reads (ProgramGoalCalculator derives from
/// onboarding cohort fields instead). Both sections are gone; what
/// remains is the one knob that's actually live — workoutLevel, the
/// difficulty baseline every generated session reads — plus the real
/// program frame so the page states facts, not stale choices.
struct EditProfileView: View {
    /// Persistent workout-level baseline (-1 gentle · 0 steady · +1 more).
    /// Local device pref (no DB sync); RoutineSessionView nudges it
    /// post-session, the generator reads it as the difficulty floor.
    @AppStorage("workoutLevel") private var workoutLevel = 0

    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared

    private var levelOptions: [(label: String, caption: String, value: Int)] {
        [
            ("keep it gentle", "softer moves, longer rests", -1),
            ("steady",         "the pace your plan was built for", 0),
            ("a little more",  "she's warmed up. push slightly.", 1),
        ]
    }

    /// "day N of M" from the active plan — facts only, omitted when no
    /// plan exists or the program is post-goal.
    private var programPill: String? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty,
              let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        else { return nil }
        let schedule = ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
        guard !schedule.isPostGoal else { return nil }
        return "day \(schedule.programDay) of \(schedule.totalDays)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                JFPageHero(title: "your pace.", italic: ["pace."],
                           pill: programPill, alignment: .leading)

                Spacer().frame(height: 14)

                Text("your days adapt to this. change it any time, no penalty, no reset.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 36)

                SettingsSection(title: "how it should feel") {
                    ForEach(levelOptions, id: \.value) { option in
                        paceRow(option)
                    }
                }

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.programEraBg)
    }

    private func paceRow(_ option: (label: String, caption: String, value: Int)) -> some View {
        let selected = workoutLevel == option.value
        return Button {
            guard !selected else { return }
            Haptics.soft()
            workoutLevel = option.value
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(selected
                              ? .custom("Fraunces72pt-SemiBoldItalic", size: 17)
                              : Typo.body)
                        .foregroundStyle(selected ? Palette.textPrimary : Palette.cocoaSecondary)
                    Text(option.caption)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                Spacer()
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 7, height: 7)
                    .scaleEffect(selected ? 1 : 0.01)
                    .opacity(selected ? 1 : 0)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsGlowPressStyle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
        .animation(Motion.gentleSpring, value: selected)
    }
}
