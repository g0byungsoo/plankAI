#if canImport(UIKit)
import Foundation
import SwiftUI

// MARK: - ResultInsights
//
// v1.0.19 (2026-06-18) — small calculator utilities for the post-scan
// carousel:
//   - ComparativeInsight: ONE honest comparative line per scan,
//     sourced from NHANES / WWEIA Tables 13-36 (women 19-30) per
//     the data agent's honest-comparative pattern lock. Returns nil
//     when no honest claim fires for this scan — we never fabricate.
//   - SatietyEstimate: simple satiety-hours rule of thumb from
//     protein + fiber + kcal, rounded to clean buckets. Lives on
//     slide 3 replacing the trend caption per founder decision.
//
// Both intentionally simple — these are caption-level reads, not the
// hero data. Heroes (calories, kcal-left, protein-today) come from
// the underlying scan.

// MARK: - ComparativeInsight

enum ComparativeInsight {

    /// Returns the single comparative line for this scan, or nil if
    /// no honest claim qualifies. Caller renders nil as "no insight
    /// line on this slide" — restraint > fabrication.
    ///
    /// Priority order per the data agent's framing rules:
    ///   1. Breakfast protein vs NHANES women 19-30 median (~14g)
    ///   2. High-fiber single meal vs daily mean (~17g)
    ///
    /// Sources (long-press affordance later):
    ///   - WWEIA Tables 13-16 (Aug 2017 - Mar 2020), women 19-30
    ///   - NIH ODS Fiber AI (25g/day for women 19-30)
    static func line(
        mealLabel: String,
        proteinG: Int,
        fiberG: Int
    ) -> InsightLine? {
        let meal = mealLabel.lowercased()
        if meal.contains("breakfast"), proteinG >= 18 {
            return InsightLine(
                prefix: "\(proteinG)g protein at breakfast. most women eat about ",
                punch: "14",
                suffix: ".",
                source: .wweia2017to2020Breakfast
            )
        }
        if fiberG >= 8 {
            return InsightLine(
                prefix: "\(fiberG)g fiber in one meal. most women land at ",
                punch: "17",
                suffix: " all day.",
                source: .nhanes2017to2020FiberDaily
            )
        }
        return nil
    }

    struct InsightLine {
        let prefix: String
        let punch: String  // italic-Fraunces accent word
        let suffix: String
        let source: Source
    }

    enum Source: String {
        case wweia2017to2020Breakfast
        case nhanes2017to2020FiberDaily

        var citation: String {
            switch self {
            case .wweia2017to2020Breakfast:
                return "WWEIA / NHANES 2017–2020, Tables 13–16, women 19–30"
            case .nhanes2017to2020FiberDaily:
                return "NHANES 2017–2020, women 19–30"
            }
        }
    }
}

// MARK: - SatietyEstimate
//
// Simple research-tracking estimate (not a clinical claim). Base
// satiety duration extended by protein + fiber per published
// satiety physiology (Weigle 2005 protein → PYY/GLP-1; Holt 1995
// fullness index). Returns a soft range string ("about 4 hours" /
// "3-4 hours") so the line reads as observation, not measurement.

enum SatietyEstimate {

    static func hoursLabel(
        kcal: Int,
        proteinG: Int,
        fiberG: Int
    ) -> String {
        guard kcal > 0 else { return "" }

        // Base 2.5 hours + protein contribution (per Weigle satiety
        // RCTs, 30g protein adds roughly 2h sustained satiety) +
        // fiber contribution (per Holt FullnessIndex, fiber drives
        // ~0.2h per gram in mixed meals).
        let proteinContribution = Double(proteinG) / 12.0
        let fiberContribution = Double(fiberG) / 6.0
        let kcalContribution = max(0, (Double(kcal) - 200) / 600.0)
        let raw = 2.5 + proteinContribution + fiberContribution + kcalContribution
        let clamped = min(max(raw, 1.5), 6.0)
        let rounded = (clamped * 2).rounded() / 2  // half-hour buckets

        if rounded == rounded.rounded() {
            return "about \(Int(rounded)) hours"
        }
        // half-hour case: "3-4 hours"
        let lower = Int(rounded.rounded(.down))
        return "\(lower)–\(lower + 1) hours"
    }
}

#endif  // canImport(UIKit)
