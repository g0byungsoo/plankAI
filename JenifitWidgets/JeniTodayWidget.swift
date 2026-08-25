import WidgetKit
import SwiftUI

// MARK: - JeniTodayWidget (app v25 pass 58)
//
// The Home Screen answers ONE question — where does today stand — in
// the band's own grammar: the protein ring (the only earned shape),
// one quiet kcal sentence, and the dose standing in DoseStanding's
// discretion (never a product name, never an amount). Everything
// rendered here was precomposed by the app (JeniWidgetSnapshot); this
// process holds no engine and can never disagree with Home.
//
// Truthfulness: an entry speaks only for its own civil day. The
// timeline carries [now, next-midnight]; the midnight entry renders
// the fresh-day state (nothing eaten yet, targets standing), and a
// stale store read after that renders fresh-day too — yesterday's
// numbers are never presented as today's. `.privacySensitive` rides
// the dose line so Lock Screen redaction applies to the most private
// fact on the surface.

// MARK: - Palette (pinned to DesignSystem/Tokens.swift — the widget
// process cannot see the app module; these four values are the law's
// copies, not a second palette)

private enum WPalette {
    static let paper = Color(red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xEF / 255)
    static let ink = Color(red: 0x18 / 255, green: 0x10 / 255, blue: 0x0F / 255)
    static let cocoa = Color(red: 0x5A / 255, green: 0x43 / 255, blue: 0x40 / 255)
    static let accent = Color(red: 0xC4 / 255, green: 0x67 / 255, blue: 0x7A / 255)
    static let berry = Color(red: 0x9E / 255, green: 0x4A / 255, blue: 0x5F / 255)
}

