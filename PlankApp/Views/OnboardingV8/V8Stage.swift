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
    @State private var activeBottom: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let anchorY = anchor(in: geo.size.height)
            ZStack(alignment: .topLeading) {
                V8Transcript(
                    messages: displayMessages,
                    anchorY: anchorY,
                    onActiveFrame: { bottom in activeBottom = bottom }
                )
                .padding(.horizontal, Space.gutter)

                // The input arrives under the active line.
                if inputShown {
                    inputColumn(anchorY: anchorY, height: geo.size.height)
                        .transition(.opacity.combined(with: .offset(y: JeniMotion.rise)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    // MARK: the beat lifecycle

    @MainActor
    private func runBeat() async {
        // Reset per-beat state.
        skipRequested = false
        selected = beat.preselected(store)
        nameText = ""
        if case .ruler(let spec) = currentInput {
            rulerValue = spec.initial
            rulerUnit = spec.initialUnit
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
            while i < chars.count {
                guard !Task.isCancelled else { return }
                if skipRequested {
                    skipRequested = false
                    setRevealed(.max, for: id)
                    break
                }
                i += 1
                setRevealed(i, for: id)
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

    private func answer(_ payload: V8AnswerPayload) {
        guard phase == .awaiting else { return }
        phase = .acking
        beat.commit(store, payload)

        Task { @MainActor in
            await pause(V8Tempo.selectedHold)
            withAnimation(V8Tempo.inputDissolve) { inputShown = false }

            // Ask-mode answers close their paragraph (the reference's
            // grammar: the grid clears; the ack begins fresh). Talk
            // answers keep the page — the name dims above its ack.
            if currentInput.risesToTop {
                await pause(0.16)
                withAnimation(.easeOut(duration: 0.22)) { messages.removeAll() }
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
    private func inputColumn(anchorY: CGFloat, height: CGFloat) -> some View {
        let top = activeBottom + (asking ? 26 : 18)
        VStack(alignment: .leading, spacing: 0) {
            if let caption = beat.caption?(store) {
                Text(caption)
                    .font(V8Type.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.bottom, 14)
            }

            ScrollView(showsIndicators: false) {
                inputBody
                    .padding(.bottom, Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, top)
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .topLeading)
    }

    @ViewBuilder
    private var inputBody: some View {
        switch currentInput {
        case .options(let opts):
            V8OptionsList(options: opts, selected: selected.first) { id in
                Haptics.tick()
                selected = [id]
                answer(.choice(id))
            }

        case .chips(let opts):
            V8ChipsGrid(options: opts, selected: selected.first) { id in
                Haptics.tick()
                selected = [id]
                answer(.choice(id))
            }

        case .multi(let opts, let minCount, let cta, let skip):
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
                Color.clear.frame(height: Space.md)
                JeniPrimaryButton(cta) {
                    guard selected.count >= minCount else { return }
                    answer(.set(selected))
                }
                .opacity(selected.count >= minCount ? 1 : 0.35)
                if let skip {
                    V8SkipLink(label: skip) { answer(.set([])) }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
            }

        case .name(let placeholder, let skip):
            VStack(alignment: .leading, spacing: 6) {
                V8NameEntry(text: $nameText, placeholder: placeholder) {
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    answer(.text(trimmed))
                }
                V8SkipLink(label: skip) { answer(.text("")) }
            }

        case .ruler(let spec):
            VStack(spacing: 0) {
                V8RulerInput(
                    spec: spec,
                    value: $rulerValue,
                    unit: $rulerUnit,
                    onContinue: {}
                )
                Color.clear.frame(height: Space.lg)
                JeniPrimaryButton(spec.cta) {
                    answer(.value(rulerValue, unit: rulerUnit))
                }
            }

        case .weekday(let skip):
            VStack(alignment: .leading, spacing: 0) {
                V8WeekdayList(selected: selected.first) { day in
                    Haptics.tick()
                    selected = [day]
                    answer(.choice(day))
                }
                V8SkipLink(label: skip) { answer(.choice("")) }
                    .frame(maxWidth: .infinity)
            }

        case .statement:
            EmptyView()
        }
    }
}
