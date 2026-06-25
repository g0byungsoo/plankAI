import SwiftUI
import PlankFood

// MARK: - LessonReaderView
//
// The premium CBT lesson reader. Replaces the legacy
// `JeniMethodRitualView` rendering layer when the new manifest-driven
// content pipeline is in use. Takes a `ScheduledLesson` (from the
// scheduler), resolves it to a `LessonSlot` + optional `CohortVariant`
// from the bundled `LessonManifest`, and plays out the 4-page lesson
// arc in the her75 editorial register.
//
// Visual register:
//   - PaperCanvas (cream + breathing grain) as the background.
//   - Top bar: act mark + page dots, back chevron, close X.
//   - Kicker: DM Sans Medium 11pt, tracked, lowercase ("day 14 · the
//     method").
//   - Headline: InkRevealHeadline (Jeni Hero Serif 38pt + italic punch
//     ink-bleed on appear).
//   - Hairline rule between headline and body.
//   - Body: DM Sans 17pt, lineSpacing 5, textPrimary.
//   - Citation (page 2): DM Sans 11pt, lowercase, kerning 0.4, opacity
//     0.7. Tap to expand into a sheet (TODO v1.0.8).
//   - Optional journal prompt (page 3): scrapbook-chrome card with
//     italic-Fraunces prompt. TextEditor stays local; nothing syncs.
//   - Footer folio: hairline + "the jenifit method · day fourteen".
//   - JFContinueButton docked at the bottom (existing component).
//
// Page transitions:
//   - The page container uses `.id(pageIndex)` + `JFPageTransition.standard`
//     so each advance reads as a turning page (200ms exit + 60ms gap +
//     350ms entrance opacity per the her75 motion vocabulary).
//   - InkRevealHeadline re-fires its bleed on each new page (a stable
//     `.id(pageIndex)` keys both views).
//
// Reduce Motion:
//   - PaperCanvas freezes the grain (time = 0).
//   - InkRevealHeadline snaps progress to 1.
//   - Page transitions still use the opacity asymmetric (no spring).
//
// Accessibility:
//   - VoiceOver reads the kicker → headline → body → citation in order.
//   - Punch words inherit the surrounding sentence (no
//     accessibilityLabel split).
//   - Dynamic Type via Font.custom(_:size:relativeTo:) on Typo tokens.
//   - 44pt tap targets on top-bar chrome.

struct LessonReaderView: View {
    let scheduled: ScheduledLesson
    let slot: LessonSlot
    let variant: CohortVariant?
    var isReread: Bool = false
    let onComplete: () -> Void
    let onSkip: (_ atPageIndex: Int) -> Void

