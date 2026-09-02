import SwiftUI
import SwiftData

// MARK: - CareConnectionSheet (app v8 S4)
//
// The patient enters the short code her clinic handed her, sees WHO
// is asking, then chooses what to share on the consent screen. She
// controls scope and lookback; nothing is active by default; the
// not-monitored line is a consent element, not a footer. Revocation
// lives in the same surface once connected.

struct CareConnectionSheet: View {
    let userId: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var phase: Phase = .loading
    @State private var connections: [CareConnection] = []
    @State private var code = {
        #if DEBUG
        // A capture door: the code-entry screen is worth photographing
        // with a code actually in it, and typing into a simulator is
        // not a deterministic act.
        if ProcessInfo.processInfo.arguments.contains("--uitest-care-prefill-code") {
            return "JENI-DEMO"
        }
        #endif
        return ""
    }()
    @State private var preview: CareInvitationPreview?
    @State private var busy = false
    @State private var errorLine: String?

    enum Phase { case loading, list, enter, consent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .loading:
                ProgressView().tint(Palette.cocoaSecondary)
                    .frame(maxWidth: .infinity).padding(.top, 60)
            case .list: connectedList
            case .enter: enterCode
            case .consent: consentScreen
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.xl)
        .background(Palette.bgPrimary)
        .task { await reload() }
    }

    private func reload() async {
        connections = await CareConnectionService.connections()
        phase = connections.contains(where: { $0.isActive }) ? .list : .enter
    }

    // MARK: connected list (also the revocation surface)

    @ViewBuilder
    private var connectedList: some View {
        Text("your care team")
            .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)

        ForEach(connections.filter { $0.isActive }) { c in
            VStack(alignment: .leading, spacing: 8) {
                Text(c.orgName)
                    .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Text(sharingLine(c))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // p67 — a consent revocation is a real control, not
                // an underlined caption (the chip grammar, §5.2).
                Button {
                    Task { await disconnect(c) }
                } label: {
                    JeniQuietCapsule("turn off my clinic's access")
                }
                .buttonStyle(JKPress())
                .padding(.top, 6)
            }
            .padding(.vertical, Space.md)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }

        Text("turning off access is separate from your treatment. your plan and records stay; your clinic just can't see new records or make changes. for treatment questions, contact your clinic directly.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.lg)

        Button { phase = .enter } label: {
            JeniQuietCapsule("connect with another code")
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
    }

    private func sharingLine(_ c: CareConnection) -> String {
        guard !c.scopes.isEmpty else { return "connected · nothing shared yet" }
        let names = CareScope.allCases.filter { c.scopes.contains($0) }.map { $0.title }
        return "sharing: " + names.joined(separator: ", ")
    }

    // MARK: enter code

    @ViewBuilder
    private var enterCode: some View {
        // The code screen is four short elements, and left to its own
        // devices they pile against the top of a full-height sheet
        // with two-thirds of the paper empty beneath them. A single
        // leading Spacer settles the group into the upper third, where
        // the eye already is — the same optical seat the onboarding
        // beats use.
        Spacer(minLength: Space.xl)

        Text("connect with your clinic")
            .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)

        Text("enter the code your clinic gave you. you'll choose what to share next.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)

        TextField("XXXX-XXXX", text: $code)
            .font(.system(.title2, design: .monospaced))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .foregroundStyle(Palette.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Palette.hairlineCocoa, lineWidth: 0.5))
            .padding(.top, Space.lg)

        if let errorLine {
            Text(errorLine)
                .font(Typo.caption).foregroundStyle(Palette.stateBad)
                .padding(.top, Space.md)
        }

        // p67 — the standing CTA (the hand-rolled capsule was
        // press-dead `.plain`, the §5.1 first-find).
        JFContinueButton(
            label: "continue",
            action: { Task { await lookUp() } },
            isEnabled: code.count >= 4,
            isLoading: busy,
            padded: false
        )
        .padding(.top, Space.lg)

        if connections.contains(where: { $0.isActive }) {
            Button { phase = .list } label: {
                Text("back").font(Typo.caption).foregroundStyle(Palette.cocoaSecondary)
            }
            .buttonStyle(JKPress()).padding(.top, Space.md)
        }
        Spacer(minLength: Space.xl)
        Spacer(minLength: 0)
    }

    // MARK: consent

    @ViewBuilder
    private var consentScreen: some View {
        if let preview, let orgName = preview.orgName, let orgId = preview.orgId {
            CareConsentView(
                userId: userId, orgId: orgId, orgName: orgName, code: code,
                onDone: { Task { await reload() } },
                onCancel: { phase = .enter }
            )
        } else {
            Text("something went wrong.").font(Typo.body).foregroundStyle(Palette.cocoaSecondary)
                .padding(.top, 40)
        }
    }

    // MARK: actions

    private func lookUp() async {
        busy = true; errorLine = nil
        do {
            let p = try await CareConnectionService.preview(code: code)
            busy = false
            if p.ok { preview = p; phase = .consent }
            else { errorLine = "that code didn't work. check it and try again." }
        } catch {
            busy = false
            errorLine = "couldn't reach your clinic just now. try again in a moment."
        }
    }

    private func disconnect(_ c: CareConnection) async {
        do {
            try await CareConnectionService.revoke(orgId: c.orgId, scope: nil, disconnect: true)
            await reload()
            Haptics.soft()
        } catch { errorLine = "couldn't update just now." }
    }
}

