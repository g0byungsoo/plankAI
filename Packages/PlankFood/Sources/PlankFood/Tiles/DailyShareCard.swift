#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - DailyShareCard
//
// v1.0.9 D3.C — daily 9:16 share card (1080×1920) rendered via
// ImageRenderer for IG Stories / TikTok bait. Per plan synthesis
// §D3 Daily 9:16:
//
//   - Cream background #F7F1E8 (NOT white — journal-page feel)
//   - Date header in lowercase Fraunces italic — "*tuesday*, june 7"
//   - 2×2 polaroid grid of meal cards (text-only for v1 — we don't
//     store photos yet; v1.1 ships photo-backed polaroids).
//     Each polaroid: cream background, slight rotation, cocoa border.
//   - 2-3 soft pills, lowercase SF — NO kcal numbers, NO fabricated
//     data (data provenance lock).
//   - Fraunces italic pull-quote rotated daily from a curated 12
//     ("*today fits*", etc).
//   - Scattered stickers (cherries, bow, flower3D, max 3).
//   - jenifit wordmark, bottom-center, 14pt rose, 40% opacity.
//
// "today fits ♡" is the viral hook — burned in as the default
// pull-quote, rotated daily through 12 alts so a returning user
// doesn't see the same line twice in a row.
//
// Designed for ImageRenderer offscreen rendering. NEVER mounted in
// the user's actual view hierarchy — only by DailyShareRenderer.

struct DailyShareCard: View {

    let date: Date
    let entries: [FoodLogPersister.FoodLogEntry]
    let pillTexts: [String]

    /// 1080×1920 canvas. SwiftUI logical pts here; ImageRenderer.scale
    /// is set to 1.0 by the renderer so logical pt == pixel.
    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                dateHeader
                    .padding(.top, 110)
                    .padding(.horizontal, 80)

                Spacer().frame(height: 28)

                intentionLine
                    .padding(.horizontal, 80)

                Spacer().frame(height: 72)

                polaroidGrid
                    .frame(maxWidth: .infinity)

                Spacer().frame(height: 80)

                pillRow
                    .padding(.horizontal, 80)

                Spacer().frame(height: 90)

                pullQuote
                    .padding(.horizontal, 80)

                Spacer()

