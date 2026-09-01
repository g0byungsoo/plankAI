import SwiftUI
import SwiftData
import PlankSync

// MARK: - SideEffectSheet (app v24 THE REGIMEN)
//
// The lightweight logger: gentle words, three severities, one tap
// each. Not medical, not scary — no sliders, no 0–10, no red.
// Tap a word → three severity words appear → tap one → recorded
// (pen tick). Tap a recorded word again → cleared. An optional
// note per entry, in her words. The pattern engine reads these;
// the care packet's symptom section already speaks timing-only.
//
// v25 §36 — THE DAY IT IS WRITING TO.
//
// `SideEffectLog.record` and `.remove` have taken a `dayKey` since v24.
// **This sheet was the only thing pinning it to today** — `load()`
// filtered `entry.dayKey == today` and both mutations took the default
// argument. So a symptom remembered the next morning had nowhere to go
// and one recorded on the wrong day could not be moved, in the one
// record that reaches a clinician.
//
// The fix is the interaction both GLP-1 references already ship (MeAgain
// puts a `Date` row at the top of its side-effect log; Shotsy promotes
// "tap to edit shot details" to its widget) and the one this product
// already ships one domain over: the plate's `the day`, expanding in
// place, fourteen days back, never forward.
//
// The day row is the FIRST thing on the sheet, above the title, because
// every tap below it writes to that day and a person who arrived here
// from a three-week-old row must never think she is recording today.

struct SideEffectSheet: View {
    let userId: String
    /// The day this sheet reads and writes. `nil` means today, which
    /// keeps every pre-v25-§36 call site byte-identical.
    var initialDayKey: String? = nil
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var recorded: [SideEffectSymptom: SideEffectSeverity] = [:]
    @State private var expanded: SideEffectSymptom?
    @State private var note: String = ""
    @State private var dayKey: String = ""
    @State private var pickingDay = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                theDay

