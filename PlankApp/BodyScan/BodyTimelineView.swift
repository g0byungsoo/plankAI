import SwiftUI
import SwiftData
import PlankSync

// MARK: - BodyTimelineView
//
// app v9 P2 — her record, opened: THE COMPARE on top (then ↔ now,
// one thumb-driven crossfade — the unforgettable interaction, L7),
// the week-grouped record beneath, and the quiet cover door. The
// alignment transform runs underneath (anchors from the pose gate)
// and never surfaces as a number (L3). Deleting stays in settings —
// this surface is for looking, not managing.

struct BodyTimelineView: View {
    let userId: String
    let onClose: () -> Void
    /// v10: the record explains its own standing ("week 2 of your
    /// record. four weeks apart draws real change.") — the floor-
    /// gated BodyChangeRead line, composed by the presenter.
    var changeLine: String? = nil

    @Environment(\.modelContext) private var modelContext
    // v10 (V7): the door now governs the LANDING figure (default
    // on — the journal opens on her); off returns the old cover +
    // the body page. Copy = D10 draft.
    @AppStorage("bodyScan.landingFigure") private var landingFigure = true

    /// v10.1 — THE JOURNEY SCRUB: one continuous position across
    /// ALL of her scans (0 = the first, N-1 = the newest); every
    /// scan is a haptic detent, release settles on the nearest.
    @State private var position: CGFloat = 0
    @State private var lastDetent = 0
    @State private var positionSeeded = false

    private var scans: [BodyScanRecord] {
        BodyScanStore.all(userId: userId, in: modelContext)
    }