// MARK: - CareConsentView (the 164.508 elements, plain)

struct CareConsentView: View {
    let userId: String
    let orgId: String
    let orgName: String
    let code: String
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var granted: Set<CareScope> = [.visitPacket, .observations, .assignment]
    @State private var lookback = 28   // 28 = last 4 weeks, 0 = from today
    @State private var busy = false
    @State private var errorLine: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("connect with")
                    .font(Typo.caption).textCase(.uppercase).tracking(1.1)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.top, Space.xl)
                Text(orgName)
                    .font(.custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, 4)

                Text("choose what \(orgName) can see and do. nothing is shared until you allow it, and you can turn any of it off anytime.")
                    .font(Typo.body).foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(CareScope.allCases, id: \.self) { scope in
                        scopeToggle(scope)
                    }
                }
                .padding(.top, Space.lg)

                // lookback chooser (stricter than the industry norm)
                Text("how far back")
                    .font(Typo.caption).textCase(.uppercase).tracking(1.1)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.top, Space.xl)
                lookbackChoice("the last 4 weeks", 28)
                lookbackChoice("from today only", 0)

                Text("your clinic reviews your records at your visits. nothing here is watched in real time. for anything urgent, call your clinic or emergency services.")
                    .font(Typo.caption).foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.lg)

                if let errorLine {
                    Text(errorLine).font(Typo.caption).foregroundStyle(Palette.stateBad).padding(.top, Space.md)
                }

                Button { Task { await accept() } } label: {
                    HStack {
                        if busy { ProgressView().tint(Palette.textInverse) }
                        Text("connect").font(Typo.heading).foregroundStyle(Palette.textInverse)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(granted.isEmpty ? Palette.cocoaTertiary : Palette.cocoaPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(granted.isEmpty || busy)
                .padding(.top, Space.lg)

                Button { onCancel() } label: {
                    Text("not now").font(Typo.caption).foregroundStyle(Palette.cocoaSecondary)
                }
                .buttonStyle(JKPress()).padding(.top, Space.md).padding(.bottom, Space.xl)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func scopeToggle(_ scope: CareScope) -> some View {
        Button {
            withAnimation(Motion.tap) {
                if granted.contains(scope) { granted.remove(scope) } else { granted.insert(scope) }
            }
            Haptics.soft()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: granted.contains(scope) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(granted.contains(scope) ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scope.title)
                        .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                    Text(scope.detail)
                        .font(Typo.caption).foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(scope.title). \(scope.detail)")
        .accessibilityAddTraits(granted.contains(scope) ? [.isButton, .isSelected] : .isButton)
    }

    private func lookbackChoice(_ label: String, _ days: Int) -> some View {
        Button {
            withAnimation(Motion.tap) { lookback = days }
            Haptics.soft()
        } label: {
            HStack {
                Image(systemName: lookback == days ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(lookback == days ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                Text(label)
                    .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityAddTraits(lookback == days ? [.isButton, .isSelected] : .isButton)
    }

    private func accept() async {
        busy = true; errorLine = nil
        do {
            let res = try await CareConnectionService.accept(
                code: code, lookbackDays: lookback,
                scopes: CareScope.allCases.filter { granted.contains($0) }
            )
            busy = false
            if res.ok {
                Haptics.soft()
                onDone()
            } else if res.reason == "already_connected" {
                errorLine = "you're already connected to this clinic."
            } else {
                errorLine = "that code didn't work. check it and try again."
            }
        } catch {
            busy = false
            errorLine = "couldn't connect just now. try again in a moment."
        }
    }
}
