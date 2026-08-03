import SwiftUI

// MARK: - Stage A beats (docs/app_v8/08_STAGE_A.md)
//
// Two additions to the food act: the supports single-ask (warm
// multi-list, an intake fact only — FR8: nothing renders in-plan,
// jeni recommends nothing) and the shot-day anchor (the flow's ONE
// clinical beat: quiet weekday list, ink selection, no cross-off
// warmth, no stickers, skip is first-class). Register law:
// medication is precise and private; everything else stays jeni.

// MARK: - Supports (all branches, after dietary)

struct OV5SupportsScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(
                title: "do you already take any of these?",
                italic: ["already"],
                sub: "so the plan fits around your real days. jeni recommends nothing here. skip freely."
            )
            OV5MultiList(
                options: [
                    .init(key: "protein_powder", label: "protein powder"),
                    .init(key: "multivitamin", label: "a multivitamin"),
                    .init(key: "vitamin_d", label: "vitamin d"),
                    .init(key: "fiber", label: "fiber"),
                    .init(key: "magnesium", label: "magnesium"),
                    .init(key: "electrolytes", label: "electrolytes"),
                    .init(key: "none", label: "none of these"),
                ],
                selection: $store.supports,
                exclusiveKeys: ["none"]
            )
        }
        .ov5CTA("continue", isEnabled: true) {
            flow.advance()
        }
    }
}

// MARK: - Shot day (GLP-1 current branch; clinical register)

struct OV5ShotDayScreen: View {
    let flow: OV5Flow

    private static let weekdays: [(key: String, word: String)] = [
        ("mon", "monday"), ("tue", "tuesday"), ("wed", "wednesday"),
        ("thu", "thursday"), ("fri", "friday"), ("sat", "saturday"),
        ("sun", "sunday"),
    ]

    var body: some View {
        OV5Screen {
            OV5Header(
                title: "your shot day",
                italic: [],
                sub: "if you'd like jeni to hold the rhythm, dose days shape themselves around it. optional, change anytime."
            )
            // The bespoke block carries its own content inset (the
            // screen's padding wraps OV5Header only — walker frame
            // 09 caught the rows flush to the screen edge).
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Self.weekdays, id: \.key) { day in
                        weekdayLine(day.key, day.word)
                    }
                }
                .padding(.top, 4)

                Text("only you see this. never named in notifications.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)

                Button {
                    flow.store.shotDay = ""
                    Haptics.soft()
                    flow.advance()
                } label: {
                    Text("skip for now")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .underline()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }
            .padding(.horizontal, Space.xl)
        }
        .ov5CTA("continue", isEnabled: !flow.store.shotDay.isEmpty) {
            flow.advance()
        }
    }

    /// The clinical row grammar (RegimenSheet's weekday line): the
    /// rule is the only chrome; selection by ink contrast — no
    /// strike, no sticker, no rose.
    private func weekdayLine(_ key: String, _ word: String) -> some View {
        let picked = flow.store.shotDay
        return Button {
            flow.store.shotDay = key
            Haptics.soft()
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Text(word)
                        .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .body))
                        .foregroundStyle(
                            picked.isEmpty || picked == key
                                ? Palette.textPrimary
                                : Palette.textPrimary.opacity(0.35)
                        )
                    Spacer()
                    if picked == key {
                        Text("your shot day")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 11)
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word)
        .accessibilityAddTraits(picked == key ? [.isButton, .isSelected] : .isButton)
    }
}
