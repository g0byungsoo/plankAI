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

struct SideEffectSheet: View {
    let userId: String
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var recorded: [SideEffectSymptom: SideEffectSeverity] = [:]
    @State private var expanded: SideEffectSymptom?
    @State private var note: String = ""

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("how it's sitting")
                    .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, Space.xl)

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
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.bgPrimary)
        .onAppear {
            load()
            #if DEBUG
            // v25 E2 film door — the mood chip's support-first card.
            if ProcessInfo.processInfo.arguments
                .contains("--uitest-expand-mood") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(JeniMotion.settle) { expanded = .lowMood }
                }
            }
            #endif
        }
        }
    }

    private func load() {
        let today = TodayStateService.dayKey()
        var map: [SideEffectSymptom: SideEffectSeverity] = [:]
        for entry in SideEffectLog.entries(userId: userId, limit: 30, in: modelContext)
        where entry.dayKey == today {
            map[entry.symptom] = entry.severity
        }
        recorded = map
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
                SideEffectLog.remove(symptom, userId: userId, in: modelContext)
                recorded[symptom] = nil
                if expanded == symptom { expanded = nil }
            } else {
                expanded = expanded == symptom ? nil : symptom
                note = ""
            }
        } label: {
            HStack(spacing: 5) {
                Text(symptom.word)
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(isAsking ? Palette.textInverse : Palette.textPrimary)
                if let severity {
                    Text("· \(severity.word)")
                        .font(.custom("DMSans-Regular", size: 13, relativeTo: .caption))
                        .foregroundStyle(Palette.cocoaSecondary)
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
                    JeniHaptic.land()
                    SideEffectLog.record(
                        symptom, severity: severity,
                        note: note.isEmpty ? nil : note,
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
