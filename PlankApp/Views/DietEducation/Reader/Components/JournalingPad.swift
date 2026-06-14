import SwiftUI
import PencilKit

// MARK: - JournalingPad
//
// The lesson reader's response surface for journaling prompts. Two modes:
//
//   1. **Ink (default)** — a PencilKit canvas the user draws on with finger
//      or Apple Pencil. The handwriting register elevates the prompt
//      into a journal artifact — slower, more reflective, more brand-
//      cohesive with the her75 editorial magazine aesthetic. Stroke
//      color = cocoa (Palette.textPrimary), pen width 4pt. Drawing
//      data persists in AppStorage as PKDrawing JSON so the user can
//      come back and add to the entry; never syncs to server (the
//      privacy rule for prompts stays).
//
//   2. **Type (fallback)** — a TextEditor with cocoa text on cream-card,
//      for users who prefer keyboard, accessibility users, or anyone
//      who hits the "tap to type" toggle in the top-right.
//
// Persistence keys are scoped by `(lessonSlotId, page)` so each prompt
// has its own draft and the user's response survives a cover dismissal.
// Keep both modes' drafts side-by-side so toggling between them never
// loses input.
//
// Why default to ink: prompt-response in a CBT lesson is a low-volume
// reflection (1-2 sentences typical). Typing rushes the response into
// performative keyboard-shaped sentences; handwriting slows the user
// down, which is the actual point of the prompt. The "type instead"
// toggle is one tap for anyone who wants it.

struct JournalingPad: View {
    let lessonSlotId: String
    let page: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var mode: JournalingPadMode

    @AppStorage private var typedDraft: String
    @AppStorage private var modeRaw: String
    @State private var inkCanvas: PKCanvasView = PKCanvasView()

    init(lessonSlotId: String, page: Int) {
        self.lessonSlotId = lessonSlotId
        self.page = page
        let typedKey = "jenimethod.prompt.typed.\(lessonSlotId).\(page)"
        let modeKey = "jenimethod.prompt.mode.\(lessonSlotId).\(page)"
        _typedDraft = AppStorage(wrappedValue: "", typedKey)
        _modeRaw = AppStorage(wrappedValue: JournalingPadMode.ink.rawValue, modeKey)
        // Initialize @State from the persisted mode at first render.
        let initial = JournalingPadMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "")
            ?? .ink
        // For users with accessibility larger-text settings or VoiceOver,
        // default to type — handwriting input doesn't play well with AT.
        let isLargeAccessibility = UIAccessibility.isVoiceOverRunning
        _mode = State(initialValue: isLargeAccessibility ? .type : initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            // Mode toggle — tiny, sits top-right above the pad.
            HStack(alignment: .center) {
                Spacer()
                Button {
                    Haptics.light()
                    withAnimation(reduceMotion ? .none : Motion.bloom) {
                        mode = (mode == .ink) ? .type : .ink
                        modeRaw = mode.rawValue
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode == .ink ? "keyboard" : "pencil.tip")
                            .font(.system(size: 11, weight: .medium))
                        Text(mode == .ink ? "tap to type" : "tap to write")
                            .font(.custom("DMSans-Medium", size: 11))
                            .kerning(0.3)
                    }
                    .foregroundStyle(Palette.textSecondary.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.white.opacity(0.55))
                    )
                    .overlay(
                        Capsule().stroke(Palette.divider.opacity(0.8), lineWidth: 0.8)
                    )
                }
                .accessibilityLabel(mode == .ink ? "switch to typing" : "switch to handwriting")
            }

            Group {
                switch mode {
                case .ink:
                    InkCanvas(canvas: $inkCanvas, lessonSlotId: lessonSlotId, page: page)
                        .transition(.opacity)
                case .type:
                    typingPad
                        .transition(.opacity)
                }
            }
        }
    }

    private var typingPad: some View {
        TextEditor(text: $typedDraft)
            .font(.custom("DMSans-Regular", size: 15))
            // CRITICAL — explicit cocoa color so the text never inherits
            // the system default (which renders WHITE in dark mode and
            // was invisible against the cream card per founder QA
            // 2026-06-13).
            .foregroundStyle(Palette.textPrimary)
            .tint(Palette.accent)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 132)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.divider, lineWidth: 1)
            )
            .accessibilityLabel("type your response")
            .accessibilityHint("your response stays on this device")
    }
}