    @State private var pageIndex: Int = {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "uitest.cbt.startPage")
        #else
        return 0
        #endif
    }()
    @State private var citationExpanded: Bool = false
    @State private var savedTick: UInt32 = 0
    @State private var promptDraft: String = ""
    @State private var musicPlayer = RitualMusicPlayer()
    /// v1.0.10 (2026-06-17) — holds the rendered IG-Story share PNG
    /// while the system share sheet is up. Identifiable so .sheet(item:)
    /// drives the lifecycle.
    @State private var quoteShareItem: LessonQuoteShareItem?
    /// v1.0.10 Phase 3 — drives the footer-folio archetype mark
    /// ("the jenifit method · day fourteen · protein day"). Reads
    /// the same AppStorage key the Plan tab + Snap Food chip composer
    /// use, so the lesson reader's contextual mark agrees with the
    /// rest of the surface.
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    /// v1.0.10 — restrictive override; matches PlanView + AnalyticsView.
    @AppStorage("onb_restrictive_food") private var restrictiveFoodFlag: Bool = false
    @AppStorage("onboardingFoodRelationship") private var foodRelationshipKey: String = ""
    // Round-8 polish: milestone close-confirm + completion bloom state.
    // First X-tap on a milestone lesson sets `closeConfirmAt`; a second
    // tap within 2s actually dismisses. Prevents tapping past an
    // act-closing lesson by accident.
    @State private var closeConfirmAt: Date? = nil
    // Brief overlay played when the user finishes the last page of a
    // milestone lesson — a single sparkle + tick-mark fades in, then
    // onComplete fires after ~0.85s so the user sees a moment of
    // closure before the sheet drops.
    @State private var completionBlooming: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [CBTLessonPage] {
        let candidate = variant?.pages ?? slot.pages
        // Defensive empty-fallback: if manifest data is missing,
        // fall back to a one-page apology so the reader never
        // crashes on a misshipped slot.
        return candidate.isEmpty ? [emptyFallback] : candidate
    }

    private var page: CBTLessonPage { pages[pageIndex] }

    var body: some View {
        ZStack {
            // Round-2: act-aware paper tint + breath period.
            PaperCanvas(act: scheduled.act)

            VStack(spacing: 0) {
                topBar

                // Round-4: outer scroll only honored under accessibility
                // text sizes. Standard Dynamic Type renders fixed page —
                // each lesson fits one viewport (PageDimensions budget).
                // Round-6+7: dispatch to LayoutArchetypeView for the
                // 5-archetype system (+ wrap_bleed). Falls back to
                // inline pageBody for legacy anchor types.
                Group {
                    if case let .layoutArchetype(arch, slots) = resolvedAnchor {
                        LayoutArchetypeView(
                            archetype: arch,
                            slots: slots,
                            wrapAttributed: arch == .wrapBleed || arch == .sideBleedHalf
                                ? LessonAttributedBuilder.compose(
                                    headline: page.headline,
                                    italicWords: page.italicWords,
                                    body: page.body,
                                    kicker: page.page == 1 ? page.eyebrow : nil)
                                : nil
                        ) {
                            pageBody
                        }
                    } else {
                        pageBody
                    }
                }
                .id(pageIndex)
                .transition(JFPageTransition.standard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footerFolio
                ctaButton.padding(.top, Space.xs)
            }

            if completionBlooming {
                CompletionBloomOverlay(
                    closingWord: closingWord,
                    subtitle: closingTeaser
                )
                .transition(.opacity)
            }

            if let _ = closeConfirmAt {
                CloseConfirmToast()
                    .padding(.top, 64)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            musicPlayer.play()
            // v1.2 (2026-06-15) — analytics parity with the legacy
            // JeniMethodRitualView so existing funnel queries
            // (diet_education_lesson_viewed / completed / skipped)
            // continue to work for the CBT path. Once-per-presentation
            // gate via `viewedThisPresentation` so SwiftUI re-render
            // doesn't double-emit.
            if !viewedThisPresentation && !isReread {
                viewedThisPresentation = true
                Analytics.track(.dietEducationLessonViewed,
                                properties: cbtAnalyticsProps())
            }
        }
        .onDisappear { musicPlayer.stop() }
        .fullScreenCover(isPresented: $promptSheetOpen) {
            PromptJournalSheet(
                lessonSlotId: slot.id,
                page: page.page,
                promptText: page.prompt ?? ""
            )
        }
        // v1.0.10 (2026-06-17) — share-this-passage system share sheet.
        // Driven by the topBar share button rendering a 1080×1920 IG-
        // Story-format PNG via LessonQuoteRenderer. Sheet auto-dismisses
        // when the system flow completes (cancel + finish both clear
        // quoteShareItem via the completion handler).
        .sheet(item: $quoteShareItem) { item in
            LessonQuoteShareSheet(items: [item.image]) {
                quoteShareItem = nil
            }
            .ignoresSafeArea()
        }
        #if DEBUG
        .onAppear {
            // QA hook — open the prompt sheet immediately when launched
            // with `--uitest-cbt-open-prompt 1`. Used by the simctl
            // screenshot harness to capture the sheet without UI
            // automation.
            if UserDefaults.standard.bool(forKey: "uitest.cbt.openPrompt"),
               page.prompt != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    promptSheetOpen = true
                }
            }
        }
        #endif
    }

    @State private var promptSheetOpen: Bool = false
    /// Guard against re-emitting `diet_education_lesson_viewed` on
    /// SwiftUI re-renders. The legacy reader uses a per-day
    /// UserDefaults gate; here we keep it presentation-scoped — a
    /// re-open is treated as a new view.
    @State private var viewedThisPresentation: Bool = false

    /// CBT-flavored analytics properties. Maps to the same event names
    /// used by `JeniMethodAnalytics.lessonProps` so funnel queries
    /// (filter by `lesson_id`, group by `lesson_topic`) work across
    /// both readers. Adds `pillar_id`, `act_id`, `program_day` as the
    /// new CBT dimensions.
    private func cbtAnalyticsProps() -> [String: Any] {
        var p: [String: Any] = [
            "lesson_id":     slot.id,
            "lesson_topic":  slot.workingTitle,
            "program_day":   scheduled.programDay,
            "pillar_id":     scheduled.primaryPillar.rawValue,
            "act_id":        scheduled.act,
            "reader":        "cbt_v1",
            // v1.0.10 Phase 5 — archetype match telemetry. Tracks how
            // often the deterministic schedule lands a pillar-aligned
            // lesson on the right archetype day (e.g. P2 hunger/satiety
            // on a protein day, P3 self-compassion on a rest day).
            // Unblocks the question "do we need a scheduler bias pass,
            // or is the existing schedule already well-aligned by
            // accident?" Both properties are pure derivations of the
            // existing ScheduledLesson + onboarding_glp1_status —
            // additive, no persistence change.
            "today_archetype": todayArchetype.rawValue,
            "archetype_match": archetypeMatches,
        ]
        if let variant {
            p["cohort_variant"] = variant.cohort
        }
        if scheduled.isMilestone {
            p["is_milestone"] = true
        }
        return p
    }

    /// v1.0.10 Phase 5 — today's archetype for this program day with
    /// the user's GLP-1 cohort applied. Single source of truth for both
    /// the folio mark and the analytics props, so they can never drift.
    private var todayArchetype: ProgramDayArchetype {
        ProgramDayArchetype.archetype(
            forProgramDay: scheduled.programDay,
            glp1Status: glp1Status,
            restrictiveFoodRelationship: isRestrictiveCohort
        )
    }

    private var isRestrictiveCohort: Bool {
        if restrictiveFoodFlag { return true }
        return ["control", "complicated"].contains(foodRelationshipKey.lowercased())
    }

    /// True when the lesson's primary pillar has the same archetype
    /// affinity as today's archetype. Drives the folio mark upgrade
    /// ("protein-day support") AND the analytics `archetype_match`
    /// property so a PostHog funnel can measure schedule alignment.
    private var archetypeMatches: Bool {
        slot.primaryPillar.archetypeAffinity == todayArchetype
    }

    /// Round-4 anchor resolution — delegates to `LessonSlot.resolvedAnchor(forPage:)`
    /// which handles override > slot default > legacy migration > fallback.
    private var resolvedAnchor: LessonAnchor {
        slot.resolvedAnchor(forPage: page.page)
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            HStack(spacing: PageDimensions.pageDotSpacing) {
                ForEach(0..<pages.count, id: \.self) { i in
                    if i <= pageIndex {
                        Circle().fill(Palette.cocoaPrimary)
                            .frame(width: PageDimensions.pageDotDiameter,
                                   height: PageDimensions.pageDotDiameter)
                    } else {
                        Circle().stroke(Palette.divider, lineWidth: 1.0)
                            .frame(width: PageDimensions.pageDotDiameter,
                                   height: PageDimensions.pageDotDiameter)
                    }
                }
            }
            .accessibilityLabel("page \(pageIndex + 1) of \(pages.count)")

            HStack {
                if pageIndex > 0 {
                    Button {
                        Haptics.light()
                        withAnimation(Motion.pageEntrance) { pageIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary.opacity(0.7))
                            .frame(width: PageDimensions.chevronSize,
                                   height: PageDimensions.chevronSize)
                            .background(Circle().fill(Color.white.opacity(0.4)))
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
                // v1.0.10 (2026-06-17) — share-this-passage affordance.
                // Renders the current page's headline + italic punch
                // words as a 1080×1920 her75 quote card, hands the PNG
                // to UIActivityViewController. Pinterest / IG / TikTok
                // bait: the user posts what moved her, JeniFit gets
                // organic acquisition. Hidden until page 1 since the
                // headline reveal-animation needs to land first.
                if pageIndex >= 0 {
                    Button {
                        Haptics.light()
                        if let image = renderLessonShareImage() {
                            quoteShareItem = LessonQuoteShareItem(image: image)
                        }
                    } label: {
                        HerShareIcon()
                    }
                    .accessibilityLabel("share this passage")
                    .padding(.trailing, 6)
                }
                Button {
                    handleCloseTap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textPrimary.opacity(0.7))
                        .frame(width: PageDimensions.chevronSize,
                               height: PageDimensions.chevronSize)
                        .background(Circle().fill(Color.white.opacity(0.4)))
                }
                .accessibilityLabel(scheduled.isMilestone
                                    ? "Close — tap again to confirm"
                                    : "Close")
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, PageDimensions.topBarVPad)
    }

    // MARK: - Share-card derivations
    //
    // Static helpers so the topBar's Button closure can compose the
    // render inputs without taking captures on `self` or duplicating
    // the formatting logic across call sites.

    /// v1.0.13 (2026-06-18) — magazine pull-quote is the only register
    /// for lesson sharing now (founder direction: handwriting reserved
    /// for food photos, lesson shares stay in the JeniFit type system).
    /// HandwrittenLessonQuoteRenderer is dead at the call-site level.
    private func renderLessonShareImage() -> UIImage? {
        let cleanedHeadline = Self.cleanHeadline(page.headline)
        let bodyLine = Self.firstSentence(of: page.body)
        let dayLabel = Self.dayLabel(programDay: scheduled.programDay)
        let pillarLabel = Self.pillarLabel(for: slot.primaryPillar)
        return LessonQuoteRenderer.render(
            headline: cleanedHeadline,
            italicWords: page.italicWords,
            bodyLine: bodyLine,
            dayLabel: dayLabel,
            pillarTitle: pillarLabel
        )
    }

    /// Strip the soft [italic] markers writers use in `workingTitle`
    /// (not on `headline`, but the helper handles both shapes so we
    /// can reuse this if we ever switch the source field).
    static func cleanHeadline(_ raw: String) -> String {
        raw.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
    }

    /// v1.0.12 — multi-sentence body extract for the lesson share
    /// card. Pulls the first 2-3 sentences so the share recipient
    /// has enough context to understand what was learned without
    /// opening the app. Caps the total length so a long lesson
    /// doesn't overflow the share canvas; the cap is character-
    /// based (~340 chars) since DM Sans 36pt with our line-height
    /// fits roughly that much in 4 lines on the 1080×1920 share.
    /// Falls back to the full body when terminal punctuation isn't
    /// found early, returning nil only when the body is empty.
    static func firstSentence(of body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let maxChars = 340
        var collected = ""
        var remaining = Substring(trimmed)
        for _ in 0..<3 {
            if let range = sentenceBoundary(in: remaining) {
                let sentence = remaining[..<range.upperBound]
                let candidate = (collected + sentence)
                    .trimmingCharacters(in: .whitespaces)
                if candidate.count > maxChars {
                    break
                }
                collected = candidate + " "
                remaining = remaining[range.upperBound...]
            } else {
                let candidate = (collected + remaining)
                    .trimmingCharacters(in: .whitespaces)
                collected = candidate.count > maxChars
                    ? collected.trimmingCharacters(in: .whitespaces)
                    : candidate
                break
            }
        }
        let result = collected.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? trimmed : result
    }

    /// First terminal-punctuation boundary in a substring. Used by
    /// `firstSentence(of:)` to walk sentence-by-sentence.
    private static func sentenceBoundary(in s: Substring) -> Range<Substring.Index>? {
        var best: Range<Substring.Index>? = nil
        for terminator in [". ", "? ", "! "] {
            if let range = s.range(of: terminator) {
                if best == nil || range.lowerBound < best!.lowerBound {
                    best = range
                }
            }
        }
        return best
    }

    /// "day fourteen" — spell-out matches the footer folio's voice
    /// so the share card and the in-app reader agree on register.
    static func dayLabel(programDay: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        let word = f.string(from: NSNumber(value: programDay)) ?? "\(programDay)"
        return "day \(word)"
    }

    /// Friendlier pillar attribution for the share card's bottom-left
    /// signature. The internal `PillarId.debugName` strings are too
    /// clinical for a user-facing surface; these labels match the
    /// editorial register used on the lesson reader's chapter marks.
    static func pillarLabel(for pillar: PillarId) -> String {
        switch pillar {
        case .P1: return "voice + food noise"
        case .P2: return "satiety + hunger"
        case .P3: return "self-compassion"
        case .P4: return "body + identity"
        case .P5: return "sleep + stress"
        case .P6: return "maintenance"
        }
    }

    // MARK: - Page body

    /// Resolves the visual treatment for the current page — checks the
    /// per-page override map, then falls back to the lesson's primary
    /// treatment, then to typographyOnly.
    private var pageTreatment: VisualTreatment {
        if let override = slot.pageTreatmentOverrides?[String(page.page)] {
            return override
        }
        return slot.primaryTreatment ?? .typographyOnly
    }

    @ViewBuilder private var pageBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Round-4 anchor — hero photo renders ABOVE column at 260pt;
            // pinned/twin-corner artifacts already render as background
            // overlay (zero vertical cost); typographyOnly + dingbat
            // render the dingbat above the headline when set.
            if case let .typographyOnly(dingbat?) = resolvedAnchor, page.page == 4 {
                Text(dingbat.glyph)
                    .font(.custom("JeniHeroSerif-Regular", size: 22))
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, Space.lg)
                    .accessibilityHidden(true)
            }

            if case let .singleHeroPhoto(slug, bleed) = resolvedAnchor {
                HeroPhotoAnchorView(slug: slug, bleed: bleed)
                    .frame(height: PageDimensions.visualHeight(for: resolvedAnchor))
                    .padding(.bottom, Space.md)
            }

            Spacer().frame(height: Space.md)

            // Round-4 K2: eyebrow kicker only on P1; subsequent pages
            // let the dots in the top bar do that work.
            if page.page == 1, let eyebrow = page.eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.lowercased())
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(1.98)
                    .foregroundStyle(Palette.textSecondary)
                Spacer().frame(height: Space.sm)
            }

            InkRevealHeadline(
                headline: page.headline,
                italicWords: page.italicWords,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary
            )

            // Round-4 K3: hairline divider collapses to 0.75pt width-56,
            // tight vertical gutter (was 32pt total, now 22pt).
            Rectangle()
                .fill(Palette.divider)
                .frame(width: PageDimensions.hairlineWidth,
                       height: PageDimensions.hairlineThickness)
                .padding(.vertical, PageDimensions.hairlineVGutter)

            // Body text — long-press-to-save a sentence drops a
            // cocoa pin-dot in the margin. The full body sentence
            // long-press flow is implemented as a single-region tap
            // affordance in round-2 (sentence-level slicing deferred
            // to round 3 — needs Text.Layout API + AttributedString
            // tagging to be perf-safe).
            // Round-4 K4: body 17→16pt, lineSpacing 5→4.
            Text(renderBody(page.body))
                .font(.custom("DMSans-Regular", size: PageDimensions.bodyFontSize, relativeTo: .body))
                .lineSpacing(PageDimensions.bodyLineSpacing)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .overlay(alignment: .leading) {
                    SaveLinePinDot(active: bodyIsSaved)
                        .padding(.leading, -18)
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    Haptics.soft()
                    toggleBodySaved()
                }
                .accessibilityAction(named: bodyIsSaved ? "unsave passage" : "save passage") {
                    toggleBodySaved()
                }

            if let citation = page.citation, !citation.isEmpty {
                CitationChip(citation: citation, expanded: $citationExpanded)
                    .padding(.top, Space.md)
            }

            // Round-5g inline scrapbook sticker retired in round-6
            // (LayoutArchetypeView wraps the pageBody for the new
            // 5-archetype dispatch). Keeping the round-5 fallback for
            // any lesson still on .scrapbookSpread anchor.
            if case let .scrapbookSpread(_, slots) = resolvedAnchor,
               let slot = slots.first {
                InlineSticker(slug: slot.assetSlug,
                              size: 140,
                              rotation: slot.rotationDeg)
                    .padding(.top, Space.lg)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let breath = page.breathLine, !breath.isEmpty {
                Text(breath.lowercased())
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.md)
            }

            // Round-4 K7: prompt page now shows only the question + a
            // "write" chip; tapping lifts the PencilKit pad as a sheet.
            if let prompt = page.prompt, !prompt.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(prompt.lowercased())
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Haptics.light()
                        promptSheetOpen = true
                    } label: {
                        Text("write")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .overlay(
                                Capsule().stroke(Palette.cocoaPrimary.opacity(0.45), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Space.md)
            }

            Spacer().frame(height: Space.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
    }

    /// Round-4: visualTreatmentAbove + suppressesStandardHeadline
    /// retired. Anchor dispatch lives directly in pageBody now.
    /// Keeping the function below as a back-compat shim returning a
    /// no-op for any callers that may still reference it during the
    /// round-3→round-4 migration window.
    @ViewBuilder private var visualTreatmentAbove: some View {
        EmptyView()
    }

    private var suppressesStandardHeadline: Bool {
        pageTreatment == .heroPhotoBleed
    }

    // MARK: - Save-line state (round-2 long-press-to-save primitive)

    private var saveKey: String { "jenimethod.savedline.\(slot.id).\(page.page)" }
    private var bodyIsSaved: Bool {
        UserDefaults.standard.bool(forKey: saveKey)
    }
    private func toggleBodySaved() {
        let next = !bodyIsSaved
        UserDefaults.standard.set(next, forKey: saveKey)
        // Force re-render — the overlay reads UserDefaults synchronously
        // but SwiftUI doesn't observe UserDefaults; toggling a state
        // var keeps the pin-dot in sync visually.
        savedTick &+= 1
    }

    /// Soft AttributedString pass — italic-punch body words (when the
    /// page body opts in via inline [brackets] or *markdown* markers)
    /// get a Fraunces italic run. Otherwise this is identity. Keeps
    /// the body rendering pipe flexible without forcing every writer
    /// to think about runs.
    private func renderBody(_ raw: String) -> AttributedString {
        var output = AttributedString()
        var cursor = raw.startIndex
        // Single-pass tokenizer that accepts `[…]` brackets OR `*…*`
        // markdown-italic delimiters. Whichever the writer used, the
        // inner phrase gets the italic Fraunces run; the delimiters
        // are consumed.
        while cursor < raw.endIndex {
            // Find the next opening marker of either kind.
            let nextBracket = raw.range(of: "[", range: cursor..<raw.endIndex)
            let nextStar    = raw.range(of: "*", range: cursor..<raw.endIndex)
            let open: (Range<String.Index>, Character)?
            switch (nextBracket, nextStar) {
            case (.some(let b), .some(let s)):
                open = b.lowerBound < s.lowerBound ? (b, "[") : (s, "*")
            case (.some(let b), .none): open = (b, "[")
            case (.none, .some(let s)): open = (s, "*")
            default: open = nil
            }
            guard let (openRange, marker) = open else {
                output.append(AttributedString(String(raw[cursor..<raw.endIndex])))
                break
            }
            let closeChar: Character = marker == "[" ? "]" : "*"
            // Emit leading text.
            if cursor < openRange.lowerBound {
                output.append(AttributedString(String(raw[cursor..<openRange.lowerBound])))
            }
            // Find the matching close.
            guard let close = raw.range(of: String(closeChar),
                                        range: openRange.upperBound..<raw.endIndex) else {
                // No close — emit the rest literally minus the orphan marker.
                output.append(AttributedString(String(raw[openRange.upperBound..<raw.endIndex])))
                break
            }
            let inner = raw[openRange.upperBound..<close.lowerBound]
            var italic = AttributedString(String(inner))
            italic.font = .custom("Fraunces72pt-SemiBoldItalic", size: 17)
            output.append(italic)
            cursor = close.upperBound
        }
        return output
    }

    @ViewBuilder
    private func promptCard(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(prompt.lowercased())
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // v2 of the prompt response surface — handwriting by default
            // (PencilKit), keyboard as fallback. Founder QA 2026-06-13:
            // the type-only pad shipped white-on-white in dark mode
            // (text color inherited system default). JournalingPad
            // forces cocoa in both modes + offers writing as the
            // primary register, which suits the magazine-artifact voice.
            JournalingPad(lessonSlotId: slot.id, page: page.page)
        }
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.accent.opacity(0.35), lineWidth: 1.2)
        )
    }

    // MARK: - Footer folio

    private var footerFolio: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.divider).frame(height: 1)
                .padding(.horizontal, Space.lg)
            HStack {
                Text(folioLine)
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(1.98)
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
                Spacer()
                Text("\(pageIndex + 1) / \(pages.count)")
                    .font(.custom("DMSans-Medium", size: 11))
                    .kerning(0.4)
                    .foregroundStyle(Palette.textSecondary.opacity(0.55))
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, 10)
        }
    }

    private var folioLine: String {
        let day = scheduled.programDay
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        let dayWord = f.string(from: NSNumber(value: day)) ?? "\(day)"
        // Append the day's archetype to the folio mark. Pillar-aligned
        // lessons (P2 on protein, P3 on rest, P5 on movement) get the
        // upgraded "support" mark; others get the plain archetype tag.
        // `todayArchetype` + `archetypeMatches` are shared with the
        // analytics props so the folio + telemetry can never diverge.
        let archetypeMark = archetypeMatches
            ? " · \(todayArchetype.rawValue)-day support"
            : " · \(todayArchetype.rawValue) day"
        return "the jenifit method · day \(dayWord)\(archetypeMark)"
    }

    // MARK: - Completion close

    /// The ink-bleed closing word on the completion bloom. "noted." is
    /// the CBT-journal register — a clinician's chart annotation, not a
    /// celebration pop (medical-grade-over-soft).
    private var closingWord: String { "noted." }

    /// A quiet teaser under the closing word. Opens the loop the D1
    /// morning "continue" push closes (Zeigarnik). True to what ships —
    /// a new lesson lands tomorrow — so it promises nothing unbuilt.
    private var closingTeaser: String { "tomorrow, the next one \u{2661}" }

    // MARK: - CTA

    @ViewBuilder private var ctaButton: some View {
        let isLast = pageIndex == pages.count - 1
        let label = isLast
            ? (page.ctaLabel.isEmpty ? "done for today" : page.ctaLabel.lowercased())
            : (page.ctaLabel.isEmpty ? "continue" : page.ctaLabel.lowercased())
        JFContinueButton(label: label) {
            if isLast {
                if !isReread {
                    Haptics.success()
                    // Completion analytic — fires once per first read of a
                    // lesson (mirrors the !isReread gate on
                    // diet_education_lesson_viewed so viewed→completed is an
                    // apples-to-apples funnel). The legacy ritual reader was
                    // the only emitter before this, so the event had fired
                    // ~once ever despite 400+ viewers on the CBT path.
                    Analytics.track(.dietEducationCompleted,
                                    properties: cbtAnalyticsProps())
                    // v1.1.2 (2026-06-24) — the earned close now plays
                    // for EVERY lesson, not just milestones: a single
                    // cocoa sparkle + an ink-bleed closing word + a quiet
                    // "tomorrow" teaser that opens the loop the D1 morning
                    // "continue" push closes. The hold lets the ink settle
                    // before the reader dissolves home — no hard snap-back
                    // to the checklist. Still no sticker scatter (reserved
                    // for welcome/plan-reveal/graduation per the rule).
                    if !reduceMotion {
                        withAnimation(Motion.bloom) { completionBlooming = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                            onComplete()
                        }
                    } else {
                        onComplete()
                    }
                } else {
                    onComplete()
                }
            } else {
                Haptics.soft()
                withAnimation(Motion.pageEntrance) { pageIndex += 1 }
            }
        }
    }

    // MARK: - Close confirmation (milestone lessons)

    /// Fires the skip-event analytics with the page where the user
    /// abandoned, then dismisses through the host's onSkip callback.
    /// Single helper so both the non-milestone path and the confirmed-
    /// milestone path emit identically.
    private func emitSkipAndDismiss() {
        if !isReread {
            var p = cbtAnalyticsProps()
            p["screen"] = String(pageIndex)
            Analytics.track(.dietEducationSkipped, properties: p)
        }
        onSkip(pageIndex)
    }

    private func handleCloseTap() {
        guard scheduled.isMilestone else {
            Haptics.light()
            emitSkipAndDismiss()
            return
        }
        if let last = closeConfirmAt, Date().timeIntervalSince(last) < 2.5 {
            Haptics.light()
            emitSkipAndDismiss()
        } else {
            Haptics.medium()
            withAnimation(Motion.bloom) { closeConfirmAt = Date() }
            // Auto-clear the prompt after the confirmation window so
            // the toast doesn't linger forever if the user wanders.
            let stamped = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                if closeConfirmAt == stamped {
                    withAnimation(Motion.exit) { closeConfirmAt = nil }
                }
            }
        }
    }

    // MARK: - Fallback

    // MARK: - Save-line pin-dot + citation chip helpers

    private var emptyFallback: CBTLessonPage {
        CBTLessonPage(
            page: 1,
            kind: "close",
            eyebrow: "today",
            headline: "we'll be back here tomorrow.",
            italicWords: ["tomorrow"],
            body: "this lesson is loading new content. tap done and we'll catch you tomorrow with the next one.",
            citation: nil, breathLine: nil, dataTie: nil, prompt: nil,
            ctaLabel: "done for today"
        )
    }
}

