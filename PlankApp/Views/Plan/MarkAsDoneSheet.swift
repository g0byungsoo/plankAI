import SwiftUI

// MARK: - MarkAsDoneSheet
//
// v1.1 program pivot — PlanView v4 per [[feedback-no-checkbox-circle]].
// Long-press on any binary PlanRow presents this sheet as the manual
// override for the "I did it offline" edge case (walk without phone,
// lesson on partner's device, etc.).
//
// Voice rules honored:
//   - No "complete" verb (anti-shame, post-Ozempic vocabulary).
//   - Lowercase casual register.
//   - No em-dashes between words.
//   - White edge-to-edge via .presentationBackground (lock sheet
//     pattern reused).
//
// Sets ProgramService.ChecklistState to `.complete` — NOT
// `.autoCompleted` — so analytics + UI can later distinguish
// system-fired completions from manual overrides (sparkle glyph
// shows only on auto, never on manual).

struct MarkAsDoneSheet: View {

    let prescription: ProgramDayPrescription
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            handle
            content
            Spacer(minLength: 24)
            ctas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.programCard)
    }

    private var handle: some View {
        Capsule()
            .fill(Palette.hairlineCocoa)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 28)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            // v8: pull the row's JeniFit sticker into the confirm
            // sheet so the long-press destination is visually anchored
            // to the same scrapbook mark the user just pressed. Falls
            // back to the SF symbol for rows without a sticker.
            Group {
                if let asset = prescription.stickerAsset {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: prescription.stickyGlyph)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Pull-quote register — italic Fraunces 22pt.
            Text(headlineCopy)
                .font(Typo.pullQuote)
                .foregroundStyle(Palette.cocoaPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Soft supporting line. Voice: trust the user, no proof asked.
            Text("we trust you. tap below to mark today's \(prescription.rowTitle) as done.")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Space.lg + 4)
    }

    private var ctas: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.success()
                onConfirm()
            } label: {
                Text("mark as done")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Palette.cocoaPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                onDismiss()
            } label: {
                Text("not yet")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, 24)
    }

    private var headlineCopy: String {
        switch prescription {
        case .lesson:       return "did you read today's lesson?"
        case .snapMeal:     return "logged a meal offline?"
        case .workout:      return "moved your body today?"
        case .plank:        return "did your plank today?"
        case .breath:       return "took a moment to breathe?"
        case .steps:        return "walked offline?"
        case .water:        return "drank some water?"
        case .weighIn:      return "stepped on the scale?"
        case .measurements: return "took measurements?"
        }
    }
}
