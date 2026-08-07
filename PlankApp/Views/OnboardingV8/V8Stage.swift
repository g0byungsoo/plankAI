import SwiftUI

// MARK: - V8Beat
//
// One conversational unit: jeni's lines → an input (or none) → an
// acknowledgment that echoes the answer. Content closures read the
// live store so branch cohorts and personas resolve at render time.

struct V8Beat: Identifiable {
    let id: String
    var lines: (OV5Store) -> [V8Line]
    var caption: ((OV5Store) -> String?)?
    var input: (OV5Store) -> V8Input
    var preselected: (OV5Store) -> Set<String>
    var commit: (OV5Store, V8AnswerPayload) -> Void
    var ack: (OV5Store, V8AnswerPayload) -> [V8Line]
    /// Fear rows strike through on selection.
    var strikes: Bool
    init(
        _ id: String,
        lines: @escaping (OV5Store) -> [V8Line],
        caption: ((OV5Store) -> String?)? = nil,
        input: @escaping (OV5Store) -> V8Input = { _ in .statement },
        preselected: @escaping (OV5Store) -> Set<String> = { _ in [] },
        commit: @escaping (OV5Store, V8AnswerPayload) -> Void = { _, _ in },
        ack: @escaping (OV5Store, V8AnswerPayload) -> [V8Line] = { _, _ in [] },
        strikes: Bool = false
    ) {
        self.id = id
        self.lines = lines
        self.caption = caption
        self.input = input
        self.preselected = preselected
        self.commit = commit
        self.ack = ack
        self.strikes = strikes
    }
}

enum V8Validation {
    case proceed
    case retry([V8Line])
}

/// The answer payload crosses the ack Task's capture boundary in a
/// reference box: captured BY VALUE, the enum arrived corrupted (read
/// back as `.none`) on the iOS 26.2 sim — the same miscompile family
/// as the @Observable deinit aborts. A class capture is a pointer.
private final class V8PayloadBox {
    let value: V8AnswerPayload
    init(_ value: V8AnswerPayload) { self.value = value }
}

// MARK: - V8Stage
//
// The consult's paper stage. Runs ONE beat at a time but keeps the
// transcript across talk beats, so step boundaries are invisible —
// the page just keeps being written. The host swaps `beat` and the
// stage's `.task(id:)` lifecycle does the rest.

struct V8Stage: View {
    let beat: V8Beat
    let store: OV5Store
    /// True when this beat was re-entered via back — render settled.
    let restored: Bool
    let onAdvance: (V8AnswerPayload) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Conversation state — survives beat swaps (the page persists).
    @State private var messages: [V8Msg] = []
    @State private var nextMsgID = 0

    // Per-beat state.
    private enum Phase { case typing, awaiting, acking }
    @State private var phase: Phase = .typing
    @State private var inputShown = false
    @State private var selected: Set<String> = []
    @State private var nameText = ""
    @State private var rulerValue: Double = 0
    @State private var rulerUnit: Int = 0
    @State private var skipRequested = false
    /// The beat whose input is live. Stale UI closures (a dissolving
    /// card, an XCUI interruption replay) carry their own beat id and
    /// are rejected — the code-probe caught a door tap answering the
    /// code beat.
    @State private var activeBeatID = ""
    /// The ack runs outside the beat's `.task` lifecycle; hold the
    /// handle so back-nav or teardown can't fire a stale advance.
    @State private var ackTask: Task<Void, Never>? = nil