// MARK: - InlineSticker
//
// Round-5g: a simple inline sticker the reader drops AFTER the body
// text + citation. SwiftUI's VStack layout guarantees this sits below
// the body — no absolute positioning, no overlap risk. Stickers
// render at a recognizable ~140pt size with a small rotation +
// bloom-in entrance. Reduce-motion safe.

struct InlineSticker: View {
    let slug: String
    var size: CGFloat = 140
    var rotation: Double = 0
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Perf: SwiftUI Image(_:) avoids per-body-recompute UIImage
        // cache hits on the main thread.
        Image(slug)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .shadow(color: Palette.cocoaPrimary.opacity(0.08),
                    radius: 8, x: 0, y: 4)
            .opacity(bloomed || reduceMotion ? 1 : 0)
            .scaleEffect(bloomed || reduceMotion ? 1.0 : 0.92, anchor: .center)
            .accessibilityHidden(true)
            .onAppear {
                if reduceMotion { bloomed = true }
                else {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)
                                    .delay(0.4)) { bloomed = true }
                }
            }
    }
}

// MARK: - SaveLinePinDot
//
// Small cocoa pin-dot that appears in the body's left margin when the
// passage is "saved". The dot fades in with a soft scale-pop on first
// activation, sits quietly thereafter. Tied to UserDefaults via the
// reader's saveKey scoped by (slot, page).

