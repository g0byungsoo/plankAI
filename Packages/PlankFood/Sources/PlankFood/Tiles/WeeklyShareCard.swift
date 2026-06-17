#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - WeeklyShareCard
//
// v1.0.10 — weekly 9:16 share card (1080×1920) rendered via
// ImageRenderer. Companion to DailyShareCard (2×2 polaroids of
// TODAY's plates); this one is the WEEK kept — 2×3 photo grid with
// the her75 register (JeniHeroSerif, Playfair-genealogy display).
//
// Founder direction (2026-06-17): the format target is the it-girl
// meal-grid TikTok save — 6 photo cells, photo-forward, minimal
// caption, rotated like polaroids stuck onto a scrapbook page.
//
// Layout (1080×1920 canvas, top-down):
//   - 0    →  240pt: eyebrow row + hero line ("the week, *kept* ♡")
//   - 240  → 1560pt: 2×3 photo grid (one cell per logged day, ≤6)
//   - 1560 → 1920pt: rotating italic pull-quote + jenifit wordmark
//
// Photo cell: 410×440pt — 380×380 image inside an 8pt white matte
// frame, italic weekday at the bottom of the matte. Each cell
// rotated by a curated angle so the grid reads as a real scrapbook
// page, not a CSS grid.
//
// Empty cells (fewer than 6 days logged this week): cream block
// with the day name italicized. Grid stays full visually even on
// partial weeks. If the user has zero photo-backed logs this week,
// the renderer no-ops upstream and we don't fire this card.
//
// Designed for ImageRenderer offscreen rendering. NEVER mounted in
// a live view hierarchy — only by WeeklyShareRenderer.

struct WeeklyShareCard: View {

    /// First day of the week being shared (Sunday, calendar-local).
    let weekStart: Date

    /// Up to 6 cell models in chronological order (oldest first). The
    /// renderer pre-trims to ≤6 — this view will only render the
    /// first 6 entries even if more are passed.
    let cells: [WeeklyShareCell]