    /// Oldest → newest — the journey's reading order.
    private var journey: [BodyScanRecord] { scans.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("YOUR RECORD")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Palette.bgElevated))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("close")
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let changeLine {
                        ItalicAccentText(
                            changeLine,
                            italic: [],
                            baseFont: .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                            italicFont: .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3),
                            color: Palette.textPrimary,
                            alignment: .leading
                        )
                        .lineSpacing(-2)
                        .kerning(-0.3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.md)
                    }
                    if let now = scans.first {
                        compareStage(now: now)
                            .padding(.top, Space.lg)
                        weekGroups
                            .padding(.top, Space.xl)
                        coverDoor
                            .padding(.top, Space.lg)
                            .padding(.bottom, Space.xl)
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .onAppear {
            // The journey opens on now (the newest scan).
            if !positionSeeded {
                positionSeeded = true
                position = CGFloat(max(0, journey.count - 1))
                lastDetent = max(0, journey.count - 1)
            }
        }
    }

    // MARK: - THE JOURNEY SCRUB (v10.1 — one drag, her whole record)

    /// The scan the journey currently rests nearest to.
    private var nearestScan: BodyScanRecord? {
        let j = journey
        guard !j.isEmpty else { return nil }
        let idx = min(max(0, Int((position).rounded())), j.count - 1)
        return j[idx]
    }

    @ViewBuilder
    private func compareStage(now: BodyScanRecord) -> some View {
        let j = journey
        let maxIndex = CGFloat(max(0, j.count - 1))
        VStack(spacing: Space.sm) {
            ZStack {
                journeyBlend(j)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.bgPrimary)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.cocoaPrimary.opacity(0.10), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            // One drag sweeps her whole record; every scan is a
            // haptic detent; release settles on the nearest scan (a
            // balance coming to rest — mid-blend is never a rest
            // state). Numbers never surface (L3).
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard j.count > 1 else { return }
                        let width = max(1, UIScreen.main.bounds.width - Space.lg * 2)
                        position = min(maxIndex, max(0, value.location.x / width * maxIndex))
                        let detent = Int(position.rounded())
                        if detent != lastDetent {
                            lastDetent = detent
                            Haptics.light()
                        }
                    }
                    .onEnded { _ in
                        guard j.count > 1 else { return }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            position = position.rounded()
                        }
                        Haptics.soft()
                    }
            )
            .accessibilityElement()
            .accessibilityIdentifier("record.compare")
            .accessibilityLabel("your journey, scan by scan")
            .accessibilityHint("drag across your record; each scan is a stop")
            .accessibilityValue(
                nearestScan.map { "showing \(dateWord($0.capturedAt))" } ?? ""
            )

            // The nearest scan's date + the detent rail beneath.
            if let nearest = nearestScan {
                Text(dateWord(nearest.capturedAt))
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .callout))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .contentTransition(.opacity)
                    .animation(Motion.crossFade, value: dateWord(nearest.capturedAt))
            }
            if j.count > 1 {
                journeyRail(count: j.count, maxIndex: maxIndex)
            }
        }
    }

    /// The two neighbouring scans of the continuous position, the
    /// lower aligned onto the higher (pairwise transform — internal
    /// mechanics, never a surfaced number).
    @ViewBuilder
    private func journeyBlend(_ j: [BodyScanRecord]) -> some View {
        let lower = min(max(0, Int(position.rounded(.down))), max(0, j.count - 1))
        let upper = min(lower + 1, j.count - 1)
        let frac = min(1, max(0, position - CGFloat(lower)))
        if lower == upper, let only = face(j[lower]) {
            Image(uiImage: only).resizable().scaledToFit()
        } else if let ref = face(j[upper]), let under = face(j[lower]) {
            alignedFigure(under, from: j[lower], onto: j[upper])
                .opacity(1 - Double(frac))
            Image(uiImage: ref)
                .resizable()
                .scaledToFit()
                .opacity(Double(frac))
        }
    }

    /// A scan drawn through the internal alignment transform so its
    /// figure coincides with the reference scan's.
    @ViewBuilder
    private func alignedFigure(
        _ image: UIImage, from: BodyScanRecord, onto reference: BodyScanRecord
    ) -> some View {
        let t = BodyChangeRead.transform(then: anchors(from), now: anchors(reference))
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(t.scale)
                .offset(
                    x: t.offsetXNorm * geo.size.width,
                    y: -t.offsetYNorm * geo.size.height   // Vision y is bottom-up
                )
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(faceAspect(image), contentMode: .fit)
    }

    /// The rail: one quiet tick per scan, the rose thumb at the
    /// continuous position. Dots hide when the record outgrows them.
    private func journeyRail(count: Int, maxIndex: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.cocoaPrimary.opacity(0.10))
                    .frame(height: 3)
                    .frame(maxHeight: .infinity)
                if count <= 40 {
                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(Palette.cocoaPrimary.opacity(0.28))
                            .frame(width: 3.5, height: 3.5)
                            .offset(x: CGFloat(i) / max(1, maxIndex) * (geo.size.width - 11) + 3.75)
                            .frame(maxHeight: .infinity)
                    }
                }
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 11, height: 11)
                    .offset(x: position / max(1, maxIndex) * (geo.size.width - 11))
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(height: 20)
        .accessibilityHidden(true)
    }

    // MARK: - The weeks (jump points into the journey)

    /// Tap any scan to glide the journey to it.
    private func jump(to scan: BodyScanRecord) {
        guard let idx = journey.firstIndex(where: { $0.id == scan.id }) else { return }
        Haptics.light()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            position = CGFloat(idx)
        }
        lastDetent = idx
    }

    private var weekGroups: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("WEEK BY WEEK")
                .font(Typo.eyebrow)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
            ForEach(groupedByWeek, id: \.label) { group in
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(group.label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                    HStack(spacing: Space.sm) {
                        ForEach(group.scans, id: \.id) { scan in
                            thumb(
                                scan,
                                selected: scan.id == nearestScan?.id
                            ) {
                                jump(to: scan)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var coverDoor: some View {
        Button {
            Haptics.light()
            landingFigure.toggle()
        } label: {
            HStack {
                Text("your figure opens becoming")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                Spacer()
                Text(landingFigure ? "on" : "off")
                    .font(Typo.caption)
                    .foregroundStyle(landingFigure ? Palette.accent : Palette.cocoaTertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("your figure opens becoming, \(landingFigure ? "on" : "off")")
    }

    // MARK: - Helpers

    private struct WeekGroup { let label: String; let scans: [BodyScanRecord] }

    private var groupedByWeek: [WeekGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: scans) { scan in
            cal.dateInterval(of: .weekOfYear, for: scan.capturedAt)?.start ?? scan.capturedAt
        }
        return groups.keys.sorted(by: >).map { start in
            WeekGroup(
                label: "week of " + start.formatted(.dateTime.month(.abbreviated).day()).lowercased(),
                scans: (groups[start] ?? []).sorted { $0.capturedAt > $1.capturedAt }
            )
        }
    }

    private func face(_ scan: BodyScanRecord) -> UIImage? {
        BodyScanPhotoStore.image(scanId: scan.id, preferring: scan.renderMode)
    }

    private func faceAspect(_ image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 3.0 / 4.0 }
        return image.size.width / image.size.height
    }

    private func anchors(_ scan: BodyScanRecord) -> BodyChangeRead.Anchors? {
        guard let top = scan.figureTopY, let bottom = scan.figureBottomY,
              let cx = scan.figureCenterX else { return nil }
        return .init(top: top, bottom: bottom, centerX: cx)
    }

    private func dateWord(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day()).lowercased()
    }

    private func thumb(
        _ scan: BodyScanRecord, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let image = face(scan) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Palette.bgElevated
                }
            }
            .frame(width: 56, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : .clear, lineWidth: 1.5)
            )
            .overlay(alignment: .bottomLeading) {
                Text(dateWord(scan.capturedAt))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.bgPrimary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Palette.cocoaPrimary.opacity(0.55), in: Capsule())
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("scan from \(dateWord(scan.capturedAt))")
    }
}
