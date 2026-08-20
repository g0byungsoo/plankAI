#if canImport(UIKit)
import SwiftUI

// MARK: - FoodAIConsentSheet
//
// One-time Apple 5.1.2(i) disclosure modal. Fires the first time a user
// taps the food camera, before any photo capture or model call happens.
// Apple's policy expects users to understand when third-party AI is
// processing their data and to have an explicit accept/decline at the
// boundary.
//
// Per sprint W5-T4 + plan §AI disclosure (locked copy):
//   "to read what's on your plate, Jeni shares your photo with
//   vision models from OpenAI and Anthropic. they don't train on
//   your data."
//
// v25 E5 CORRECTION (2026-08-11): the locked copy named a provider the
// pipeline does not call. `supabase/functions/food-vision` reads
// OPENAI_API_KEY and defaults FOOD_VISION_MODEL to gpt-5; there is not
// one reference to Anthropic in any edge function or in PlankFood. A
// consent sheet is the one screen in the product that must be exactly
// true — naming an extra recipient of a user's photo is a trust defect
// on a product whose strategy IS trust. Corrected to name only the
// processor that actually receives the photo. If a second provider is
// ever added, this copy changes in the SAME commit.
//
// Plus a 3-line "what you're agreeing to" detail block — required for
// review credibility but kept short (long disclosure = read as fine
// print = accept-blindly = compliance theatre).
//
// Acceptance persists via AppStorage as a stop-gap. Schema work to
// sync `food_ai_consent_at` into Supabase profile lands in a follow-up
// ticket; the AppStorage value is the source of truth on-device.
// Re-prompt is required if any provider changes (future-proof in
// the policy clause — not enforced by code yet; would key the
// AppStorage flag by provider set hash when that happens).
//
// Decline → onDecline closure runs. CaptureFlowView interprets this
// as "user backed out" and dismisses the capture flow entirely so the
// user lands back on Home. They can re-tap the food card any time to
// see the sheet again.

@MainActor
public struct FoodAIConsentSheet: View {

    /// Pass 52 — the consent speaks the language of the door she is
    /// standing at (photo copy over a typed sentence was the filmed
    /// category error). One acceptance still covers the feature: both
    /// variants disclose both channels (`FoodAIConsentCopy`).
    public let door: FoodAIConsentCopy.Door
    public let onAccept: () -> Void
    public let onDecline: () -> Void

    public init(
        door: FoodAIConsentCopy.Door = .photo,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) {
        self.door = door
        self.onAccept = onAccept
        self.onDecline = onDecline
    }

    // THE REDESIGN (2026-08-12). Founder, in two steps: "this old screen
    // probably needs a major redesign", then the better question — "is
    // that screen fundamentally needed? looking at meagain screens, they
    // have a lot of visual 'how to' instructions for first time users".
    //
    // IS IT NEEDED? Yes, and it cannot simply be deleted. App Review
    // 5.1.2(i) requires explicit consent before user data reaches a third
    // party, and a photograph of someone's dinner going to OpenAI is
    // exactly that. Removing it is a review risk on a build that has
    // already been rejected once.
    //
    // BUT IT WAS DOING ONE JOB WITH A WHOLE SCREEN. A first-time user
    // meets THREE walls before her first photo — this sheet, the food
    // onboarding questions, then the OS camera prompt — and this one
    // taught her nothing. It spent a full takeover on a legal obligation
    // and left the camera to explain itself.
    //
    // So the consent stays and the screen starts earning it. It is a
    // first-run primer now: what actually makes a reading accurate, then
    // the disclosure, then the affirmative accept. Same number of walls,
    // one of which is now the only place the food rail ever teaches.
    //
    // THE THREE TEACHINGS ARE NOT GENERIC TIPS. Each is lifted from a
    // failure mode the vision model names in its own system prompt:
    //   - "food cropped off-frame" is one of its `needs_second_photo`
    //     triggers;
    //   - "if NO usable reference is in frame, widen portion_grams_low/
    //     high and lower confidence — do not fake precision";
    //   - depth is how it sizes a bowl ("a heap ≈ 0.5 × its peak
    //     height"), and a straight-down shot hides it.
    // Following them measurably narrows the range she gets back, which
    // makes this the rare onboarding screen that improves the product's
    // own accuracy rather than only its comprehension.
    //
    // WHAT ELSE CHANGED, and why it was wrong before:
    // ① It said everything twice. The paragraph read "jeni sends the
    //    photo to OpenAI's vision model. they don't train on your data."
    //    and the card below restated both, so the ONE fact that was new —
    //    the photo is deleted afterwards — sat third in a list that had
    //    already taught her to skim.
    // ② An outlined card with a hard drop shadow is v1 scrapbook chrome;
    //    no current Jeni surface draws one. That shadow also cast from
    //    every GLYPH rather than the card (SwiftUI applies `.shadow` per
    //    primitive without `compositingGroup`), so all three rows were
    //    painted twice, 3pt down and right. Filmed, stable across
    //    seconds. It shipped on the one screen this file's header says
    //    must be exactly right.
    // ③ Rose checkmarks were decoration AND the wrong sign: a filled
    //    check reads "agreed" on a screen where she has agreed to
    //    nothing yet. Rose is the DATA hue (design law §3).
    // ④ ~40% dead space, with the content floating in the middle of it.
    // ⑤ `.system(size:)` on the body, the rows and "not now".
    //
    // UNCHANGED: the accept/decline contract, `aiConsentShown`, the
    // AppStorage keys, and the rule that this names exactly the one
    // processor that receives the photo and no other.