                Text("how it's sitting")
                    .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, pickingDay ? Space.md : 6)

                Text("a quiet record for you and your next visit. nothing here grades you.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                // v25 E7 (founder steer 2026-08-11): "these options
                // better to be pill options so we can save space +
                // make it signal that its clickable."
                //
                // Thirteen full-width rows separated by hairlines read
                // as a settings table — a list of statements, not a
                // set of choices — and cost ~590pt of a sheet that
                // still had a severity picker, a note field and a
                // primary action to fit. As a wrapped cloud the same
                // thirteen words take four lines, and a capsule is the
                // one shape in this system that always means "tap me".
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(SideEffectSymptom.allCases) { symptom in
                        symptomPill(symptom)
                    }
                }
                .padding(.top, Space.lg)
                .id("cloud")

                // The picker follows the cloud instead of splitting it.
                // Inline expansion inside a wrapping layout would have
                // reflowed every pill after the open one — the words
                // would move under her thumb as she read them.
                if let symptom = expanded, recorded[symptom] == nil {
                    detailPanel(symptom)
                        .padding(.top, Space.md)
                        .id("detail")
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -6)),
                            removal: .opacity
                        ))
                }

                Button {
                    Haptics.soft()
                    onDone()
                } label: {
                    Text("done")
                        .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                                .fill(Palette.textPrimary)
                        )
                }
                .buttonStyle(JKPress())
                .padding(.top, Space.lg)

                Text("only you see this. shared with a clinic only through the care loop you approve.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.lg)
                    .padding(.bottom, Space.xl)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
            .animation(JeniMotion.settle, value: expanded)
            // v25 E2 — an opened picker near the sheet's fold stays
            // visible (frame-caught: the mood card opened below the
            // detent and never showed). It now follows the cloud
            // rather than splitting it, so the target is the panel.
            .onChange(of: expanded) { _, symptom in
                guard symptom != nil else { return }
                withAnimation(JeniMotion.settle) {
                    proxy.scrollTo("detail", anchor: .bottom)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.bgPrimary)
        .onAppear {
            if dayKey.isEmpty { dayKey = initialDayKey ?? TodayStateService.dayKey() }
            load()
            #if DEBUG
            // v25 E2 film door — the mood chip's support-first card.
            if ProcessInfo.processInfo.arguments
                .contains("--uitest-expand-mood") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(JeniMotion.settle) { expanded = .lowMood }
                }
            }
            // v25 §36 film door — the day picker, open. simctl cannot
            // tap, and an affordance nobody has filmed open is an
            // affordance nobody has looked at (`30` §12.1).
            if ProcessInfo.processInfo.arguments
                .contains("--debug-symptom-day") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(JeniMotion.settle) { pickingDay = true }
                }
            }
            #endif
        }
        }
    }

    // MARK: - the day (v25 §36)
    //
    // Borrowed back from `PlateDetailSheet`, which borrowed this sheet's
    // own expand-in-place panel in `34`. No new vocabulary and no new
    // geometry: the same row, the same fourteen days, the same refusal
    // of a future day — a symptom cannot have happened tomorrow.

    @ViewBuilder private var theDay: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Button {
                Haptics.light()
                withAnimation(JeniMotion.settle) { pickingDay.toggle() }
            } label: {
                // AX5, caught by filming this row and not by reading it:
                // `the day` beside `yesterday` wrapped to `the` / `day`
                // — a word breaking inside itself, which is `33`'s
                // `medica/tion ozem/pic` law happening to my own new
                // row. The rule is the one every other label/value pair
                // in this product uses: from xxxLarge up, a row becomes
                // a column.
                let label = Text("the day")
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                let value = Text(pickingDay ? "which day?" : SymptomLedger.dayWord(
                    dayKey, now: .now, calendar: .current
                ))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                Group {
                    if stacksForType {
                        VStack(alignment: .leading, spacing: 2) {
                            label.fixedSize(horizontal: false, vertical: true)
                            value.fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            label
                            Spacer(minLength: Space.md)
                            value
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, Space.lg)
            .accessibilityLabel(
                "recording for \(SymptomLedger.dayWord(dayKey, now: .now, calendar: .current)). double-tap to choose another day."
            )

            if pickingDay {
                VStack(spacing: 0) {
                    ForEach(SymptomLedger.dayOptions(), id: \.self) { day in
                        let key = TodayStateService.dayKey(for: day)
                        let isCurrent = key == dayKey
                        Button {
                            Haptics.soft()
                            withAnimation(JeniMotion.settle) {
                                pickingDay = false
                                if !isCurrent {
                                    dayKey = key
                                    expanded = nil
                                    note = ""
                                }
                            }
                            load()
                        } label: {
                            HStack {
                                Text(SymptomLedger.dayWord(
                                    key, now: .now, calendar: .current
                                ))
                                .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                                .foregroundStyle(
                                    isCurrent ? Palette.cocoaTertiary : Palette.textPrimary
                                )
                                Spacer(minLength: Space.md)
                                if isCurrent {
                                    Text("the one you're on")
                                        .font(Typo.caption)
                                        .foregroundStyle(Palette.cocoaTertiary)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(JKPress())
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    /// The rule `HomeNutritionSummary.stacksForType` has used since E9
    /// and `33` applied to the regimen home: from xxxLarge up, a row
    /// becomes a column.
    private var stacksForType: Bool {
        typeSize.isAccessibilitySize || typeSize >= .xxxLarge
    }

    private func load() {
        recorded = SideEffectLog.recorded(
            on: dayKey.isEmpty ? TodayStateService.dayKey() : dayKey,
            userId: userId, in: modelContext
        )
    }

    // MARK: - One pill
    //
    // Three states, three fills, no icons:
    //   at rest    paper + cocoa hairline
    //   asking     ink fill (this is the live question)
    //   recorded   blush fill, and the pill carries its own severity
    //              so the record is legible without a second column
    //
    // Tapping a recorded pill still clears it — the v24 gesture
    // survives the shape change.
    @ViewBuilder
    private func symptomPill(_ symptom: SideEffectSymptom) -> some View {
        let severity = recorded[symptom]
        let isAsking = expanded == symptom && severity == nil

        Button {
            JeniHaptic.tick()
            if severity != nil {
                SideEffectLog.remove(
                    symptom, dayKey: dayKey, userId: userId, in: modelContext
                )
                recorded[symptom] = nil
                if expanded == symptom { expanded = nil }
            } else {
                expanded = expanded == symptom ? nil : symptom
                note = ""
            }
        } label: {
            // AX5 — a recorded pill is TWO strings, and at accessibility
            // sizes `queasy · noticeable` ran off the right edge of the
            // screen: `FlowLayout` places a capsule at its ideal width,
            // and the ideal width of two long strings on one line
            // exceeds the device. Pre-existing since E7 gave these pills
            // their severity suffix, and never filmed at AX5 because
            // this sheet had no film door of its own until now.
            //
            // Same rule as everywhere else: from xxxLarge the pair
            // stacks, so the capsule grows DOWN instead of sideways.
            let word = Text(symptom.word)
                .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(isAsking ? Palette.textInverse : Palette.textPrimary)
            let suffix = severity.map {
                Text(stacksForType ? $0.word : "· \($0.word)")
                    .font(.custom("DMSans-Regular", size: 13, relativeTo: .caption))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            Group {
                if stacksForType {
                    VStack(alignment: .leading, spacing: 2) {
                        word.fixedSize(horizontal: false, vertical: true)
                        suffix?.fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(spacing: 5) {
                        word
                        suffix
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(
                    isAsking ? Palette.textPrimary
                    : severity != nil ? Palette.roseBlush.opacity(0.55)
                    : Color.clear
                )
            )
            .overlay(
                Capsule().stroke(
                    isAsking || severity != nil ? Color.clear : Palette.hairlineCocoa,
                    lineWidth: 1
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(
            severity.map { "\(symptom.word), \($0.word). double-tap to clear." }
                ?? "\(symptom.word). double-tap to record."
        )
    }

    // MARK: - The detail panel

    @ViewBuilder
    private func detailPanel(_ symptom: SideEffectSymptom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // v25 E2 (E2-D5) — the mood chip leads with SUPPORT,
            // before anything is recorded: crisis resources first,
            // clinician second, the record third — and recording is
            // never blocked.
            if symptom.routesToSupportFirst {
                moodSupportCard
            }
            Text("how much?")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
            severityRow(symptom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moodSupportCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("if the low is heavy right now: call or text 988. someone is there around the clock. findahelpline.com finds support anywhere.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("worth telling your clinician too. mood shifts on medication are theirs to know about.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.hairlineCocoa, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func severityRow(_ symptom: SideEffectSymptom) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(SideEffectSeverity.allCases) { severity in
                Button {
                    // p62 — a symptom entering the record speaks the
                    // record hand, same as a dose, a weight, a plate.
                    JeniHaptic.record()
                    SideEffectLog.record(
                        symptom, severity: severity,
                        note: note.isEmpty ? nil : note,
                        dayKey: dayKey,
                        userId: userId, in: modelContext
                    )
                    recorded[symptom] = severity
                    expanded = nil
                    note = ""
                } label: {
                    Text(severity.word)
                        .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(
                                Palette.textPrimary.opacity(0.25), lineWidth: 0.5
                            )
                        )
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("\(symptom.word), \(severity.word)")
            }
        }

        TextField("a word about it, if you want", text: $note)
            .font(Typo.caption)
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, 8)
    }
}
