import SwiftUI

// MARK: - MethodNoteView
//
// The Method's whole surface. One screen, four things, in this order:
//
//   what jeni noticed   ← her record, in serif, the hero
//   why it is true      ← one mechanism sentence
//   where that comes from ← quiet provenance, when there is any
//   one thing to do     ← a pill into a door that already exists
//
// It inherits `RepView`'s shell deliberately — the eyebrow, the serif
// scenario, the tall pill, the staged beats — because that shell is
// already in the current design language and already the shape a person
// meets on this beat. What changed is upstream: the content is chosen by
// her record instead of by the calendar.
//
// The "not now" row is not politeness. A person who cannot leave a
// teaching surface without completing it will stop opening it, and this
// product's entire retention problem is people not coming back.

struct MethodNoteView: View {

    let resolved: ResolvedMethodNote
    /// Fires when she takes the action or acknowledges the note — the
    /// host marks the beat either way. Reading is not the point; the
    /// point is that the note happened.
    let onKept: () -> Void
    let onClose: () -> Void

    @State private var router = AppRouter.shared
    @State private var acted = false
    @State private var didRecordShow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var note: MethodNote { resolved.note }

    var body: some View {
        JKScreenChrome {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, Space.hero)
                        .jkBeat1()

                    ItalicAccentText(
                        resolved.line,
                        italic: resolved.italic,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 30, relativeTo: .title),
                        color: Palette.textPrimary,
                        alignment: .leading
                    )
                    .lineSpacing(-2)
                    .kerning(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xl)
                    .jkBeat2()

                    Text(note.because)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .jkBeat2(extraDelay: 0.06)

                    if let evidence = note.evidence {
                        evidenceRow(evidence)
                            .padding(.top, Space.md)
                            .jkBeat2(extraDelay: 0.1)
                    }

                    if let action = note.action, action.door != .none {
                        actionPill(action)
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.14)
                    } else if let action = note.action {
                        // An action with no door is still an action. It
                        // renders as the thing to remember, not as a
                        // button that goes nowhere.
                        Text(action.label)
                            .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.14)
                    }

                    dismissRow
                        .padding(.top, note.action == nil ? Space.section : Space.lg)
                        .jkBeat2(extraDelay: 0.2)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, Space.lg)
            }
        }
        .onAppear {
            guard !didRecordShow else { return }
            didRecordShow = true
            MethodLedger.markShown(resolved)
            Analytics.track(.methodNoteShown, properties: [
                "note_id": note.id,
                "trigger": note.trigger.rawValue,
                "kind": note.kind.rawValue,
                "authority": note.authority.isCareTeam ? "care_team" : "jeni",
                "has_action": note.action != nil,
            ])
        }
    }

    // MARK: - Header
    //
    // AUTHORITY IS A WORD, ALWAYS. "from jeni" / "from your care team" /
    // "from dr. okafor" sits in the eyebrow on every note, because a
    // patient who cannot tell a clinician's instruction from a product's
    // education cannot weigh either of them — and because colour alone
    // can never carry that distinction (a11y, and a rose tint is
    // forbidden on clinical surfaces anyway).

    private var header: some View {
        HStack(spacing: Space.sm) {
            Text(resolved.authorityLabel)
                .font(Typo.captionTracked)
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(
                    note.authority.isCareTeam
                        ? Palette.cocoaPrimary : Palette.cocoaTertiary
                )
            if note.authority.isCareTeam {
                // A drawn mark, not a colour, so the distinction survives
                // greyscale and every accessibility setting.
                Image(systemName: "stethoscope")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .accessibilityHidden(true)
            }
            Spacer()
            JKQuietMark(systemName: "xmark", accessibilityLabel: "close") { onClose() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            note.authority.isCareTeam
                ? "\(resolved.authorityLabel), from your clinic"
                : resolved.authorityLabel
        )
    }

    private func evidenceRow(_ evidence: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(width: 1)
            Text(evidence)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - The one action

    private func actionPill(_ action: MethodNote.Action) -> some View {
        Button {
            Haptics.soft()
            acted = true
            MethodLedger.markActionTaken(note.id)
            Analytics.track(.methodNoteAction, properties: [
                "note_id": note.id,
                "trigger": note.trigger.rawValue,
                "door": action.door.rawValue,
                "authority": note.authority.isCareTeam ? "care_team" : "jeni",
            ])
            onKept()
            if action.door == .askJeni {
                // The chat seam, not a route: jeni answers from her own
                // read tools, seeded with the observation rather than
                // with the note's words.
                router.openChat(seed: action.chatSeed)
            } else if let route = route(for: action.door) {
                router.open(route)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                Text(action.label)
                    .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule(style: .continuous).fill(Palette.roseBlush)
            )
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(action.label). opens \(action.door.rawValue)")
    }

    private var dismissRow: some View {
        Button {
            Haptics.light()
            MethodLedger.markOpened(note.id)
            Analytics.track(.methodNoteDismissed, properties: [
                "note_id": note.id,
                "trigger": note.trigger.rawValue,
            ])
            onKept()
            onClose()
        } label: {
            Text(note.action == nil ? "noted" : "not now")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
    }

    /// The door token → a real route. The engine and the catalog never
    /// hold an `AppRouter.Route`, which is what lets a clinician's note
    /// be plain data without handing it the ability to send a patient
    /// anywhere in the app.
    private func route(for door: MethodNote.Action.Door) -> AppRouter.Route? {
        switch door {
        case .describePlate: return .foodDescribe(text: "", spoken: false)
        case .againSheet:    return .snap
        case .weightTrend:   return .trend
        case .breath:        return .breath
        case .move:          return .move
        case .doseSheet:     return .doseSheet
        case .askJeni:       return nil   // handled by the host's chat seam
        case .none:          return nil
        }
    }
}