    private struct Teaching: Identifiable {
        let id: Int
        let mark: PrimerMark
        let line: String
    }

    private static let teachings: [Teaching] = [
        Teaching(id: 0, mark: .wholePlate, line: "get the whole plate in frame"),
        Teaching(id: 1, mark: .scale, line: "leave something for scale \u{00B7} a fork, your hand"),
        Teaching(id: 2, mark: .angle, line: "shoot at a slight angle, not straight down"),
    ]

    public var body: some View {
        let header = FoodAIConsentCopy.header(for: door)
        let facts = FoodAIConsentCopy.facts(for: door)
        let factsLabel = FoodAIConsentCopy.factsLabel(for: door)
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // SCROLLS. The teachings plus a disclosure plus a hero
                // does not fit an SE at AX5, and a consent a person
                // cannot reach the bottom of is not consent. Founder
                // steer (pass 52, filmed): the words variant left more
                // than half the page dead between the facts and the
                // CTA — short content now settles at the page's optical
                // center (the promise ticket's balanced-spacer law)
                // while tall content scrolls exactly as before.
                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 8)

                            ItalicAccentText(
                                header.text,
                                italic: [header.italic],
                                baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                                color: FoodTheme.textPrimary,
                                alignment: .leading
                            )

                            Text(FoodAIConsentCopy.subline(for: door))
                                .font(.custom("DMSans-Regular", size: 16, relativeTo: .body))
                                .foregroundStyle(FoodTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 12)