                wordmark
                    .padding(.bottom, 70)
            }
        }
        .frame(width: 1080, height: 1920)
        .background(Color(hex: "#F7F1E8"))
    }

    // MARK: - Background

    @ViewBuilder private var background: some View {
        ZStack {
            Color(hex: "#F7F1E8")

            // Scattered coquette stickers — 3 max per plan, kept at
            // soft opacity so the pull-quote stays the eye.
            Image("sticker_cherries", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-12))
                .opacity(0.85)
                .offset(x: -380, y: -780)

            Image("sticker_bow_iridescent", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(14))
                .opacity(0.85)
                .offset(x: 400, y: -720)

            Image("sticker_flower_3d", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(-8))
                .opacity(0.7)
                .offset(x: 380, y: 760)
        }
    }

    // MARK: - Date header

    @ViewBuilder private var dateHeader: some View {
        HStack(spacing: 0) {
            Text(weekdayPart)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 72))
            Text(", " + monthDayPart)
                .font(.custom("Fraunces72pt-Regular", size: 72))
        }
        .foregroundStyle(Color(hex: "#3D2B2B"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekdayPart: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date).lowercased()
    }

    private var monthDayPart: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return fmt.string(from: date).lowercased()
    }

    // MARK: - Intention line

    /// One-line "what today looked like" sourced from the user's own
    /// log count. Data-provenance locked — no fabricated mood.
    @ViewBuilder private var intentionLine: some View {
        Text(intentionCopy)
            .font(.system(size: 30))
            .foregroundStyle(Color(hex: "#7B5959"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intentionCopy: String {
        switch entries.count {
        case 0:  return "a quieter day."
        case 1:  return "one plate, on purpose."
        case 2:  return "showed up twice today."
        case 3:  return "three quiet wins."
        default: return "showed up \(entries.count) times today."
        }
    }

    // MARK: - Polaroid grid

    /// 2×2 grid of text-only polaroid cards. Each shows a meal title
    /// + soft timestamp. Slight per-card rotation reads scrapbook,
    /// not iOS-grid. Fewer than 4 entries → fewer cards; centered.
    /// Empty state → single "table is set" polaroid.
    @ViewBuilder private var polaroidGrid: some View {
        let top = Array(entries.prefix(4))
        if top.isEmpty {
            polaroidCard(
                title: "the table is set.",
                time: "today",
                rotation: -3,
                isEmptyState: true
            )
            .frame(width: 440, height: 500)
        } else {
            // Pad to exactly 4 slots so the grid layout is stable.
            // Slots beyond the entry count render an invisible spacer.
            let rotations: [Double] = [-3, 2, -1, 4]
            VStack(spacing: 36) {
                HStack(spacing: 36) {
                    polaroidSlot(top.indices.contains(0) ? top[0] : nil,
                                 rotation: rotations[0])
                    polaroidSlot(top.indices.contains(1) ? top[1] : nil,
                                 rotation: rotations[1])
                }
                HStack(spacing: 36) {
                    polaroidSlot(top.indices.contains(2) ? top[2] : nil,
                                 rotation: rotations[2])
                    polaroidSlot(top.indices.contains(3) ? top[3] : nil,
                                 rotation: rotations[3])
                }
            }
        }
    }

    @ViewBuilder
    private func polaroidSlot(
        _ entry: FoodLogPersister.FoodLogEntry?,
        rotation: Double
    ) -> some View {
        if let entry {
            polaroidCard(
                title: entry.title.isEmpty ? "scanned plate" : entry.title.lowercased(),
                time: timeLabel(for: entry.loggedAt),
                rotation: rotation,
                isEmptyState: false
            )
            .frame(width: 440, height: 500)
        } else {
            Color.clear.frame(width: 440, height: 500)
        }
    }

    @ViewBuilder
    private func polaroidCard(
        title: String,
        time: String,
        rotation: Double,
        isEmptyState: Bool
    ) -> some View {
        VStack(spacing: 0) {
            // Top: text panel that stands in for the photo until v1.1
            // ships photo storage. Cocoa text on accentSubtle so the
            // card still reads as a contentful tile, not a blank
            // polaroid.
            ZStack {
                Color(hex: "#F5D5D8").opacity(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(title)
                    .font(.custom("Fraunces72pt-Regular", size: 34))
                    .foregroundStyle(Color(hex: "#3D2B2B"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 32)
            }
            .frame(width: 380, height: 380)
            .padding(.top, 24)
            .padding(.horizontal, 24)

            // Caption — Fraunces italic, matches plan §D3 caption spec.
            Text(time)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
                .foregroundStyle(Color(hex: "#7B5959"))
                .padding(.vertical, 24)
        }
        .frame(width: 440, height: 500)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 2, y: 6)
        .rotationEffect(.degrees(rotation))
    }

    private func timeLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        fmt.amSymbol = "am"
        fmt.pmSymbol = "pm"
        return fmt.string(from: date)
    }

    // MARK: - Pills

    @ViewBuilder private var pillRow: some View {
        HStack(spacing: 14) {
            Spacer()
            ForEach(Array(pillTexts.prefix(3).enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.system(size: 26))
                    .foregroundStyle(Color(hex: "#3D2B2B"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(Color(hex: "#E8B4B8").opacity(0.55))
                    )
            }
            Spacer()
        }
    }

    // MARK: - Pull quote

    @ViewBuilder private var pullQuote: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            (
                Text(quotePart1).font(.custom("Fraunces72pt-Regular", size: 56)) +
                Text(quotePart2).font(.custom("Fraunces72pt-SemiBoldItalic", size: 56)) +
                Text(" ♡").font(.system(size: 48))
            )
            .foregroundStyle(Color(hex: "#3D2B2B"))
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    /// Split the locked quote into "regular prefix" + "italic punch
    /// word(s)" + heart suffix per voice lock.
    private var quotePart1: String {
        switch quoteIndex {
        case 0:  return "today "         // "today *fits*"
        case 1:  return "slow and "      // "slow and *on purpose*"
        case 2:  return "proud of "      // "proud of *this one*"
        case 3:  return "becoming, "     // "becoming, *quietly*"
        case 4:  return "a "             // "a *soft day*"
        case 5:  return "nourished "     // "nourished *today*"
        case 6:  return "worth the "     // "worth the *pause*"
        case 7:  return ""                // "*enough*"
        case 8:  return "trusting "      // "trusting *the day*"
        case 9:  return "quiet "         // "quiet *progress*"
        case 10: return "kind "          // "kind *to me*"
        default: return "gentle "         // "gentle *wins*"
        }
    }

    private var quotePart2: String {
        switch quoteIndex {
        case 0:  return "fits"
        case 1:  return "on purpose"
        case 2:  return "this one"
        case 3:  return "quietly"
        case 4:  return "soft day"
        case 5:  return "today"
        case 6:  return "pause"
        case 7:  return "enough"
        case 8:  return "the day"
        case 9:  return "progress"
        case 10: return "to me"
        default: return "wins"
        }
    }

    /// Day-of-year mod 12 so the line rotates daily — a returning
    /// sharer doesn't see the same quote two days in a row, and
    /// "today fits" lands ~30 days a year as the viral hook anchor.
    private var quoteIndex: Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return day % 12
    }

    // MARK: - Wordmark

    @ViewBuilder private var wordmark: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("jenifit")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Color(hex: "#C4677A").opacity(0.4))
            Spacer()
        }
    }
}

#endif  // canImport(UIKit)
