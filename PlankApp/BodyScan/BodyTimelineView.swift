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

    @Environment(\.modelContext) private var modelContext
    @AppStorage("bodyScan.coverOptIn") private var coverOptIn = false

    /// The "then" side of the compare; newest prior scan by default.
    @State private var thenScan: BodyScanRecord?
    /// 0 = fully then, 1 = fully now.
    @State private var blend: CGFloat = 1

    private var scans: [BodyScanRecord] {
        BodyScanStore.all(userId: userId, in: modelContext)
    }

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
                    if let now = scans.first {
                        compareStage(now: now)
                            .padding(.top, Space.lg)
                        if scans.count > 1 {
                            thenPicker
                                .padding(.top, Space.md)
                        }
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
            if thenScan == nil { thenScan = scans.dropFirst().first }
        }
    }

    // MARK: - The compare (then ↔ now, one gesture)

    @ViewBuilder
    private func compareStage(now: BodyScanRecord) -> some View {
        let then = thenScan
        VStack(spacing: Space.sm) {
            ZStack {
                if let then, let thenImage = face(then) {
                    alignedThen(thenImage, then: then, now: now)
                        .opacity(1 - blend)
                }
                if let nowImage = face(now) {
                    Image(uiImage: nowImage)
                        .resizable()
                        .scaledToFit()
                        .opacity(then == nil ? 1 : blend)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, x: 0, y: 6)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard then != nil else { return }
                        let width = max(1, UIScreen.main.bounds.width - Space.lg * 2)
                        blend = min(1, max(0, value.location.x / width))
                    }
            )
            .accessibilityLabel("compare, then and now")
            .accessibilityHint("drag between your first and latest scan")

            if let then {
                HStack {
                    Text(dateWord(then.capturedAt))
                        .font(Typo.caption)
                        .foregroundStyle(blend < 0.5 ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                    scrubRail
                    Text(dateWord(now.capturedAt))
                        .font(Typo.caption)
                        .foregroundStyle(blend >= 0.5 ? Palette.cocoaPrimary : Palette.cocoaTertiary)
                }
            } else {
                Text(dateWord(now.capturedAt))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .animation(Motion.crossFade, value: blend >= 0.5)
    }

    /// "Then" drawn through the internal alignment transform so the
    /// figures coincide — mechanics, never a surfaced number.
    @ViewBuilder
    private func alignedThen(
        _ image: UIImage, then: BodyScanRecord, now: BodyScanRecord
    ) -> some View {
        let t = BodyChangeRead.transform(then: anchors(then), now: anchors(now))
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

    private var scrubRail: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.cocoaPrimary.opacity(0.10))
                    .frame(height: 3)
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 11, height: 11)
                    .offset(x: blend * (geo.size.width - 11))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
        .accessibilityHidden(true)
    }

    // MARK: - Then picker + weeks

    private var thenPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(scans.dropFirst(), id: \.id) { scan in
                    thumb(scan, selected: scan.id == thenScan?.id) {
                        Haptics.light()
                        thenScan = scan
                        blend = 0.5
                    }
                }
            }
        }
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
                            thumb(scan, selected: false) {
                                Haptics.light()
                                if scan.id != scans.first?.id {
                                    thenScan = scan
                                    blend = 0.5
                                }
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
            coverOptIn.toggle()
        } label: {
            HStack {
                Text("her scan as the becoming cover")
                    .font(Typo.body)
                    .foregroundStyle(Palette.cocoaSecondary)
                Spacer()
                Text(coverOptIn ? "on" : "off")
                    .font(Typo.caption)
                    .foregroundStyle(coverOptIn ? Palette.accent : Palette.cocoaTertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("use your scan as the becoming cover, \(coverOptIn ? "on" : "off")")
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