struct SaveLinePinDot: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(Palette.cocoaPrimary)
            .frame(width: 6, height: 6)
            .opacity(active ? 1 : 0)
            .scaleEffect(active ? 1.0 : 0.6, anchor: .center)
            .animation(reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.78),
                       value: active)
            .accessibilityHidden(true)
    }
}

// MARK: - CitationChip
//
// Round-2 interactive primitive — tap-to-reveal-citation. The
// collapsed state is the existing single-line lowercase citation;
// tapping expands a soft cocoa-outline chip with the full citation
// + a "research" hint. Pure cosmetic in v1 — full author-info sheet
// (DOI link, abstract, etc) is a round-3 surface.

struct CitationChip: View {
    let citation: String
    @Binding var expanded: Bool

    var body: some View {
        Button {
            Haptics.light()
            withAnimation(.easeInOut(duration: 0.28)) { expanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: expanded ? "book.closed.fill" : "book.closed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.textSecondary.opacity(0.85))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(citation.lowercased())
                        .font(.custom("DMSans-Medium", size: 11))
                        .kerning(0.4)
                        .foregroundStyle(Palette.textSecondary.opacity(0.85))
                        .multilineTextAlignment(.leading)
                    if expanded {
                        Text("real study, peer-reviewed. tap again to collapse.")
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(expanded ? 0.55 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.divider.opacity(expanded ? 0.9 : 0.0), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "collapse citation" : "expand citation: \(citation)")
    }
}

// MARK: - CompletionBloomOverlay
//
// Brief closure beat for milestone lessons. Single Fraunces sparkle
// (✦) glyph fades + scales up in the center of the canvas, holds
// ~500ms, fades. Soft cream wash behind so the underlying lesson
// quiets without going dark. NO sticker scatter — that's reserved
// for welcome / plan reveal / graduation only.

struct CompletionBloomOverlay: View {
    var closingWord: String = "noted."
    var subtitle: String? = nil

    @State private var bloomed = false
    @State private var subtitleIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Palette.bgPrimary.opacity(0.62))
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text("✦")
                    .font(.custom("JeniHeroSerif-Regular", size: 52))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .opacity(bloomed ? 1 : 0)
                    .scaleEffect(bloomed ? 1.0 : 0.6)

                // The closing word wicks in like wet ink on paper — the
                // dormant inkBleedReveal Metal shader, finally lit.
                InkBleedClosingWord(word: closingWord)

                if let subtitle {
                    Text(subtitle)
                        .font(.custom("DMSans-Medium", size: 13))
                        .kerning(0.3)
                        .foregroundStyle(Palette.textSecondary)
                        .opacity(subtitleIn ? 1 : 0)
                        .offset(y: subtitleIn ? 0 : 6)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                bloomed = true
            }
            guard subtitle != nil else { return }
            let delay = reduceMotion ? 0.0 : 0.55
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.45)) { subtitleIn = true }
            }
        }
    }
}