                            // The framing teachings are photographic
                            // advice; they render only where a photograph
                            // is about to be taken (the words door gets
                            // none).
                            if FoodAIConsentCopy.showsTeachings(for: door) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Self.teachings) { t in
                                        teachingRow(t)
                                    }
                                }
                                .padding(.top, 20)
                            }

                            // THE DISCLOSURE, in the receipt grammar the
                            // rest of the product keeps: an editorial
                            // eyebrow, then each fact as its own
                            // hairline-ruled row. The one screen that
                            // must be exactly true reads like the
                            // record it protects.
                            Text(factsLabel)
                                .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
                                .tracking(0.8)
                                .foregroundStyle(FoodTheme.textSecondary)
                                .textCase(.uppercase)
                                .padding(.top, 28)

                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(facts.enumerated()), id: \.offset) { i, fact in
                                    if i > 0 { hairline }
                                    Text(fact)
                                        .font(.custom("DMSans-Regular", size: 15, relativeTo: .callout))
                                        .foregroundStyle(FoodTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 13)
                                }
                            }
                            .padding(.top, 6)
                            // One element, one sentence. A disclosure read
                            // aloud as three unrelated items is how somebody
                            // using VoiceOver loses the shape of what they
                            // are agreeing to.
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                factsLabel + ". " + facts.joined(separator: ". ")
                            )

                            Spacer(minLength: 12)
                        }
                        // Short content centers between the safe top and
                        // the docked CTA; tall content overflows into a
                        // scroll, unchanged.
                        .frame(minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                VStack(spacing: 4) {
                    Button(action: onAccept) {
                        Text("accept")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                            .foregroundStyle(FoodTheme.bgPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(FoodTheme.textPrimary)
                            .clipShape(Capsule())
                    }
                    Button(action: onDecline) {
                        Text("not now")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                            .foregroundStyle(FoodTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FoodTheme.Space.lg)
            .padding(.top, FoodTheme.Space.lg)
            .padding(.bottom, 12)
        }
        .onAppear {
            FoodAnalytics.track(.aiConsentShown)
        }
    }

    @ViewBuilder
    private func teachingRow(_ t: Teaching) -> some View {
        HStack(alignment: .center, spacing: 16) {
            PrimerMarkView(kind: t.mark)
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
            Text(t.line)
                .font(.custom("DMSans-Regular", size: 15, relativeTo: .callout))
                .foregroundStyle(FoodTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.line)
    }

    private var hairline: some View {
        Rectangle()
            .fill(FoodTheme.textPrimary.opacity(0.1))
            .frame(height: 0.75)
    }
}

// MARK: - Consent storage key
//
// MARK: - The drawn marks
//
// Hairline ink, no fill, no icon font — the same idiom as the scan
// chooser's `EmptyPlateDoor` and the body door, which are the two
// drawn marks the product already ships. Borrowed rather than invented
// so the primer and the door it leads to speak one language.
//
// Deliberately NOT SF Symbols: this is a brand surface, and a camera
// glyph would be a picture of a phone rather than a picture of the
// thing she should do.

enum PrimerMark {
    /// The whole plate inside the capture window.
    case wholePlate
    /// A plate with a fork beside it: a known size in frame.
    case scale
    /// The plate seen from a slight angle, so it has depth.
    case angle
}

struct PrimerMarkView: View {
    let kind: PrimerMark

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let ink = FoodTheme.textPrimary
            ZStack {
                switch kind {
                case .wholePlate:
                    // Straight-on: the plate is a CIRCLE. Row three is
                    // the same plate as an ellipse, so the two marks
                    // teach the difference between them by standing
                    // three lines apart.
                    plate(d: d, foreshortened: false, ink: ink)
                    brackets(d: d, ink: ink)

                case .scale:
                    plate(d: d, foreshortened: false, ink: ink)
                        .offset(x: -d * 0.13)
                    ForkMark()
                        .stroke(ink.opacity(0.42),
                                style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                        .frame(width: d * 0.15, height: d * 0.58)
                        .offset(x: d * 0.27)

                case .angle:
                    plate(d: d, foreshortened: true, ink: ink)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The plate, drawn once. `foreshortened` is the whole teaching of
    /// row three: from a slight angle a circle becomes an ellipse and
    /// the food on it gains a height the model can size. From directly
    /// above it does not, which is why a straight-down photograph comes
    /// back with a wider range.
    @ViewBuilder
    private func plate(d: CGFloat, foreshortened: Bool, ink: Color) -> some View {
        let w = d * (foreshortened ? 0.62 : 0.52)
        let h = d * (foreshortened ? 0.30 : 0.52)
        ZStack {
            Ellipse()
                .strokeBorder(ink.opacity(0.30), lineWidth: 1.4)
                .frame(width: w, height: h)
            Ellipse()
                .fill(ink.opacity(0.20))
                .frame(width: w * 0.42, height: h * (foreshortened ? 0.46 : 0.34))
                .offset(x: -w * 0.09, y: -h * 0.04)
            Ellipse()
                .fill(ink.opacity(0.11))
                .frame(width: w * 0.30, height: h * (foreshortened ? 0.34 : 0.24))
                .offset(x: w * 0.16, y: h * 0.15)
        }
    }

    @ViewBuilder
    private func brackets(d: CGFloat, ink: Color) -> some View {
        // Inset so all three marks carry the same optical width. Filmed
        // at full bleed the bracket row read a size larger than the two
        // below it and the column lost its grid.
        let span = d * 0.88
        let corner = span * 0.28
        ForEach(0..<4, id: \.self) { i in
            PrimerCornerBracket()
                .stroke(ink.opacity(0.42),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: corner, height: corner)
                .rotationEffect(.degrees(Double(i) * 90))
                .offset(
                    x: (i == 0 || i == 3 ? -1 : 1) * (span / 2 - corner / 2),
                    y: (i == 0 || i == 1 ? -1 : 1) * (span / 2 - corner / 2)
                )
        }
    }
}

/// One corner of the capture window, drawn top-left and rotated for the
/// other three. Same geometry as the chooser's.
struct PrimerCornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width * 0.34
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// A fork: three tines over a stem.
struct ForkMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tineTop = rect.minY
        let neck = rect.minY + rect.height * 0.34
        for i in 0..<3 {
            let x = rect.minX + rect.width * (0.5 * CGFloat(i))
            p.move(to: CGPoint(x: x, y: tineTop))
            p.addLine(to: CGPoint(x: x, y: neck))
        }
        p.move(to: CGPoint(x: rect.midX, y: neck))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}


// AppStorage stop-gap until the food_ai_consent_at column ships in
// Supabase. Key chosen to match the spec field name so the migration
// is a 1:1 rename.

public enum FoodAIConsent {
    /// AppStorage key — `Bool`. `true` once the user has tapped accept.
    public static let acceptedKey = "foodAIConsentAccepted"
    /// AppStorage key — ISO8601 timestamp string of when accept fired.
    public static let acceptedAtKey = "foodAIConsentAt"

    /// Snapshot read — true if the user has accepted the disclosure at
    /// any point on this device.
    public static func hasAccepted() -> Bool {
        UserDefaults.standard.bool(forKey: acceptedKey)
    }

    /// Mark accepted now. Idempotent.
    public static func markAccepted() {
        UserDefaults.standard.set(true, forKey: acceptedKey)
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: Date()),
                                  forKey: acceptedAtKey)
    }
}

#endif  // canImport(UIKit)