    /// entryId → stored food photo. Entries without a photo fall back
    /// to the title-only polaroid panel.
    let photos: [String: UIImage]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 96)
                eyebrowRow.padding(.horizontal, 80)
                Spacer().frame(height: 16)
                heroLine.padding(.horizontal, 80)
                Spacer().frame(height: 56)
                grid
                Spacer().frame(height: 52)
                pullQuote.padding(.horizontal, 90)
                Spacer()
                wordmark.padding(.bottom, 72)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Background + sticker scatter
    //
    // Per [[feedback-scatter-milestone-rule]] stickers belong on the
    // 3 earned moments. The weekly share = celebration of the week
    // kept = earned moment. 3 stickers at the corners (cherries, bow,
    // gummy) at 0.75–0.85 opacity so the photos stay the eye.

    @ViewBuilder private var background: some View {
        ZStack {
            Color(hex: "#F7F1E8")

            Image("sticker_cherries", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 138, height: 138)
                .rotationEffect(.degrees(-14))
                .opacity(0.85)
                .offset(x: -380, y: -800)

            Image("sticker_bow_iridescent", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 116)
                .rotationEffect(.degrees(12))
                .opacity(0.82)
                .offset(x: 400, y: -780)

            Image("sticker_gummy_bear", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(16))
                .opacity(0.78)
                .offset(x: -370, y: 760)
        }
    }

    // MARK: - Eyebrow + hero

    @ViewBuilder private var eyebrowRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("HER WEEK")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(Color(hex: "#7B5959"))
                .kerning(3.6)
            Spacer()
            Text(dateRangeLabel)
                .font(.custom("Fraunces72pt-Regular", size: 28))
                .foregroundStyle(Color(hex: "#7B5959"))
        }
    }

    @ViewBuilder private var heroLine: some View {
        (
            Text("the week, ").font(.custom("JeniHeroSerif-Regular", size: 78))
            + Text("kept ").font(.custom("JeniHeroSerif-Italic", size: 78))
            + Text("\u{2661}").font(.system(size: 64))
        )
        .foregroundStyle(Color(hex: "#3D2B2B"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateRangeLabel: String {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let monthFmt = DateFormatter()
        if cal.component(.month, from: weekStart) == cal.component(.month, from: weekEnd) {
            // same month → "june 11–17"
            monthFmt.dateFormat = "MMMM d"
            let start = monthFmt.string(from: weekStart).lowercased()
            monthFmt.dateFormat = "d"
            let end = monthFmt.string(from: weekEnd)
            return "\(start)\u{2013}\(end)"
        } else {
            // crosses months → "may 30 – jun 5"
            monthFmt.dateFormat = "MMM d"
            let start = monthFmt.string(from: weekStart).lowercased()
            let end = monthFmt.string(from: weekEnd).lowercased()
            return "\(start) \u{2013} \(end)"
        }
    }

    // MARK: - Grid (2 cols × 3 rows = 6 cells)
    //
    // Per-cell rotations curated for a hand-laid feel: not perfectly
    // alternating, not symmetric — slight bias gives the grid a real-
    // person tilt. Locked so a re-render reproduces the same layout.

    @ViewBuilder private var grid: some View {
        let rotations: [Double] = [-3, 3, -2, 2, -4, 4]
        let padded: [WeeklyShareCell?] = (0..<6).map { i in
            cells.indices.contains(i) ? cells[i] : nil
        }
        VStack(spacing: 34) {
            HStack(spacing: 30) {
                cellView(padded[0], rotation: rotations[0])
                cellView(padded[1], rotation: rotations[1])
            }
            HStack(spacing: 30) {
                cellView(padded[2], rotation: rotations[2])
                cellView(padded[3], rotation: rotations[3])
            }
            HStack(spacing: 30) {
                cellView(padded[4], rotation: rotations[4])
                cellView(padded[5], rotation: rotations[5])
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: WeeklyShareCell?, rotation: Double) -> some View {
        if let cell {
            polaroidCell(cell: cell, rotation: rotation)
        } else {
            // Empty cell — cream block, italic "—" centered. Lets the
            // grid stay 2×3 visually without overclaiming a logged day.
            VStack {
                Spacer()
                Text("\u{2014}")
                    .font(.custom("JeniHeroSerif-Italic", size: 56))
                    .foregroundStyle(Color(hex: "#3D2B2B").opacity(0.22))
                Spacer()
            }
            .frame(width: 480, height: 540)
            .background(Color(hex: "#F7F1E8"))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color(hex: "#3D2B2B").opacity(0.08), lineWidth: 1)
            )
            .rotationEffect(.degrees(rotation))
        }
    }

    @ViewBuilder
    private func polaroidCell(cell: WeeklyShareCell, rotation: Double) -> some View {
        VStack(spacing: 0) {
            // Photo zone (380×380) or title fallback for entries
            // without a stored photo (quick-add / im-out logs).
            ZStack {
                if let photo = photos[cell.entryId] {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 416, height: 416)
                        .clipped()
                } else {
                    Color(hex: "#F5D5D8").opacity(0.55)
                        .frame(width: 416, height: 416)
                    VStack(spacing: 6) {
                        Text(cell.title.isEmpty ? "scanned plate" : cell.title.lowercased())
                            .font(.custom("JeniHeroSerif-Italic", size: 30))
                            .foregroundStyle(Color(hex: "#3D2B2B"))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 28)
                    }
                }
            }
            .frame(width: 416, height: 416)
            .clipped()
            .padding(.top, 16)
            .padding(.horizontal, 16)

            // Bottom matte — italic weekday only. Photo-forward design;
            // we keep numerals + kcal totals OUT (founder anti-shame
            // lock + "share-safe day-card facts" rule on AnalyticsView).
            HStack(spacing: 0) {
                Text(weekdayLabel(for: cell.date))
                    .font(.custom("JeniHeroSerif-Italic", size: 30))
                    .foregroundStyle(Color(hex: "#3D2B2B"))
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 18)
            .padding(.horizontal, 22)
        }
        .frame(width: 448, height: 514)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.11), radius: 9, x: 2, y: 7)
        .rotationEffect(.degrees(rotation))
    }

    private func weekdayLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date).lowercased()
    }

    // MARK: - Pull quote
    //
    // 8 weekly variants — week-of-year mod 8 so a returning sharer
    // doesn't see the same quote two weeks in a row, and the punch
    // word stays italic per [[feedback-voice-signals-locked]].

    @ViewBuilder private var pullQuote: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            (
                Text(quotePart1).font(.custom("JeniHeroSerif-Regular", size: 52))
                + Text(quotePart2).font(.custom("JeniHeroSerif-Italic", size: 52))
                + Text(" \u{2661}").font(.system(size: 44))
            )
            .foregroundStyle(Color(hex: "#3D2B2B"))
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    private var quotePart1: String {
        switch quoteIndex {
        case 0:  return "a week of "         // "a week of *showing up*"
        case 1:  return "quietly "            // "quietly *kept*"
        case 2:  return "no skipping, just " // "no skipping, just *being*"
        case 3:  return "the small "          // "the small *yeses*"
        case 4:  return "soft + "             // "soft + *steady*"
        case 5:  return "becoming, "          // "becoming, *unhurried*"
        case 6:  return "every plate "        // "every plate *counted*"
        default: return "a quiet "            // "a quiet *win*"
        }
    }

    private var quotePart2: String {
        switch quoteIndex {
        case 0:  return "showing up"
        case 1:  return "kept"
        case 2:  return "being"
        case 3:  return "yeses"
        case 4:  return "steady"
        case 5:  return "unhurried"
        case 6:  return "counted"
        default: return "win"
        }
    }

    private var quoteIndex: Int {
        let week = Calendar.current.component(.weekOfYear, from: weekStart)
        return week % 8
    }

    // MARK: - Wordmark

    @ViewBuilder private var wordmark: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("jenifit")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Color(hex: "#C4677A").opacity(0.42))
            Spacer()
        }
    }
}

// MARK: - WeeklyShareCell

/// One cell of the 2×3 weekly collage. Identified by its source food
/// log entryId so the renderer can resolve the stored photo via
/// FoodPhotoStore. `title` is shown only on no-photo fallbacks.
struct WeeklyShareCell: Identifiable {
    let id = UUID()
    let entryId: String
    let date: Date
    let title: String
}

#endif  // canImport(UIKit)
