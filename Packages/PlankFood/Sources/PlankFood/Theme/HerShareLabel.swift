#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - HerShareLabel
//
// v1.0.13 (2026-06-18) — refined share affordance for the her75 /
// jenifit register. Replaces the generic-iOS `square.and.arrow.up`
// in a white circle (founder: "share button alone is still ugly")
// with a cocoa-filled pill carrying a paper-plane glyph + italic
// Fraunces "share" wordmark. Distinctive enough to read as a brand
// element, not a system control; compact enough to fit the tight
// rows the becoming dashboard + lesson reader put it in.
//
// Why a label-only view (not a full Button): every call site needs
// its own action closure + render path + state. Sharing the chrome
// across surfaces stays cleaner if the caller owns the Button and
// just drops this label inside it.
//
// Usage:
//
//     Button(action: shareAction) { HerShareLabel() }
//         .buttonStyle(.plain)
//         .accessibilityLabel("share")
//
// Sizing: 28pt tall × ~78pt wide intrinsic — fits a 32pt circle
// "slot" and reads visually heavier than the previous icon-only.

public struct HerShareLabel: View {

    public init() {}

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 10, weight: .semibold))
                .rotationEffect(.degrees(-12))
            Text("share")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .baselineOffset(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Color(hex: "#3D2A2A"))
        )
        // Soft scrapbook offset shadow (hard-edged, no blur) — matches
        // the chrome the home / settings tiles use elsewhere, signals
        // "this is a jenifit chrome element" without a heavy border.
        .shadow(color: Color(hex: "#3D2A2A").opacity(0.16), radius: 0, x: 1, y: 1.5)
    }
}

// MARK: - HerShareIcon
//
// Compact variant — icon-only, same cocoa fill + offset shadow. For
// surfaces where the wordmark pill would crowd (lesson reader topBar
// already carries back + close icons of similar size; an extra
// labeled pill there reads cluttered).

public struct HerShareIcon: View {

    public init() {}

    public var body: some View {
        Image(systemName: "paperplane.fill")
            .font(.system(size: 13, weight: .semibold))
            .rotationEffect(.degrees(-12))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle().fill(Color(hex: "#3D2A2A"))
            )
            .shadow(color: Color(hex: "#3D2A2A").opacity(0.16), radius: 0, x: 1, y: 1.5)
    }
}

// Color(hex:) extension lives in FoodTheme.swift in the same target;
// reuse it rather than duplicating.

#endif  // canImport(UIKit)
