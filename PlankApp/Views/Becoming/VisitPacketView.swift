import SwiftUI
import SwiftData
import UIKit

// MARK: - VisitPacketView (app v8 S3 — docs/app_v8/09_S3_PACKET.md)
//
// The visit-prep packet, rendered in the CLINICAL register: quiet
// typography, hairline separators, plain counts, provenance
// captions, zero ornament. Facts she entered and summaries the
// system computed stay visually distinct (summaries carry the
// "from your records" caption grammar; her questions carry edit
// affordances). Nothing here celebrates; nothing here diagnoses.

struct VisitPacketView: View {
    let userId: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var packet: VisitPacket?
    @State private var editingQuestionId: String?
    @State private var draftText = ""
    @State private var newQuestion = ""
    @State private var consentActive = false
    @State private var showConsentSheet = false
    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let packet {
                    header(packet)
                    if packet.isEmpty {
                        emptyBody(packet)
                    } else {
                        if let regimen = packet.regimen { medicationSection(regimen) }
                        if let weight = packet.weight { weightSection(weight) }
                        if !packet.symptoms.isEmpty { symptomSection(packet.symptoms) }
                        if let nutrition = packet.nutrition { nutritionSection(nutrition) }
                        if let movement = packet.movement { movementSection(movement) }
                    }
                    questionSection(packet)
                    if !packet.gaps.isEmpty { gapsSection(packet.gaps) }
                    consentSection
                    footer
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 40)
        }
        // p62's one masthead-scrim law — the densest record page
        // scrolled its section serif through the status-bar clock.
        .jeniMastheadScrim()
        // p67 — the page's actual job (hand this to your clinician)
        // was an underlined caption in the header. It is the standing
        // CTA now, pinned in the thumb zone.
        .safeAreaInset(edge: .bottom) {
            if let packet, !packet.isEmpty {
                JFContinueButton(
                    label: "share as pdf",
                    action: { exportPDF(packet) }
                )
                .padding(.top, Space.sm)
                .background {
                    Palette.bgPrimary
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 22)
                            .offset(y: -22)
                        }
                        .ignoresSafeArea()
                }
                .accessibilityLabel("share the packet as a pdf")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bgPrimary)
        .onAppear { refresh() }
        // p68 — brief: one consent question; 0.68 left a third of the
        // sheet as dead paper beneath the capsule.
        .jeniSheet(isPresented: $showConsentSheet, detents: JeniSheetHeight.brief) { consentSheet }
        .sheet(item: $shareURL) { url in
            ActivityShareSheet(url: url)
        }
    }

    private func refresh() {
        packet = VisitPacketBuilder.build(userId: userId, in: modelContext)
        consentActive = ConsentService.isActive(
            scope: ConsentService.visitPacketScope, userId: userId, in: modelContext
        )
    }

    // MARK: header

    @ViewBuilder
    private func header(_ packet: VisitPacket) -> some View {
        // Pass 57 — the packet is a PAGE (cover) now, and a page names
        // its exit. As a sheet it had no close control at all: the only
        // way out was a grabber-less drag nobody could see.
        HStack(alignment: .top) {
            Text("FOR YOUR NEXT VISIT")
                .font(Typo.caption)
                .kerning(1.6)
                .foregroundStyle(Palette.cocoaTertiary)
            Spacer(minLength: Space.md)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.textPrimary.opacity(0.05)))
                    // p63 — 34pt visible, HIG-floor target (the same
                    // X was copy-pasted under-target on four sheets).
                    .tappableArea()
            }
            .buttonStyle(JeniPressable())
            .accessibilityIdentifier("packet.close")
            .accessibilityLabel("done. closes your visit record")
        }
        .padding(.top, Space.xl)
        Text("your record,\n\(packet.window.label).")
            .font(.custom("JeniHeroSerif-Regular", size: 34, relativeTo: .largeTitle))
            .foregroundStyle(Palette.textPrimary)
            .lineSpacing(-2)
            .padding(.top, 6)
        Text("the last four weeks · from your records")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func emptyBody(_ packet: VisitPacket) -> some View {
        sectionRule("this period")
        Text("not much was recorded these four weeks. the packet fills itself from weigh-ins, dose marks, sit-checks, and plates as they happen.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
            .padding(.vertical, 10)
    }

    // MARK: sections (ledger grammar)

    private func sectionRule(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
            Text(title.uppercased())
                .font(Typo.caption)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 12)
        }
        .padding(.top, 18)
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
            Spacer(minLength: 16)
            Text(value)
                .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func medicationSection(_ regimen: VisitPacket.Regimen) -> some View {
        sectionRule("medication")
        factRow(regimen.authorityLabel, regimen.displayLine)
        if let day = regimen.anchorWeekdayWord {
            factRow("schedule", "weekly · \(day)s")
        }
        // p54 — the tenure line was SERIALIZED to the clinic and
        // rendered to her nowhere: a clinician could read "month 4 of
        // treatment, by her account" while she could neither see nor
        // correct the claim. She sees what they see.
        if let tenure = regimen.tenureLine {
            factRow("tenure", tenure)
        }
        if regimen.scheduledCount > 0 {
            factRow("marked taken", "\(regimen.takenCount) of \(regimen.scheduledCount) scheduled days")
            if regimen.skippedCount > 0 {
                factRow("marked skipped", "\(regimen.skippedCount)")
            }
            if regimen.unrecordedCount > 0 {
                factRow("unrecorded", "\(regimen.unrecordedCount)")
            }
        }
    }

    @ViewBuilder
    private func weightSection(_ weight: VisitPacket.Weight) -> some View {
        sectionRule("weight")
        factRow("weigh-ins", "\(weight.entryCount) this period")
        if let first = weight.firstKg, let latest = weight.latestKg, weight.entryCount >= 2 {
            let unit = WeightUnit.current
            factRow(
                "first · latest",
                "\(unit.display(fromKg: first).formatted()) · \(unit.display(fromKg: latest).formatted()) \(unit.label)"
            )
        }
        if let direction = weight.directionWord {
            // p54 — the one computed word in a section of recorded
            // facts says so: inference must not sit typographically
            // identical to record.
            factRow("trend", "\(direction) · computed from her weigh-ins")
        } else {
            Text("not enough entries to describe a pattern.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func symptomSection(_ symptoms: [VisitPacket.Symptom]) -> some View {
        sectionRule("how days sat")
        ForEach(symptoms, id: \.word) { symptom in
            factRow(symptom.word, "\(symptom.count) evening\(symptom.count == 1 ? "" : "s")")
            if let note = symptom.timingNote {
                Text(note)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private func nutritionSection(_ nutrition: VisitPacket.Nutrition) -> some View {
        sectionRule("protein")
        factRow(
            "reached \(nutrition.targetG)g",
            "\(nutrition.proteinDaysMet) of \(nutrition.loggedDays) logged days"
        )
    }

    @ViewBuilder
    private func movementSection(_ movement: VisitPacket.Movement) -> some View {
        sectionRule("movement")
        if movement.movedDays > 0 {
            factRow("sessions kept", "\(movement.movedDays) this period")
        }
        if let avg = movement.stepsWeekAvg {
            factRow("steps, past week", avg.formatted())
        }
        // p54 — the one figure a follow-up actually uses (the 2-3/week
        // strength floor) was serialized to the clinic and rendered to
        // her nowhere. Same law as the tenure line: she sees what they
        // see.
        if let strength = movement.strengthSessions7 {
            // p55 — provenance on the clinical surface: a session she
            // typed and a session a sensor measured must never read
            // alike where a decision is made (MoveRecord's own law).
            let hand = movement.strengthRecordedByHand7
            let word = "\(strength) session\(strength == 1 ? "" : "s")"
            factRow(
                "strength, past week",
                hand > 0 ? "\(word) · \(hand) recorded by her" : word
            )
        }
    }

    // MARK: questions (hers to edit)

    @ViewBuilder
    private func questionSection(_ packet: VisitPacket) -> some View {
        sectionRule("questions for the visit")
        ForEach(packet.questions) { question in
            VStack(alignment: .leading, spacing: 4) {
                if editingQuestionId == question.id {
                    TextField("your question", text: $draftText, axis: .vertical)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .textFieldStyle(.plain)
                        .onSubmit { commitEdit(question) }
                    HStack(spacing: 18) {
                        Button { commitEdit(question) } label: {
                            Text("save").underline().tappableArea()
                        }
                        Button { remove(question) } label: {
                            Text("remove").underline().tappableArea()
                        }
                    }
                    .buttonStyle(JKPress())
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                } else {
                    Text(question.text)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // p63 — the actions wore the LABEL's exact ink:
                    // "from your records · edit · remove" read as one
                    // caption. The clinical family's own underline
                    // (the p62-kept grammar) separates the verbs, the
                    // press answers, the targets meet the floor.
                    HStack(spacing: 18) {
                        Text(question.origin == "generated" ? "from your records" : "yours")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Button {
                            editingQuestionId = question.id
                            draftText = question.text
                        } label: {
                            Text("edit").underline().tappableArea()
                        }
                        Button { remove(question) } label: {
                            Text("remove").underline().tappableArea()
                        }
                    }
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .buttonStyle(JKPress())
                }
                Rectangle().fill(Palette.hairlineCocoa.opacity(0.6)).frame(height: 0.5)
            }
            .padding(.vertical, 8)
        }
        HStack(spacing: 12) {
            TextField("add your own question", text: $newQuestion, axis: .vertical)
                .font(Typo.body)
                .textFieldStyle(.plain)
            if !newQuestion.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("add") { addQuestion() }
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaPrimary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private func commitEdit(_ question: VisitPacket.Question) {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { remove(question); return }
        ObservationStore.record(
            .visitQuestion, valueText: text,
            payload: try? JSONSerialization.data(withJSONObject: ["origin": question.origin]),
            dayKey: TodayStateService.dayKey(), userId: userId,
            source: "manual", in: modelContext, sync: false, id: question.id
        )
        editingQuestionId = nil
        refresh()
    }

    private func remove(_ question: VisitPacket.Question) {
        ObservationStore.delete(id: question.id, in: modelContext)
        if question.origin == "generated",
           let rule = question.id.split(separator: "-").last {
            UserDefaults.standard.set(
                true, forKey: "visitq.removed.\(rule).\(userId.lowercased())"
            )
        }
        editingQuestionId = nil
        refresh()
    }

    private func addQuestion() {
        let text = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        ObservationStore.record(
            .visitQuestion, valueText: text,
            payload: try? JSONSerialization.data(withJSONObject: ["origin": "patient"]),
            dayKey: TodayStateService.dayKey(), userId: userId,
            source: "manual", in: modelContext, sync: false
        )
        newQuestion = ""
        refresh()
    }

    // MARK: gaps + consent + footer

    @ViewBuilder
    private func gapsSection(_ gaps: [String]) -> some View {
        sectionRule("not recorded")
        ForEach(gaps, id: \.self) { gap in
            Text(gap)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private var consentSection: some View {
        sectionRule("sharing")
        HStack {
            Text(consentActive
                 ? "future care-team sharing: allowed"
                 : "future care-team sharing: off")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
            Spacer()
            Button(consentActive ? "review" : "change") { showConsentSheet = true }
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaPrimary)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        Text("nothing is sent anywhere. sharing a pdf is always your own action.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
    }

    private var consentSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("care-team sharing")
                .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title))
                .padding(.top, Space.xl)
            Text("when a care team connects later, this consent lets jeni share your visit packet with them. it is off by default, scoped to the packet only, and you can turn it off anytime. no clinic is connected today; nothing is sent today.")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if consentActive {
                    ConsentService.revoke(
                        scope: ConsentService.visitPacketScope,
                        userId: userId, in: modelContext
                    )
                } else {
                    ConsentService.grant(
                        scope: ConsentService.visitPacketScope,
                        purpose: "share the visit packet with a connected care team",
                        userId: userId, in: modelContext
                    )
                }
                refresh()
                showConsentSheet = false
            } label: {
                Text(consentActive ? "turn sharing off" : "allow future sharing")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Palette.cocoaPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            Spacer()
        }
        .padding(.horizontal, Space.xl)
    }

    @ViewBuilder
    private var footer: some View {
        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
            .padding(.top, 18)
        Text(VisitPacket.disclaimerLine)
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 10)
    }

    // MARK: pdf export

    private func exportPDF(_ packet: VisitPacket) {
        let renderer = ImageRenderer(
            content: VisitPacketPrintView(packet: packet).frame(width: 612)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("visit packet \(packet.window.label).pdf")
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: 612, height: max(size.height, 792)))
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        shareURL = url
    }
}

// MARK: - Print view (the PDF's face — clinical, sticker-free)

struct VisitPacketPrintView: View {
    let packet: VisitPacket

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("visit record · \(packet.window.label)")
                // p61 — New York was a fourth typeface, on the one
                // document a patient hands a clinician. The brand
                // serif is the product's own formal register.
                .font(.custom("JeniHeroSerif-Regular", size: 20))
            Text("patient-entered facts and app-computed summaries; every line traces to a record. \(VisitPacket.disclaimerLine)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if let regimen = packet.regimen {
                printSection("medication", [
                    "\(regimen.authorityLabel): \(regimen.displayLine)",
                    regimen.anchorWeekdayWord.map { "schedule: weekly · \($0)s" },
                    regimen.tenureLine,
                    regimen.scheduledCount > 0
                        ? "marked taken on \(regimen.takenCount) of \(regimen.scheduledCount) scheduled days · skipped \(regimen.skippedCount) · unrecorded \(regimen.unrecordedCount)"
                        : nil,
                ].compactMap { $0 })
            }
            if let weight = packet.weight {
                printSection("weight", [
                    "weigh-ins: \(weight.entryCount) this period",
                    weight.directionWord.map { "trend: \($0) (computed from her weigh-ins)" }
                        ?? "not enough entries to describe a pattern",
                ])
            }
            if !packet.symptoms.isEmpty {
                printSection("how days sat (patient-recorded)", packet.symptoms.map {
                    "\($0.word): \($0.count)\($0.timingNote.map { note in " · \(note)" } ?? "")"
                })
            }
            if let nutrition = packet.nutrition {
                printSection("protein", [
                    "reached \(nutrition.targetG)g on \(nutrition.proteinDaysMet) of \(nutrition.loggedDays) logged days"
                ])
            }
            if let movement = packet.movement {
                printSection("movement", [
                    movement.movedDays > 0 ? "sessions kept: \(movement.movedDays)" : nil,
                    movement.stepsWeekAvg.map { "steps, past week: \($0.formatted())/day" },
                    movement.strengthSessions7.map {
                        movement.strengthRecordedByHand7 > 0
                            ? "strength, past week: \($0) (\(movement.strengthRecordedByHand7) patient-recorded)"
                            : "strength, past week: \($0)"
                    },
                ].compactMap { $0 })
            }
            if !packet.questions.isEmpty {
                printSection("questions for the visit (patient-edited)", packet.questions.map(\.text))
            }
            if !packet.gaps.isEmpty {
                printSection("not recorded", packet.gaps)
            }
        }
        .padding(36)
        .background(Color.white)
        .foregroundStyle(.black)
    }

    @ViewBuilder
    private func printSection(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            ForEach(lines, id: \.self) { line in
                Text(line).font(.system(size: 12))
            }
        }
    }
}

// MARK: - Share sheet

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
