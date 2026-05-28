import SwiftUI

/// Read-only index of past JeniFit Method lessons. Phase 7 of
/// docs/diet_education_plan.md. Shown via SettingsSheet.jeniMethod after
/// the user has completed Lesson 5; lets them revisit any of the five
/// lessons in read-only mode.
///
/// Phase 9.22 — migrated to JeniMethodRitualView. `isReread: true`
/// still gates analytics + markLessonCompleted via the same path.
/// Re-reads also skip the workoutHandoff side-effect because that
/// closure is only provided on the live post-paywall + auto-present
/// paths; on re-read it falls back to plain onComplete.
struct JeniMethodReReadView: View {
    @State private var selectedLesson: LessonID? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("the jenifit method")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                Text("revisit any lesson. these are yours to keep. no progress tracking on re-reads.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .lineSpacing(2)

                VStack(spacing: Space.md) {
                    // dailyLessons (not allCases) so the generic Day 6+
                    // check-in doesn't appear in the re-read index — it's
                    // not a fixed lesson, it's a rotating daily ritual.
                    ForEach(LessonID.dailyLessons) { lesson in
                        lessonRow(for: lesson)
                    }
                }
                .padding(.top, Space.sm)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fullScreenCover(item: $selectedLesson) { lesson in
            JeniMethodRitualView(
                lesson: lesson,
                user: .fromAppStorage(),
                isReread: true,
                onComplete: { selectedLesson = nil },
                onSkip:     { _ in selectedLesson = nil }
            )
        }
    }

    private func lessonRow(for lesson: LessonID) -> some View {
        Button {
            selectedLesson = lesson
        } label: {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("lesson \(lesson.rawValue) of 5")
                    .font(Typo.eyebrow)
                    .foregroundStyle(Palette.textSecondary)
                Text(lesson.headline)
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .padding(Space.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Palette.accent.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lesson \(lesson.rawValue) of 5: \(lesson.headline)")
        .accessibilityHint("Re-read this lesson")
    }
}

#if DEBUG
#Preview {
    JeniMethodReReadView()
        .background(Palette.bgPrimary)
}
#endif
