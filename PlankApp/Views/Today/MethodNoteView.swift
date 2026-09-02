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
    /// p63 — the note SPEAKS: the claim, then the argument (because +
    /// evidence), then the action. The old two-beat spread landed the
    /// argument on top of the claim 0.06s apart.
    @State private var act = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var note: MethodNote { resolved.note }

    var body: some View {
        JKScreenChrome {
            // p66 — THE STICKY ANATOMY (founder law): the exit pins at
            // the top, the decision pins at the bottom, and only the
            // note itself scrolls between them. The p54 optical-center
            // float survives for short notes: the GeometryReader now
            // measures exactly the between-space, so `minHeight`
            // centers in what is actually visible.
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.lg)
                    .jkBeat1()
                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            noteBlock
                            // AX escape (the p54/p57 law-shape): at
                            // accessibility sizes the pinned block
                            // would trap the note in a sliver and
                            // clip the argument behind the pill (AX5
                            // filmed) — the decision JOINS the scroll
                            // so everything stays reachable.
                            if typeSize.isAccessibilitySize {
                                actionsBlock
                                    .padding(.horizontal, Space.lg)
                                    .padding(.bottom, Space.lg)
                            }
                        }
                        .frame(minHeight: geo.size.height, alignment: .center)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                if !typeSize.isAccessibilitySize {
                    actionsBlock
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.lg)
                }
            }
        }
        .onAppear {
            guard !didRecordShow else { return }
            didRecordShow = true
            noteDidShow()
        }
        .simultaneousGesture(TapGesture().onEnded {
            if act < 2 { Analytics.track(.arrivalSkipped, properties: ["surface": "method"]) }
            JeniActs.complete($act, to: 2)
        })
        .task { await JeniActs.run($act, to: 2, reduceMotion: reduceMotion) }
    }

    private var noteBlock: some View {
                VStack(alignment: .leading, spacing: 0) {
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
                    .jkBeat2()

                    Text(note.because)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .jeniAct(1, current: act)

                    if let evidence = resolved.evidenceLine {
                        // p54 — the resolved, suppression-aware line;
                        // never `note.evidence` directly (its numerals
                        // reached the suppressed cohort).
                        evidenceRow(evidence)
                            .padding(.top, Space.md)
                            .jeniAct(1, current: act)
                    }

                }
                .padding(.horizontal, Space.lg)
                // Bottom bias: the centred block sits a breath above
                // true centre, which is where the letter floats.
                .padding(.bottom, Space.lg)
    }

    /// p66 — the pinned decision block (sticky-anatomy law): the one
    /// action and the quiet exit live at the bottom edge, never in the
    /// scroll.
    @ViewBuilder private var actionsBlock: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            if let action = note.action, action.door != .none {
                actionPill(action)
            } else if let action = note.action {
                // An action with no door is still an action. It
                // renders as the thing to remember, not as a
                // button that goes nowhere.
                Text(action.label)
                    .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
            }
            dismissRow
        }
        .jeniAct(2, current: act)
    }

    private func noteDidShow() {
        MethodLedger.markShown(resolved)
        Analytics.track(.methodNoteShown, properties: [
            "note_id": note.id,
            "trigger": note.trigger.rawValue,
            "kind": note.kind.rawValue,
            "authority": note.authority.isCareTeam ? "care_team" : "jeni",
            "has_action": note.action != nil,
            // p54 — the evidence spine reaches the measurement: which
            // GRADE of claim was on screen (s / rp / a), never the
            // sentence itself.
            "evidence_tier": note.evidenceTier.rawValue,
        ])
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

    // p66 — the note's action is THE standing CTA now. It was the
    // last hand-rolled ink pill on a Jeni-speaking surface (a
    // left-aligned serif-in-capsule with an arrow glyph, against the
    // her75 CTA register lock: primary actions are centered upright
    // sans, one implementation, one press hand). One decision, one
    // object, everywhere Jeni asks.
    private func actionPill(_ action: MethodNote.Action) -> some View {
        JFContinueButton(label: action.label, action: {
            JeniHaptic.land()   // p58 — the grammar's word for it
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
        }, firesHaptic: false, padded: false)
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