// MARK: - InkBleedClosingWord
//
// Lights the compiled-but-dormant `inkBleedReveal` Metal shader: the
// word's pixels are revealed by a jagged, fbm-warped radial mask that
// grows from the center over ~0.5s, so the word bleeds in like ink
// wicking across uncoated paper. Reduce-Motion renders a plain Text
// (the shader at progress=1 on an unmeasured frame would be blank).
private struct InkBleedClosingWord: View {
    let word: String
    @State private var progress: CGFloat = 0
    @State private var measured: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Text(word)
                .font(.custom("JeniHeroSerif-Italic", size: 23))
                .foregroundStyle(Palette.textPrimary.opacity(0.88))
        } else {
            Text(word)
                .font(.custom("JeniHeroSerif-Italic", size: 23))
                .foregroundStyle(Palette.textPrimary.opacity(0.88))
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { measured = geo.size }
                    }
                )
                .colorEffect(
                    ShaderLibrary.inkBleedReveal(
                        .float(Float(progress)),
                        .float2(Float(measured.width / 2), Float(measured.height / 2)),
                        .float2(Float(measured.width), Float(measured.height)),
                        .float(7)
                    )
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        withAnimation(.easeOut(duration: 0.5)) { progress = 1 }
                    }
                }
        }
    }
}

