import SwiftUI
import PlankSync

// MARK: - PostRoutineView — the kept receipt
//
// App v4 (docs/app_v4/03_FEATURES.md §7). The v1 celebration — black
// flash, fire Lottie, stat pills, a 5-star row AND a feel row,
// sticker scatter on a non-earned moment — dies. A workout ends the
// way every kept moment ends now: "kept." in serif, one receipt line,
// ONE feeling row (the relative-effort signal that tunes the next
// session — kept, restyled), and a quiet door out.
//
// Star ratings die app-wide with this file. The onRate contract is
// unchanged — (0, [effortFeel]) was already a legal payload — so the
// next-session energy nudge and the ratings pipe stay wired.

struct PostRoutineView: View {
    let exerciseResults: [ExerciseResultEntry]
    let totalDuration: TimeInterval
    let workoutName: String
    let streakCount: Int          // retired display; parameter kept for call-site stability
    let isFirstWorkoutToday: Bool
    /// `false` when the user ended below the 70% completion threshold —
    /// the receipt reads "you stopped when you needed to" and nothing
    /// is graded, because stopping early is listening.
    let didMeetThreshold: Bool
    let onRate: (Int, [String]) -> Void
    let onDone: () -> Void

    @State private var settled = false
    /// "too_easy" / "just_right" / "too_hard" — the one signal that
    /// matters (beginners can't self-rate RPE; relative feel works).
    @State private var effortFeel: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var completedCount: Int {
        exerciseResults.filter { !$0.skipped }.count
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // The word.
                Text(didMeetThreshold ? "kept." : "ended early.")
                    .font(.custom("JeniHeroSerif-Regular", size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.textPrimary)
                    .opacity(settled ? 1 : 0)
                    .offset(y: settled ? 0 : 10)

                Text(didMeetThreshold
                     ? "the whole thing, start to close \u{2665}\u{FE0E}"
                     : "you stopped when you needed to. it still counts \u{2665}\u{FE0E}")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 6)
                    .opacity(settled ? 1 : 0)
                    .offset(y: settled ? 0 : 8)

                // The receipt — lines of fact, nothing counted twice.
                VStack(spacing: 0) {
                    JKReceiptRow(
                        lead: "the move",
                        punch: workoutName.lowercased(),
                        punchItalic: [],
                        showsRule: false
                    )
                    JKReceiptRow(
                        lead: "held for",
                        punch: minutesWord,
                        punchItalic: [minutesWord]
                    )
                    if !didMeetThreshold, completedCount > 0 {
                        JKReceiptRow(
                            lead: "landed",
                            punch: completedCount == 1
                                ? "one move" : "\(completedCount) moves",
                            punchItalic: []
                        )
                    }
                }
                .padding(.top, Space.xl)
                .opacity(settled ? 1 : 0)

                // The one question — a feeling, not a grade. It tunes
                // the next session's energy.
                VStack(alignment: .leading, spacing: 10) {
                    Text(effortFeel.isEmpty ? "how did it land?" : feelAck)
                        .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .animation(Motion.entranceSoft, value: effortFeel)
                    if effortFeel.isEmpty {
                        HStack(spacing: 10) {
                            feelChip("too easy", key: "too_easy")
                            feelChip("just right", key: "just_right")
                            feelChip("too hard", key: "too_hard")
                        }
                    }
                }
                .padding(.top, Space.xl)
                .opacity(settled ? 1 : 0)

                Spacer()

                JFContinueButton(label: "done") {
                    if !effortFeel.isEmpty {
                        onRate(0, [effortFeel])
                    }
                    onDone()
                }
                .opacity(settled ? 1 : 0)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .onAppear {
            Analytics.captureScreen("PostRoutine")
            if didMeetThreshold { Haptics.success() } else { Haptics.soft() }
            if reduceMotion { settled = true; return }
            withAnimation(Motion.entranceSoft.delay(0.15)) { settled = true }
        }
    }

    // MARK: - Pieces

    private var minutesWord: String {
        let minutes = max(1, Int(totalDuration) / 60)
        return minutes == 1 ? "one minute" : "\(minutes) minutes"
    }

    private var feelAck: String {
        switch effortFeel {
        case "too_easy": return "noted. next time leans a little stronger \u{2665}\u{FE0E}"
        case "too_hard": return "noted. next time runs gentler \u{2665}\u{FE0E}"
        default: return "good. the pace holds \u{2665}\u{FE0E}"
        }
    }

    private func feelChip(_ label: String, key: String) -> some View {
        Button {
            Haptics.soft()
            withAnimation(Motion.entranceSoft) { effortFeel = key }
        } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().strokeBorder(
                        Palette.cocoaPrimary.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(JKPress())
    }
}