private enum WFont {
    static func serif(_ size: CGFloat) -> Font { .custom("JeniHeroSerif-Regular", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("DMSans-Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("DMSans-Medium", size: size) }
    static func semibold(_ size: CGFloat) -> Font { .custom("DMSans-SemiBold", size: size) }
}

// MARK: - Timeline

struct JeniTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: JeniWidgetSnapshot?
}

struct JeniTodayProvider: TimelineProvider {

    func placeholder(in context: Context) -> JeniTodayEntry {
        JeniTodayEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (JeniTodayEntry) -> Void) {
        completion(JeniTodayEntry(date: .now, snapshot: liveSnapshot(at: .now) ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JeniTodayEntry>) -> Void) {
        let now = Date.now
        var entries = [JeniTodayEntry(date: now, snapshot: liveSnapshot(at: now))]

        // The rollover entry: at midnight the numbers reset honestly
        // even if the app never wakes. `.atEnd` re-asks after it.
        if let stored = JeniWidgetSnapshot.read() {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone.current
            if let midnight = cal.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 5),
                matchingPolicy: .nextTime
            ) {
                entries.append(JeniTodayEntry(
                    date: midnight,
                    snapshot: stored.freshDay(as: JeniWidgetSnapshot.dayKey(for: midnight))
                ))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// The stored snapshot, aged truthfully: same civil day → live;
    /// an older day → the fresh-day state; nothing stored → nil.
    private func liveSnapshot(at date: Date) -> JeniWidgetSnapshot? {
        guard let stored = JeniWidgetSnapshot.read() else { return nil }
        let today = JeniWidgetSnapshot.dayKey(for: date)
        return stored.dayKey == today ? stored : stored.freshDay(as: today)
    }
}

extension JeniWidgetSnapshot {
    /// Gallery/placeholder face — representative, never presented as
    /// the user's own record (placeholders render redacted anyway).
    static let preview = JeniWidgetSnapshot(
        dayKey: JeniWidgetSnapshot.dayKey(),
        generatedAt: .now,
        proteinEatenG: 64,
        proteinFloorG: 90,
        kcalEaten: 1240,
        kcalTarget: 1620,
        plateCount: 3,
        countUpOnly: false,
        isMaintenance: false,
        numericsSuppressed: false,
        doseLine: nil
    )
}

// MARK: - The ring (static; a widget renders archived views, so the
// trace-in belongs to the app — here the shape is simply at rest)

private struct WRing: View {
    let fraction: Double
    var size: CGFloat = 64
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(WPalette.accent.opacity(0.16), lineWidth: lineWidth)
            // A zero day draws the track alone — a round cap at 0.001
            // would mint a phantom dot (caught on the gallery film).
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: min(1, fraction))
                    .stroke(
                        fraction >= 1 ? WPalette.berry : WPalette.accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth / 2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Faces

struct JeniTodayWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: JeniTodayEntry
    /// Harness-only: `widgetFamily` is read-only in the environment,
    /// so the in-app gallery passes the family explicitly.
    var familyOverride: WidgetFamily? = nil

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                if snap.numericsSuppressed {
                    quietFace(snap)
                } else {
                    switch family {
                    case .systemMedium: medium(snap)
                    default: small(snap)
                    }
                }
            } else {
                beginFace
            }
        }
        .containerBackground(for: .widget) { WPalette.paper }
        .widgetURL(URL(string: "jenifit://today"))
    }

    // No record on this device yet.
    private var beginFace: some View {
        VStack(spacing: 6) {
            Text("jeni")
                .font(WFont.serif(24))
                .foregroundStyle(WPalette.ink)
            Text("open to begin.")
                .font(WFont.body(12))
                .foregroundStyle(WPalette.cocoa)
        }
    }

    /// The suppressed cohort's face: presence without a single
    /// numeral (the safety gate's law reaches the Home Screen).
    private func quietFace(_ snap: JeniWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("today")
                .font(WFont.semibold(11))
                .foregroundStyle(WPalette.ink.opacity(0.55))
            Spacer(minLength: 0)
            Text(snap.plateCount > 0 ? "on the record." : "the day is open.")
                .font(WFont.serif(19))
                .foregroundStyle(WPalette.ink)
            if let dose = snap.doseLine {
                Text(dose)
                    .font(WFont.body(12))
                    .foregroundStyle(WPalette.cocoa)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func small(_ snap: JeniWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("protein")
                .font(WFont.semibold(11))
                .foregroundStyle(WPalette.ink.opacity(0.55))
            Spacer(minLength: 4)
            HStack(alignment: .center, spacing: 12) {
                if let floor = snap.proteinFloorG, floor > 0 {
                    ZStack {
                        WRing(fraction: Double(snap.proteinEatenG) / Double(floor))
                        Text("\(snap.proteinEatenG)")
                            .font(WFont.serif(20))
                            .foregroundStyle(WPalette.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(maxWidth: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("of \(floor) g")
                            .font(WFont.medium(12))
                            .foregroundStyle(WPalette.cocoa)
                        if let reading = snap.proteinReading {
                            Text(reading)
                                .font(WFont.body(11))
                                .foregroundStyle(WPalette.ink.opacity(0.55))
                        }
                    }
                } else {
                    Text(snap.plateCount > 0
                         ? "\(snap.plateCount) on the record"
                         : "nothing yet today")
                        .font(WFont.serif(17))
                        .foregroundStyle(WPalette.ink)
                }
            }
            Spacer(minLength: 4)
            if let dose = snap.doseLine {
                Text(dose)
                    .font(WFont.body(11))
                    .foregroundStyle(WPalette.cocoa)
                    .lineLimit(1)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(a11y(snap)))
    }

    private func medium(_ snap: JeniWidgetSnapshot) -> some View {
        HStack(alignment: .center, spacing: 16) {
            if let floor = snap.proteinFloorG, floor > 0 {
                ZStack {
                    WRing(fraction: Double(snap.proteinEatenG) / Double(floor),
                          size: 76, lineWidth: 8)
                    VStack(spacing: 0) {
                        Text("\(snap.proteinEatenG)")
                            .font(WFont.serif(22))
                            .foregroundStyle(WPalette.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(maxWidth: 46)
                        Text("of \(floor) g")
                            .font(WFont.body(9))
                            .foregroundStyle(WPalette.cocoa)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("protein")
                    .font(WFont.semibold(11))
                    .foregroundStyle(WPalette.ink.opacity(0.55))
                if let reading = snap.proteinReading {
                    Text(reading)
                        .font(WFont.medium(14))
                        .foregroundStyle(WPalette.ink)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(snap.kcalEaten.formatted())
                        .font(WFont.serif(17))
                        .foregroundStyle(WPalette.ink)
                    if let reference = snap.dayReference {
                        Text(reference)
                            .font(WFont.body(11))
                            .foregroundStyle(WPalette.cocoa)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let dose = snap.doseLine {
                    Text(dose)
                        .font(WFont.body(11))
                        .foregroundStyle(WPalette.cocoa)
                        .privacySensitive()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(a11y(snap)))
    }

    private func a11y(_ snap: JeniWidgetSnapshot) -> String {
        var parts: [String] = []
        if let floor = snap.proteinFloorG, floor > 0 {
            parts.append("protein \(snap.proteinEatenG) of \(floor) grams")
        }
        if let reference = snap.dayReference {
            parts.append("\(snap.kcalEaten) \(reference)")
        }
        if let dose = snap.doseLine { parts.append(dose) }
        return parts.isEmpty ? "jeni, the day is open" : parts.joined(separator: ", ")
    }
}

// MARK: - The widget

struct JeniTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JeniTodayWidget", provider: JeniTodayProvider()) { entry in
            JeniTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("today")
        .description("where the day stands — protein, the day, your shot.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
