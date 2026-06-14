import SwiftUI

// MARK: - PromptJournalSheet
//
// Round-4 prompt response surface. Replaces the inline 280pt
// PencilKit pad on P3. Now the inline prompt page renders ONLY the
// question + a "write" chip; tapping the chip lifts the full pad
// here as a presentation cover, saving 240pt of vertical column.
//
// The sheet itself is a magazine-page-style spread: cream bg,
// italic-Fraunces question header, full-height JournalingPad,
// cocoa "done" CTA. Drag-down dismissable; scale-degrades during
// the drag so the user feels the page lift back to the lesson.
//
// PencilKit drawings persist via the existing JournalingPad UserDefaults
// scoping by (lessonSlotId, page). No server sync.

struct PromptJournalSheet: View {
    let lessonSlotId: String
    let page: Int
    let promptText: String
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Round-8 polish: drag indicator pill so the
                // gesture is discoverable, plus an editorial kicker
                // + hairline so the sheet feels like its own
                // magazine spread, not a generic modal.
                Capsule()
                    .fill(Palette.textPrimary.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .accessibilityHidden(true)

                Text("your turn")
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(1.98)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.bottom, 8)

                Text(promptText.lowercased())
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22,
                                  relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 56, height: 0.75)
                    .padding(.vertical, 14)

                // The existing JournalingPad already handles ink + type
                // toggle + persistence; we just lift it into a sheet.
                JournalingPad(lessonSlotId: lessonSlotId, page: page)
                    .frame(maxHeight: .infinity)

                JFContinueButton(label: "done") {
                    Haptics.soft()
                    dismiss()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.textPrimary.opacity(0.08), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
        .offset(y: dragOffset)
        .scaleEffect(1.0 - min(max(dragOffset, 0), 200) / 1200)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 120 ||
                       value.predictedEndTranslation.height > 800 {
                        Haptics.soft()
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear { Haptics.light() }
    }
}
