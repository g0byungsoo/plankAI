import SwiftUI
import SwiftData
import PlankSync

// MARK: - CorrectionSheet (app v8 S4 — FR2 / §8)
//
// The patient reports that a care-team medication record looks wrong.
// 164.526-shaped: the request files an auditable ask; it NEVER
// mutates the plan. Bounded categories + one optional short note
// (sensitive; stored on the request row only). Clinical register,
// and explicitly not an urgent channel.

struct CorrectionSheet: View {
    let userId: String
    let plan: RegimenPlanRecord
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var category: CorrectionCategory?
    @State private var note = ""
    @State private var sending = false
    @State private var sent = false
    @State private var errorLine: String?

    private var orgId: String? { plan.orgId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sent {
                sentFace
            } else {
                formFace
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        // Pass 57 (D7) — a fixed VStack holding a text field clipped
        // under the keyboard at accessibility sizes; the scroll law
        // keeps the form and its send reachable.
        .modifier(JeniScrollingSheetBody())
        .background(Palette.bgPrimary)
    }

    @ViewBuilder
    private var formFace: some View {
        Text("report a problem")
            .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)

        Text("your care team reviews this. it doesn't change your plan on its own, and it isn't a way to reach anyone urgently. for that, call your clinic.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)

        VStack(spacing: 0) {
            ForEach(CorrectionCategory.allCases) { cat in
                categoryLine(cat)
            }
        }
        .padding(.top, Space.lg)

        if category == .other {
            VStack(alignment: .leading, spacing: 6) {
                Text("what's off? (optional)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                TextField("", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Palette.hairlineCocoa, lineWidth: 0.5))
                    .onChange(of: note) { _, v in if v.count > 200 { note = String(v.prefix(200)) } }
            }
            .padding(.top, Space.md)
        }

        if let errorLine {
            Text(errorLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.stateBad)
                .padding(.top, Space.md)
        }

        Button {
            send()
        } label: {
            HStack {
                if sending { ProgressView().tint(Palette.textInverse) }
                Text("send to my care team")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textInverse)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(category == nil ? Palette.cocoaTertiary : Palette.cocoaPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(category == nil || sending)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
    }

    @ViewBuilder
    private var sentFace: some View {
        Spacer().frame(height: Space.xl)
        Text("sent to your care team")
            .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)
        Text("they'll review it and update your plan if it needs a change. your plan is unchanged until then.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
        Button {
            onDone()
        } label: {
            Text("done")
                .font(Typo.heading)
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Palette.cocoaPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, Space.xl)
        Spacer()
    }

    private func categoryLine(_ cat: CorrectionCategory) -> some View {
        Button {
            withAnimation(Motion.tap) { category = cat }
            Haptics.soft()
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Text(cat.label)
                        .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(category == cat ? Palette.textPrimary : Palette.textPrimary.opacity(0.5))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    if category == cat {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                }
                .padding(.vertical, 11)
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(cat.label)
        .accessibilityAddTraits(category == cat ? [.isButton, .isSelected] : .isButton)
    }

    private func send() {
        guard let category, let orgId else {
            errorLine = "couldn't find your clinic connection."
            return
        }
        sending = true
        errorLine = nil
        let planId = plan.id
        let noteToSend = category == .other && !note.trimmingCharacters(in: .whitespaces).isEmpty ? note : nil
        Task {
            do {
                try await CareConnectionService.submitCorrection(
                    orgId: orgId, regimenPlanId: planId, category: category, note: noteToSend
                )
                await MainActor.run {
                    sending = false
                    withAnimation(Motion.entranceSoft) { sent = true }
                    Haptics.soft()
                }
            } catch {
                await MainActor.run {
                    sending = false
                    errorLine = "couldn't send just now. try again in a moment."
                }
            }
        }
    }
}