// MARK: - CloseConfirmToast
//
// Soft cocoa-outlined pill toast pinned near the top — appears after
// the first X-tap on a milestone lesson; tells the user a second tap
// will dismiss. Self-clears after 2.7s if untouched.

struct CloseConfirmToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
            Text("tap close again to leave this lesson")
                .font(.custom("DMSans-Medium", size: 12))
                .kerning(0.2)
                .foregroundStyle(Palette.textPrimary.opacity(0.88))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Palette.divider, lineWidth: 0.8)
        )
        .shadow(color: Palette.cocoaPrimary.opacity(0.10), radius: 8, x: 0, y: 4)
        .accessibilityLabel("tap close again to leave the lesson")
    }
}

#if DEBUG
#Preview("LessonReaderView · day 1") {
    let manifest = LessonManifest.stubForPreview
    let slot = manifest.canonical84.first!
    return LessonReaderView(
        scheduled: ScheduledLesson(
            programDay: 1, lessonSlotId: slot.id, primaryPillar: .P1,
            pillarIds: [.P1], act: 1, isMilestone: true, isActClosing: false,
            isDataAware: false, isVoiceNoteEligible: true, isBreathRitual: false,
            isJournalPrompt: false, manifestVersion: 0
        ),
        slot: slot,
        variant: nil,
        onComplete: {},
        onSkip: { _ in }
    )
}
#endif