enum JournalingPadMode: String {
    case ink
    case type
}

// MARK: - InkCanvas (PencilKit-backed handwriting pad)
//
// SwiftUI wrapper around PKCanvasView. Cocoa-ink pen tool, finger or
// Pencil supported (`drawingPolicy = .anyInput`), no background (the
// outer card paints the cream). Auto-persists the drawing to
// AppStorage as base64-encoded PKDrawing data scoped to the (slot,
// page) pair.
//
// The PencilKit toolbar (`PKToolPicker`) is deliberately NOT shown.
// One tool, one color, one width. Premium = constraint. Erase is via
// two-finger tap (PencilKit gesture) or the small "clear" affordance.

private struct InkCanvas: View {
    @Binding var canvas: PKCanvasView
    let lessonSlotId: String
    let page: Int

    @State private var hasInk: Bool = false

    private var persistKey: String {
        "jenimethod.prompt.ink.\(lessonSlotId).\(page)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CanvasRepresentable(canvas: $canvas,
                                hasInk: $hasInk,
                                persistKey: persistKey)
                .frame(minHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("draw your response")
                .accessibilityHint("your handwriting stays on this device")

            // Subtle baseline-rule hint inside the empty pad. Pure
            // visual — the user can write anywhere, this just frames
            // the empty canvas the way a journal page would have a
            // single ruled line.
            if !hasInk {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer().frame(height: 32)
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 11, weight: .medium))
                        Text("write with your finger or pencil")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    }
                    .foregroundStyle(Palette.textSecondary.opacity(0.55))
                    .padding(.horizontal, 14)
                    Rectangle()
                        .fill(Palette.divider.opacity(0.55))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            if hasInk {
                Button {
                    Haptics.light()
                    canvas.drawing = PKDrawing()
                    UserDefaults.standard.removeObject(forKey: persistKey)
                    hasInk = false
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 9, weight: .semibold))
                        Text("clear").font(.custom("DMSans-Medium", size: 10)).kerning(0.4)
                    }
                    .foregroundStyle(Palette.textSecondary.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.75)))
                    .overlay(Capsule().stroke(Palette.divider.opacity(0.8), lineWidth: 0.6))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(8)
                .accessibilityLabel("clear handwriting")
            }
        }
    }
}

// MARK: - UIViewRepresentable for PKCanvasView

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var hasInk: Bool
    let persistKey: String

    func makeUIView(context: Context) -> PKCanvasView {
        let view = canvas
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput   // finger or pencil
        // Cocoa-ink pen. UIColor(Color) bridges from the brand palette
        // so any future palette swap propagates. Width 4 is the
        // "magazine-marginalia" weight — readable, not childish.
        view.tool = PKInkingTool(.pen, color: UIColor(Palette.textPrimary), width: 4)
        view.delegate = context.coordinator
        // Restore any prior drawing.
        if let data = UserDefaults.standard.data(forKey: persistKey),
           let drawing = try? PKDrawing(data: data) {
            view.drawing = drawing
            DispatchQueue.main.async {
                self.hasInk = !drawing.strokes.isEmpty
            }
        }
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No-op — coordinator handles writes.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasRepresentable
        init(parent: CanvasRepresentable) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Persist on every change. PKDrawing's dataRepresentation
            // is compact (vector strokes), so writing on every tick is
            // cheap; for an 88pt pad a few sentences of cursive < 3KB.
            let data = canvasView.drawing.dataRepresentation()
            UserDefaults.standard.set(data, forKey: parent.persistKey)
            let nowHasInk = !canvasView.drawing.strokes.isEmpty
            if parent.hasInk != nowHasInk {
                DispatchQueue.main.async {
                    self.parent.hasInk = nowHasInk
                }
            }
        }
    }
}

#if DEBUG
#Preview("JournalingPad — ink default") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        JournalingPad(lessonSlotId: "D01_preview", page: 3)
            .padding(.horizontal, Space.lg)
    }
}
#endif