    var body: some View {
        GeometryReader { geo in
            let anchorY = anchor(in: geo.size.height)
            V8Transcript(messages: displayMessages, anchorY: anchorY) {
                // The input is part of the column — it composes under
                // the active message, so the seating is layout-true.
                if inputShown {
                    inputColumn(height: geo.size.height)
                        .transition(.opacity.combined(with: .offset(y: JeniMotion.rise)))
                }
            }
            .padding(.horizontal, Space.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .bottom) {
            // Commit actions live where thumbs live. Only inputs with
            // an explicit commit (multi, ruler) dock a pill.
            if inputShown, let dock = dockSpec {
                VStack(spacing: 2) {
                    JeniPrimaryButton(dock.cta) {
                        guard dock.enabled else { return }
                        dock.commit()
                    }
                    .opacity(dock.enabled ? 1 : 0.35)
                    if let skip = dock.skip {
                        V8SkipLink(label: skip.label) { skip.commit() }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.sm)
                .transition(.opacity.combined(with: .offset(y: JeniMotion.rise)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .mask(
            // Retiring lines dissolve into the chrome, never clip.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 44)
                Color.black
            }
        )
        .task(id: taskKey) { await runBeat() }
        .onDisappear { ackTask?.cancel() }
        .animation(V8Tempo.anchorShift, value: inputShown)
    }

    // MARK: layout math

    private var currentInput: V8Input { beat.input(store) }

    private var asking: Bool { inputShown && currentInput.risesToTop }

    private func anchor(in height: CGFloat) -> CGFloat {
        asking ? 18 : height * 0.30
    }

    /// In ask mode the history fades away and only the question holds
    /// the page with its input.
    private var displayMessages: [V8Msg] {
        asking ? messages.suffix(1).map { $0 } : messages
    }

    private var taskKey: String { "\(beat.id)-\(restored)" }

    private struct DockSpec {
        let cta: String
        let enabled: Bool
        let commit: () -> Void
        let skip: (label: String, commit: () -> Void)?
    }

    private var dockSpec: DockSpec? {
        switch currentInput {
        case .multi(_, let minCount, let cta, let skipLabel):
            return DockSpec(
                cta: cta,
                enabled: selected.count >= minCount,
                commit: { answer(.set(selected), from: beat.id) },
                skip: skipLabel.map { label in
                    (label: label, commit: { answer(.set([]), from: beat.id) })
                }
            )
        case .ruler(let spec):
            return DockSpec(
                cta: spec.cta,
                enabled: true,
                commit: { answer(.value(rulerValue, unit: rulerUnit), from: beat.id) },
                skip: nil
            )
        default:
            return nil
        }
    }

    // MARK: the beat lifecycle

    @MainActor
    private func runBeat() async {
        // Reset per-beat state.
        activeBeatID = beat.id
        skipRequested = false
        selected = beat.preselected(store)
        nameText = ""
        if case .ruler(let spec) = currentInput {
            rulerUnit = spec.initialUnit
            rulerValue = spec.clamped(spec.initial, at: spec.initialUnit)
        }

        if restored {
            // Back-nav re-entry: the beat renders settled — its lines
            // fully written, its input up, its stored answer selected.
            messages = beat.lines(store).map { line in
                defer { nextMsgID += 1 }
                return V8Msg(id: nextMsgID, line: line, revealed: .max)
            }
            phase = .awaiting
            if !currentInput.isStatement {
                withAnimation(V8Tempo.inputArrive) { inputShown = true }
            }
            return
        }

        phase = .typing
        inputShown = false
        // A fresh paragraph (after a chapter or structured moment)
        // waits for the surface crossfade to finish before the first
        // ink arrives — never type over a dissolving page (loop-1).
        if messages.isEmpty {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
        }
        await type(lines: beat.lines(store))
        guard !Task.isCancelled else { return }

        if currentInput.isStatement {
            phase = .awaiting
            await pause(V8Tempo.statementHold)
            guard !Task.isCancelled else { return }
            onAdvance(.none)
        } else {
            await pause(V8Tempo.optionsDelay)
            guard !Task.isCancelled else { return }
            phase = .awaiting
            withAnimation(V8Tempo.inputArrive) { inputShown = true }
        }
    }

    /// Types a run of messages, honoring skips, reduce-motion and the
    /// punctuation clock. Trims transcript history as it goes.
    @MainActor
    private func type(lines: [V8Line]) async {
        for (idx, line) in lines.enumerated() {
            if idx > 0 { await pause(V8Tempo.interLine) }
            guard !Task.isCancelled else { return }

            let id = nextMsgID
            nextMsgID += 1
            withAnimation(V8Tempo.advance) {
                messages.append(V8Msg(id: id, line: line, revealed: reduceMotion ? .max : 0))
                trimHistory()
            }

            guard !reduceMotion else {
                await pause(0.30)
                continue
            }

            let chars = Array(line.text)
            var i = 0
            var lastTick = Date.distantPast
            while i < chars.count {
                guard !Task.isCancelled else { return }
                if skipRequested {
                    skipRequested = false
                    setRevealed(.max, for: id)
                    break
                }
                i += 1
                setRevealed(i, for: id)
                // The ink arrives with a pulse you can feel: a whisper
                // per word, a firmer beat at sentence ends (founder:
                // haptics when text appears — premium, never noisy).
                let c = chars[i - 1]
                let now = Date()
                if c == "." || c == "!" || c == "?" {
                    JeniHaptic.land()
                    lastTick = now
                } else if c == " ", now.timeIntervalSince(lastTick) > 0.09 {
                    JeniHaptic.tick()
                    lastTick = now
                }
                try? await Task.sleep(nanoseconds: UInt64(V8TypeClock.delay(after: i - 1, in: line.text) * 1_000_000_000))
            }
            setRevealed(.max, for: id)
        }
    }

    private func setRevealed(_ n: Int, for id: Int) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].revealed = n
    }

    /// The ladder holds at most three visible lines; older leave.
    private func trimHistory() {
        while messages.count > 3 {
            messages.removeFirst()
        }
    }

    @MainActor
    private func pause(_ seconds: Double) async {
        let step: Double = 0.05
        var elapsed: Double = 0
        while elapsed < seconds {
            if skipRequested { skipRequested = false; return }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
            elapsed += step
        }
    }

    // MARK: answering

    private func answer(_ payload: V8AnswerPayload, from beatID: String? = nil) {
        guard phase == .awaiting else { return }
        // Reject answers from a beat that is no longer on stage.
        if let beatID, beatID != activeBeatID { return }
        // The payload's SHAPE must match the input's — a text beat can
        // only be answered by text, a grid only by a choice. Stale or
        // replayed events with the wrong shape die here (the probe
        // caught a non-text payload reaching the code validate).
        switch (currentInput, payload) {
        case (.options, .choice), (.chips, .choice), (.quiz, .choice),
             (.weekday, .choice),
             (.multi, .set), (.ruler, .value),
             (.name, .text), (.code, .text),
             (.statement, _):
            break
        default:
            return
        }
        #if DEBUG
        let payloadCase: String
        switch payload {
        case .choice(let v): payloadCase = "choice:\(v)"
        case .set: payloadCase = "set"
        case .text(let t): payloadCase = "text:\(t.prefix(6))"
        case .value: payloadCase = "value"
        case .none: payloadCase = "none"
        }
        let entry = "\(activeBeatID)<-\(payloadCase)<-from:\(beatID ?? "nil")"
        let prior = UserDefaults.standard.string(forKey: "onb_v8_last_answer") ?? ""
        UserDefaults.standard.set(prior.isEmpty ? entry : prior + " | " + entry,
                                  forKey: "onb_v8_last_answer")
        #endif
        phase = .acking

        ackTask?.cancel()
        let payloadBox = V8PayloadBox(payload)
        ackTask = Task { @MainActor in
            let payload = payloadBox.value
            // Async gate first (the clinician code): a retry types its
            // reason and re-opens the SAME input — the conversation
            // absorbs the error, no alert ever.
            // Validators live in a STATIC registry, resolved fresh at
            // call time — an async closure STORED on the beat struct
            // arrives corrupted (nil, or garbage parameters) through
            // SwiftUI's value plumbing on the iOS 26.2 sim toolchain.
            if let validate = V8Script.validator(for: beat.id) {
                withAnimation(V8Tempo.inputDissolve) { inputShown = false }
                var answerText = ""
                if case .text(let t) = payload { answerText = t }
                let verdict = await validate(store, answerText)
                guard !Task.isCancelled else { return }
                if case .retry(let lines) = verdict {
                    await type(lines: lines)
                    guard !Task.isCancelled else { return }
                    phase = .awaiting
                    withAnimation(V8Tempo.inputArrive) { inputShown = true }
                    return
                }
            }
            beat.commit(store, payload)
            await pause(V8Tempo.selectedHold)
            withAnimation(V8Tempo.inputDissolve) { inputShown = false }

            // Ask-mode answers close their paragraph (the reference's
            // grammar: the grid clears; the ack begins fresh). Talk
            // answers keep the page — the name dims above its ack.
            if currentInput.risesToTop {
                await pause(0.16)
                withAnimation(.easeOut(duration: 0.22)) { messages.removeAll() }
                // Let the dissolving options clear the stage before the
                // ack's ink arrives (loop-3: brief type-over-ghosts).
                await pause(0.30)
            } else if case .text(let name) = payload, !name.isEmpty {
                let id = nextMsgID
                nextMsgID += 1
                withAnimation(V8Tempo.advance) {
                    messages.append(V8Msg(id: id, line: V8Line(name, user: true), revealed: .max))
                    trimHistory()
                }
            }

            await pause(V8Tempo.ackDelay)
            let ackLines = beat.ack(store, payload)
            if !ackLines.isEmpty {
                JeniHaptic.land()
                await type(lines: ackLines)
                await pause(V8Tempo.statementHold * 0.8)
            }
            guard !Task.isCancelled else { return }
            onAdvance(payload)
        }
    }

    private func tapped() {
        switch phase {
        case .typing, .acking:
            skipRequested = true
        case .awaiting:
            if currentInput.isStatement { skipRequested = true }
        }
    }

    // MARK: the input column

    @ViewBuilder
    private func inputColumn(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let caption = beat.caption?(store) {
                Text(caption)
                    .font(V8Type.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.bottom, 14)
            }

            // Natural height: the column starts at the top in ask mode,
            // so standard inputs always fit. (XXL overflow is a known
            // follow-up; the mask only ever fades the TOP.)
            inputBody
                .padding(.bottom, Space.md)
        }
        .padding(.top, asking ? 20 : 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var inputBody: some View {
        switch currentInput {
        case .options(let opts):
            V8OptionsList(options: opts, selected: selected.first) { id in
                Haptics.tick()
                selected = [id]
                answer(.choice(id), from: beat.id)
            }

        case .chips(let opts):
            V8ChipsGrid(options: opts, selected: selected.first) { id in
                Haptics.tick()
                selected = [id]
                answer(.choice(id), from: beat.id)
            }

        case .quiz(let items):
            V8QuizGrid(items: items, selected: selected.first) { id in
                Haptics.tick()
                selected = [id]
                answer(.choice(id), from: beat.id)
            }

        case .multi(let opts, _, _, _):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(opts) { opt in
                    V8MultiRow(
                        option: opt,
                        isOn: selected.contains(opt.id),
                        strikes: beat.strikes
                    ) {
                        Haptics.tick()
                        if selected.contains(opt.id) { selected.remove(opt.id) }
                        else { selected.insert(opt.id) }
                    }
                }
            }

        case .name(let placeholder, let skip):
            VStack(alignment: .leading, spacing: 6) {
                V8NameEntry(text: $nameText, placeholder: placeholder) {
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    answer(.text(trimmed), from: beat.id)
                }
                V8SkipLink(label: skip) { answer(.text(""), from: beat.id) }
            }

        case .code(let placeholder, let skip):
            VStack(alignment: .leading, spacing: 6) {
                V8CodeEntry(text: $nameText, placeholder: placeholder) {
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    answer(.text(trimmed), from: beat.id)
                }
                V8SkipLink(label: skip) { answer(.text(""), from: beat.id) }
            }

        case .ruler(let spec):
            V8RulerInput(
                spec: spec,
                value: $rulerValue,
                unit: $rulerUnit,
                onContinue: {}
            )
            .padding(.top, Space.md)

        case .weekday(let skip):
            VStack(alignment: .leading, spacing: 0) {
                V8WeekdayList(selected: selected.first) { day in
                    Haptics.tick()
                    selected = [day]
                    answer(.choice(day), from: beat.id)
                }
                V8SkipLink(label: skip) { answer(.choice(""), from: beat.id) }
                    .frame(maxWidth: .infinity)
            }

        case .statement:
            EmptyView()
        }
    }
}
