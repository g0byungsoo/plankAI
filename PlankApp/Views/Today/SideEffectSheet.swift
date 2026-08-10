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

                VStack(spacing: 0) {
                    ForEach(SideEffectSymptom.allCases) { symptom in
                        symptomLine(symptom)
                    }
                }
                .padding(.top, Space.lg)

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
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.bgPrimary)
        .onAppear(perform: load)
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

    @ViewBuilder
    private func symptomLine(_ symptom: SideEffectSymptom) -> some View {
        let severity = recorded[symptom]
        VStack(spacing: 0) {
            Button {
                JeniHaptic.tick()
                if severity != nil {
                    // Tapping a recorded word clears it.
                    SideEffectLog.remove(symptom, userId: userId, in: modelContext)
                    recorded[symptom] = nil
                    if expanded == symptom { expanded = nil }
                } else {
                    expanded = expanded == symptom ? nil : symptom
                    note = ""
                }
            } label: {
                HStack {
                    Text(symptom.word)
                        .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    if let severity {
                        Text(severity.word)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                }
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityLabel(
                severity.map { "\(symptom.word), \($0.word). double-tap to clear." }
                    ?? "\(symptom.word). double-tap to record."
            )

            if expanded == symptom, severity == nil {
                severityRow(symptom)
                    .padding(.bottom, 10)
            }

            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func severityRow(_ symptom: SideEffectSymptom) -> some View {
        HStack(spacing: 10) {
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
