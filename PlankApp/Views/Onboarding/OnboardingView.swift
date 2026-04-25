import SwiftUI
import AVFoundation

// MARK: - Onboarding Flow
// Interleaved: 2-3 questions → education/celebration → repeat
// Every question requires Continue. Instant feedback on answers.
// Gradient blobs + animated SF Symbols + photo slots for stock images.

struct OnboardingView: View {
    @State private var screen = -1  // -1 = splash
    @State private var dir = 1
    @State private var visible = false
    @State private var feedback = ""
    @State private var showFeedback = false
    @State private var showConfetti = false

    // Data
    @State private var goal = ""
    @State private var experience = ""
    @State private var baseline = ""
    @State private var barriers: Set<String> = []
    @State private var ageRange = ""
    @State private var activityLevel = ""
    @State private var focusArea = ""
    @State private var plankTime = ""
    @State private var commitmentDays = ""
    @State private var notificationsEnabled = false
    @State private var notificationTime = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
    @State private var name = ""
    @State private var voicePreference = "keepItReal"

    // Analyze
    @State private var analyzing = false
    @State private var analyzePercent = 0
    @State private var planRevealed = false
    @State private var chartAnimated = false
    @State private var proofCount = 0
    @State private var celebVisible = false

    // Education screen animations
    @State private var factVisible = false
    @State private var featureVisible = false
    @State private var beforeAfterVisible = false
    @State private var personalStatVisible = false

    let onComplete: (OnboardingData) -> Void
    private let total = 25

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if screen >= 1 && !analyzing && screen != 20 {
                    navBar.transition(.opacity)
                }
                Spacer().frame(height: screen < 1 ? 0 : Space.sm)


                currentScreen
                    .id(screen)
                    .transition(.asymmetric(
                        insertion: .move(edge: dir > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: dir > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
            }

            if analyzing { analyzingScreen.transition(.opacity).zIndex(10) }

            // Centered feedback interstitial
            if showFeedback {
                ZStack {
                    Palette.bgPrimary.opacity(0.95).ignoresSafeArea()
                    VStack(spacing: Space.md) {
                        Text("✓")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Palette.accent)
                            .clipShape(Circle())

                        Text(feedback)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.opacity)
                .zIndex(15)
            }

            if showConfetti { ConfettiView().ignoresSafeArea().allowsHitTesting(false).zIndex(20) }
        }
    }

    private func showToast(_ msg: String) {
        feedback = msg
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showFeedback = true }
        Haptics.soft()
    }

    private func hideToast() {
        withAnimation(.easeOut(duration: 0.2)) { showFeedback = false }
    }

    // Flow (25 screens):
    // 0:  Welcome
    // 1:  Q — Goal
    // 2:  Q — Experience
    // 3:  Q — Baseline (skip if never)
    // 4:  E — Chart ("most quit at 20s")
    // 5:  Q — Barriers
    // 6:  C — Personalized celebration
    // 7:  Q — Age range
    // 8:  Q — Activity level
    // 9:  E — "Did you know" core fact
    // 10: Q — Focus area
    // 11: Q — When do you plank
    // 12: E — Form vs Time
    // 13: E — What makes us different (feature showcase)
    // 14: S — Social proof (counter)
    // 15: S — Testimonial
    // 16: E — Before/after stat
    // 17: Q — Commitment (days/week)
    // 18: Q — Name
    // 19: Trainer selector
    // 20: Analyzing
    // 21: Plan reveal
    // 22: E — Personalized stat
    // 23: Camera setup
    // 24: Paywall

    @ViewBuilder private var currentScreen: some View {
        switch screen {
        case -1: splashScreen
        case 0: welcome

        case 1: questionView("What do you want\nto achieve?", sub: "We'll build your plan around this.", opts: [
            ("strength", "💪  Stronger core"), ("posture", "🧍‍♀️  Better posture"),
            ("confidence", "✨  Feel more confident"), ("toned", "🔥  Get toned"),
        ], sel: $goal, feedbacks: [
            "strength": "Strong core = strong everything 💪",
            "posture": "Good posture changes how people see you",
            "confidence": "It starts from the inside out ✨",
            "toned": "30 days. You'll feel the difference 🔥",
        ], next: 2)

        case 2: questionView("Ever done a plank?", sub: "Be honest. Zero judgment.", opts: [
            ("never", "🆕  Nope, first time"), ("gaveUp", "😅  Tried, gave up"),
            ("sometimes", "🔄  Here and there"), ("regular", "💎  All the time"),
        ], sel: $experience, feedbacks: [
            "never": "Everyone starts somewhere 🙌",
            "gaveUp": "This time you have a trainer who won't let you quit",
            "sometimes": "Let's make it a habit",
            "regular": "Okay show-off. Let's perfect your form 😏",
        ], next: experience == "never" ? 4 : 3)

        case 3: questionView("How long can\nyou hold one?", sub: nil, opts: [
            ("under15", "⚡  Under 15 seconds"), ("15to30", "🔥  15–30 seconds"),
            ("30to60", "💪  30–60 seconds"), ("over60", "👑  60+ seconds"),
        ], sel: $baseline, feedbacks: [
            "under15": "You'll double this in 2 weeks",
            "15to30": "Solid. Let's build on that",
            "30to60": "You're ahead of most people already",
            "over60": "Elite. Time to master form 👑",
        ], next: 4)

        case 4: chartScreen

        case 5: multiView("What usually\nstops you?", sub: "Pick all that apply.", opts: [
            ("boring", "😴  Gets boring fast"), ("dontKnow", "🤷  Not sure if I'm doing it right"),
            ("motivation", "📉  Hard to stay motivated"), ("time", "⏰  Never have time"),
            ("injury", "🩹  Worried about injury"),
        ], sel: $barriers, next: 6)

        case 6: celebrationScreen

        case 7: questionView("How old are you?", sub: "This personalizes your plan intensity.", opts: [
            ("under18", "⚡  Under 18"), ("18to24", "🔥  18–24"),
            ("25to34", "💪  25–34"), ("35to44", "✨  35–44"),
            ("45to54", "🧘  45–54"), ("55plus", "👑  55+"),
        ], sel: $ageRange, feedbacks: [
            "under18": "Starting young = starting right",
            "18to24": "Peak building years. Let's go",
            "25to34": "The sweet spot for results",
            "35to44": "Core strength matters more every year",
            "45to54": "This is when planking pays off the most",
            "55plus": "Strong core = independence for life 👑",
        ], next: 8)

        case 8: questionView("How active are\nyou right now?", sub: "This calibrates your starting level.", opts: [
            ("sedentary", "🛋️  Not very active"), ("light", "🚶  Light walks / stretching"),
            ("moderate", "🚴  A few workouts a week"), ("active", "🏋️  4–5x a week"),
            ("athlete", "🏃‍♀️  Daily training"),
        ], sel: $activityLevel, feedbacks: [
            "sedentary": "We start easy. No judgment at all",
            "light": "Great foundation to build on",
            "moderate": "Perfect. This fits right in",
            "active": "We'll push you 😈",
            "athlete": "Let's see how your core stacks up 💪",
        ], next: 9)

        case 9: didYouKnowScreen

        case 10: questionView("What do you want\nto target?", sub: "We'll focus your coaching here.", opts: [
            ("abs", "🎯  Abs / front core"), ("obliques", "🔄  Obliques / waist"),
            ("lowerBack", "🔙  Lower back"), ("fullCore", "💎  Full core — everything"),
        ], sel: $focusArea, feedbacks: [
            "abs": "Front and center. We'll get there",
            "obliques": "Waist definition takes real form",
            "lowerBack": "Underrated. This changes posture",
            "fullCore": "The complete package 💎",
        ], next: 11)

        case 11: questionView("When do you\nwant to plank?", sub: "We'll remind you.", opts: [
            ("morning", "🌅  Morning — start strong"), ("afternoon", "☀️  Afternoon — energy boost"),
            ("evening", "🌙  Evening — wind down"), ("whenever", "🤷  Whenever I feel like it"),
        ], sel: $plankTime, feedbacks: [
            "morning": "Morning plankers are 2x more consistent",
            "afternoon": "Great for a midday reset",
            "evening": "Perfect way to end the day",
            "whenever": "Flexibility works too",
        ], next: 12)

        case 12: formScreen
        case 13: featureShowcaseScreen
        case 14: socialProofScreen
        case 15: testimonialScreen
        case 16: beforeAfterScreen
        case 17: questionView("How many days\na week?", sub: "More days = faster results. We recommend 5.", opts: [
            ("3", "3️⃣  3 days — easing in"), ("5", "5️⃣  5 days — recommended"),
            ("7", "7️⃣  Every day — all in"),
        ], sel: $commitmentDays, feedbacks: [
            "3": "Consistency beats intensity",
            "5": "The sweet spot for results",
            "7": "Every. Single. Day. Respect 🫡",
        ], next: 18)
        case 18: nameInput
        case 19: coachSelector
        case 20: EmptyView() // analyzing overlay
        case 21: planRevealScreen
        case 22: personalStatScreen
        case 23: cameraSetupScreen
        case 24: paywallScreen
        default: EmptyView()
        }
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack(spacing: Space.sm) {
            Button { Haptics.light(); goBack() } label: {
                Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.textPrimary).frame(width: 40, height: 40)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.divider).frame(height: 4)
                    Capsule().fill(Palette.textPrimary)
                        .frame(width: max(8, geo.size.width * CGFloat(screen) / CGFloat(total - 1)), height: 4)
                        .animation(.spring(response: 0.5), value: screen)
                }
            }.frame(height: 4)
            Color.clear.frame(width: 40, height: 40)
        }.padding(.horizontal, Space.screenPadding)
    }

    // ═══════════════════════════════════════
    // MARK: - SPLASH (screen -1)
    // ═══════════════════════════════════════

    @State private var splashLogoVisible = false
    @State private var splashLineVisible = false
    @State private var splashPulse = false

    private var splashScreen: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / brand mark
                Text("absmaxxing")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Palette.textPrimary)
                    .opacity(splashLogoVisible ? 1 : 0)
                    .scaleEffect(splashLogoVisible ? 1 : 0.8)

                Spacer().frame(height: 12)

                // Animated underline
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.accent)
                    .frame(width: splashLineVisible ? 120 : 0, height: 4)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: splashLineVisible)

                Spacer().frame(height: Space.lg)

                // Subtle loading dots
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Palette.accent.opacity(splashPulse ? 0.8 : 0.2))
                            .frame(width: 6, height: 6)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                                value: splashPulse
                            )
                    }
                }
                .opacity(splashLineVisible ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            // Stage 1: logo scales in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                splashLogoVisible = true
            }

            // Stage 2: underline draws + dots pulse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                splashLineVisible = true
                splashPulse = true
            }

            // Stage 3: auto-transition to welcome
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                go(0)
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - WELCOME
    // ═══════════════════════════════════════

    @State private var heroVisible = false
    @State private var bubbleVisible = false

    private var welcome: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Space.md)

                // Phone mockup showing the product
                ZStack {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Color.black)
                        .frame(width: 220, height: 380)
                        .overlay(
                            RoundedRectangle(cornerRadius: 36)
                                .fill(
                                    LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .padding(4)
                                .overlay(
                                    VStack(spacing: 0) {
                                        Spacer().frame(height: 40)
                                        Text("47s")
                                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                        Spacer().frame(height: 8)
                                        Text("GOOD FORM")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(1.5)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10).padding(.vertical, 4)
                                            .background(Color(hex: "#30FF00").opacity(0.6))
                                            .clipShape(Capsule())
                                        Spacer()
                                        skeletonMini
                                            .frame(height: 120)
                                            .padding(.horizontal, 20)
                                        Spacer()
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 36))
                                )
                        )
                        .opacity(heroVisible ? 1 : 0)
                        .offset(y: heroVisible ? 0 : 30)

                    // Voice bubble
                    if bubbleVisible {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🔥 Kira")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.accent)
                            Text("\"Hips! Up!\nYou're giving\nhammock rn\"")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                                .italic()
                        }
                        .padding(10)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .offset(x: 100, y: 40)
                        .transition(.scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
                    }
                }
                .frame(height: 400)

                Spacer().frame(height: Space.lg)

                Text("absmaxxing")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(Palette.textPrimary)
                    .opacity(visible ? 1 : 0).offset(y: visible ? 0 : 20)

                Spacer().frame(height: 6)

                Text("AI plank trainer that\nactually makes you show up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(visible ? 1 : 0).offset(y: visible ? 0 : 15)

                Spacer()

                ctaBtn("Get Started") {
                    Haptics.heavy()
                    go(1)
                }
                .opacity(visible ? 1 : 0).offset(y: visible ? 0 : 30)

                Text("Already have an account? **Sign In**")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .opacity(visible ? 1 : 0)
                    .padding(.bottom, Space.lg)
            }
        }
        .onAppear {
            // Phone mockup fades in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.5)) { heroVisible = true }
            }

            // Text + button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.5)) { visible = true }
                Haptics.heavy()
            }

            // Confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showConfetti = false }
            }

            // Voice bubble + strong vibration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    bubbleVisible = true
                }
                Haptics.doubleVibrate()
            }
        }
    }

    /// Mini skeleton — fixed size, no GeometryReader
    private var skeletonMini: some View {
        let green = Color(hex: "#30FF00")
        let pts: [CGPoint] = [
            CGPoint(x: 27, y: 48), CGPoint(x: 45, y: 54),
            CGPoint(x: 90, y: 58), CGPoint(x: 135, y: 60), CGPoint(x: 162, y: 62),
        ]
        return ZStack {
            Path { p in
                p.move(to: pts[0])
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(green.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            ForEach(0..<pts.count, id: \.self) { i in
                Circle().fill(green).frame(width: 10, height: 10)
                    .position(pts[i])
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - QUESTION (feedback on Continue)
    // ═══════════════════════════════════════

    private func questionView(_ title: String, sub: String?, opts: [(String, String)],
                              sel: Binding<String>, feedbacks: [String: String], next: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Space.screenPadding)
            if let sub {
                Text(sub).font(Typo.body).foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.xs).padding(.horizontal, Space.screenPadding)
            }

            Spacer()

            VStack(spacing: Space.sm) {
                ForEach(opts, id: \.0) { key, label in
                    let on = sel.wrappedValue == key
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { sel.wrappedValue = key }
                    } label: {
                        Text(label)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(on ? Palette.textInverse : Palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20).frame(height: 60)
                            .background(on ? Palette.bgInverse : Palette.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .scaleEffect(on ? 1.02 : 1.0)
                    .animation(.spring(response: 0.25), value: on)
                }
            }.padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("Continue") {
                Haptics.medium()
                if let fb = feedbacks[sel.wrappedValue] {
                    // Show centered feedback interstitial
                    feedback = fb
                    withAnimation(.spring(response: 0.3)) { showFeedback = true }
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        withAnimation(.easeOut(duration: 0.2)) { showFeedback = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if next == -1 { withAnimation { analyzing = true }; startAnalyzing() }
                            else { go(next) }
                        }
                    }
                } else {
                    if next == -1 { withAnimation { analyzing = true }; startAnalyzing() }
                    else { go(next) }
                }
            }
            .opacity(sel.wrappedValue.isEmpty ? 0.3 : 1.0)
            .disabled(sel.wrappedValue.isEmpty)
        }
    }

    // MARK: - MULTI SELECT

    private func multiView(_ title: String, sub: String?, opts: [(String, String)],
                            sel: Binding<Set<String>>, next: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Space.screenPadding)
            if let sub {
                Text(sub).font(Typo.body).foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.xs).padding(.horizontal, Space.screenPadding)
            }
            Spacer()
            VStack(spacing: Space.sm) {
                ForEach(opts, id: \.0) { key, label in
                    let on = sel.wrappedValue.contains(key)
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.25)) {
                            if on { sel.wrappedValue.remove(key) } else { sel.wrappedValue.insert(key) }
                        }
                    } label: {
                        HStack {
                            Text(label).font(.system(size: 17, weight: .medium))
                                .foregroundStyle(on ? Palette.textInverse : Palette.textPrimary)
                            Spacer()
                            if on { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.textInverse) }
                        }
                        .padding(.horizontal, 20).frame(height: 60)
                        .background(on ? Palette.bgInverse : Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }.padding(.horizontal, Space.screenPadding)
            Spacer()
            ctaBtn("Continue") { Haptics.medium(); go(next) }
                .opacity(sel.wrappedValue.isEmpty ? 0.3 : 1.0).disabled(sel.wrappedValue.isEmpty)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - CHART (screen 4)
    // ═══════════════════════════════════════

    private var chartScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.accentSubtle, Palette.stateGood])
                .offset(y: 100)

            VStack(spacing: 0) {
                Spacer()
                AnimatedIcon(name: "chart.line.uptrend.xyaxis", size: 48)
                Spacer().frame(height: Space.lg)
                Text("Most people quit\nat 20 seconds.").font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary).multilineTextAlignment(.center)
                Spacer().frame(height: Space.lg)

                // Chart card
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Hold time over 30 days").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.textSecondary)
                    GeometryReader { geo in
                        let w = geo.size.width; let h = geo.size.height
                        // Without coaching
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h * 0.65))
                            p.addCurve(to: CGPoint(x: w, y: h * 0.8),
                                       control1: CGPoint(x: w * 0.3, y: h * 0.5),
                                       control2: CGPoint(x: w * 0.6, y: h * 0.85))
                        }.trim(from: 0, to: chartAnimated ? 1 : 0)
                         .stroke(Palette.divider, lineWidth: 2)
                        // With absmaxxing
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h * 0.65))
                            p.addCurve(to: CGPoint(x: w, y: h * 0.1),
                                       control1: CGPoint(x: w * 0.3, y: h * 0.45),
                                       control2: CGPoint(x: w * 0.7, y: h * 0.15))
                        }.trim(from: 0, to: chartAnimated ? 1 : 0)
                         .stroke(Palette.accent, lineWidth: 3)
                        if chartAnimated {
                            Text("Without coaching").font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                                .position(x: w * 0.78, y: h * 0.92).transition(.opacity)
                            Text("With absmaxxing").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.accent)
                                .position(x: w * 0.82, y: h * 0.05).transition(.opacity)
                        }
                    }.frame(height: 130)
                    HStack {
                        Text("Day 1").font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text("Day 30").font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(Space.cardPadding).background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.md)
                Text("80% of users hold 3x longer by day 30")
                    .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(5) }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.5).delay(0.3)) { chartAnimated = true } }
    }

    // ═══════════════════════════════════════
    // MARK: - CELEBRATION (screen 6)
    // ═══════════════════════════════════════

    @State private var coachPhotoVisible = false
    @State private var coachRingPulse = false

    private var celebrationScreen: some View {
        let msg = barriers.contains("boring") ? "Boredom is the #1 reason\npeople quit planking."
            : barriers.contains("motivation") ? "Motivation fades.\nAccountability doesn't."
            : barriers.contains("dontKnow") ? "Not knowing correct form\nis more common than you think."
            : "We hear you."

        let fix = barriers.contains("boring") ? "Your AI coach makes\nevery second count."
            : barriers.contains("motivation") ? "Your coach shows up\nevery single day."
            : barriers.contains("dontKnow") ? "Your AI coach corrects\nyour form in real time."
            : "absmaxxing was built for this."

        return ZStack {
            GradientBlob(colors: [Palette.stateGood, Palette.accentSubtle, Palette.accent])

            VStack(spacing: 0) {
                Spacer()

                // Trainer profile photos — 3 overlapping circles
                HStack(spacing: -16) {
                    ForEach(Array(["coach-kira", "coach-sarah", "coach-matson"].enumerated()), id: \.offset) { i, photo in
                        ZStack {
                            // Pulse ring
                            Circle()
                                .stroke(Palette.accent.opacity(coachRingPulse ? 0.3 : 0), lineWidth: 3)
                                .frame(width: 76, height: 76)
                                .scaleEffect(coachRingPulse ? 1.15 : 1.0)
                                .animation(
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.3),
                                    value: coachRingPulse
                                )

                            // Photo
                            Group {
                                if UIImage(named: photo) != nil {
                                    Image(photo).resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Palette.accentSubtle
                                }
                            }
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 3))
                        }
                        .opacity(coachPhotoVisible ? 1 : 0)
                        .scaleEffect(coachPhotoVisible ? 1 : 0.5)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.65).delay(Double(i) * 0.12),
                            value: coachPhotoVisible
                        )
                    }
                }

                Spacer().frame(height: Space.lg)

                Text(msg).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center).opacity(celebVisible ? 1 : 0).offset(y: celebVisible ? 0 : 20)

                Spacer().frame(height: Space.xl)

                Text(fix).font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.center).opacity(celebVisible ? 1 : 0).offset(y: celebVisible ? 0 : 15)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: celebVisible)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(7) }.opacity(celebVisible ? 1 : 0)
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            Haptics.success()
            // Photos spring in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { coachPhotoVisible = true }
            // Text fades in after photos
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.6)) { celebVisible = true }
            }
            // Pulse rings start after everything settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { coachRingPulse = true }
        }
    }

    // MARK: - Form Education (screen 12)

    @State private var formStep = 0  // 0=hidden, 1=left card, 2=arrow, 3=right card, 4=text

    private var formScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.stateWarn, Palette.accentSubtle]).offset(y: 80)
            VStack(spacing: 0) {
                Spacer()

                // Animated comparison
                HStack(spacing: Space.lg) {
                    // Left — good form
                    VStack(spacing: Space.sm) {
                        Text("20s").font(.system(size: 48, weight: .black)).foregroundStyle(Palette.stateGood)
                        Text("perfect form").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.textSecondary)
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundStyle(Palette.stateGood)
                    }
                    .opacity(formStep >= 1 ? 1 : 0)
                    .offset(x: formStep >= 1 ? 0 : -30)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: formStep)

                    // Arrow
                    Text(">")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(Palette.accent)
                        .opacity(formStep >= 2 ? 1 : 0)
                        .scaleEffect(formStep >= 2 ? 1 : 0.5)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: formStep)

                    // Right — bad form
                    VStack(spacing: Space.sm) {
                        Text("60s").font(.system(size: 48, weight: .black)).foregroundStyle(Palette.stateBad)
                        Text("bad form").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.textSecondary)
                        Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(Palette.stateBad)
                    }
                    .opacity(formStep >= 3 ? 1 : 0)
                    .offset(x: formStep >= 3 ? 0 : 30)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: formStep)
                }

                Spacer().frame(height: Space.xl)

                Text("Form matters more\nthan time.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(formStep >= 4 ? 1 : 0)
                    .offset(y: formStep >= 4 ? 0 : 12)
                    .animation(.easeOut(duration: 0.4), value: formStep)

                Spacer().frame(height: Space.sm)

                Text("That's what your AI coach is for.\nReal-time corrections, every second.")
                    .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
                    .opacity(formStep >= 4 ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: formStep)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(13) }
                    .opacity(formStep >= 4 ? 1 : 0)
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            // Staggered entrance: left → arrow → right → text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { formStep = 1; Haptics.light() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { formStep = 2; Haptics.medium() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { formStep = 3; Haptics.light() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { formStep = 4 }
        }
    }

    // MARK: - Social Proof (screen 14)

    @State private var cardsVisible = false

    @State private var marqueeOffset1: CGFloat = 0
    @State private var marqueeOffset2: CGFloat = 0

    private var socialProofScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Top marquee — scrolls left
            marqueeRow(
                assets: ["social-1", "social-2", "social-3", "social-4", "social-5"],
                sizes: [(80, 142), (68, 120), (74, 132), (60, 106), (72, 128)],
                rotations: [-5, 3, -2, 4, -6],
                offset: marqueeOffset1
            )
            .opacity(cardsVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: cardsVisible)

            Spacer().frame(height: Space.lg)

            // Counter
            Text("\(proofCount)")
                .font(.system(size: 72, weight: .black))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())

            Spacer().frame(height: Space.xs)

            Text("women started their\nCore Reset this month")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            // Live activity indicator
            HStack(spacing: 6) {
                Circle().fill(Palette.stateGood).frame(width: 8, height: 8)
                    .opacity(cardsVisible ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: cardsVisible)
                Text("12 active right now")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .opacity(cardsVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(1.2), value: cardsVisible)

            Spacer().frame(height: Space.lg)

            // Bottom marquee — scrolls right
            marqueeRow(
                assets: ["social-6", "social-7", "social-8", "social-9", "social-10"],
                sizes: [(72, 128), (64, 114), (80, 142), (56, 100), (68, 120)],
                rotations: [4, -3, 5, -4, 2],
                offset: marqueeOffset2
            )
            .opacity(cardsVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: cardsVisible)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(15) }
        }
        .clipped()
        .onAppear {
            cardsVisible = true
            // Start marquee after entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    marqueeOffset1 = -1  // triggers the offset calc inside marqueeRow
                }
                withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                    marqueeOffset2 = -1
                }
            }
            let t = 2847
            for i in 0...30 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                    withAnimation(.easeOut(duration: 0.1)) { proofCount = Int(Double(t) * Double(i) / 30) }
                    if i % 5 == 0 { Haptics.light() }
                    if i == 30 { Haptics.heavy() }
                }
            }
        }
    }

    /// Infinite marquee row of 9:16 cards. Duplicates content for seamless loop.
    private func marqueeRow(
        assets: [String],
        sizes: [(CGFloat, CGFloat)],
        rotations: [Double],
        offset: CGFloat
    ) -> some View {
        let cardSpacing: CGFloat = 12
        // Total width of one set of cards
        let totalWidth = sizes.reduce(CGFloat(0)) { $0 + $1.0 + cardSpacing }

        return GeometryReader { geo in
            let scrollAmount = offset < 0 ? totalWidth : 0  // 0 = static, totalWidth = one full loop

            HStack(spacing: cardSpacing) {
                // First set
                ForEach(0..<assets.count, id: \.self) { i in
                    socialCard(asset: assets[i], width: sizes[i].0, height: sizes[i].1, rotation: rotations[i])
                }
                // Duplicate for seamless loop
                ForEach(0..<assets.count, id: \.self) { i in
                    socialCard(asset: assets[i], width: sizes[i].0, height: sizes[i].1, rotation: rotations[i])
                }
            }
            .offset(x: -scrollAmount)
        }
        .frame(height: 150)
    }

    private func socialCard(asset: String, width: CGFloat, height: CGFloat, rotation: Double) -> some View {
        Group {
            if UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Palette.accent.opacity(0.15), Palette.accentSubtle.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.divider.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Coach Education (screen 12) — raw bold style, no photos

    private var coachScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.stateGood, Palette.bgInverse]).offset(y: -50)
            VStack(spacing: 0) {
                Spacer()

                // Big bold stat
                Text("3x")
                    .font(.system(size: 80, weight: .black))
                    .foregroundStyle(Palette.accent)

                Text("longer hold times\nwith real-time coaching")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Space.xl)

                // Feature pills
                VStack(spacing: Space.sm) {
                    featurePill("camera.fill", "Watches your form in real time")
                    featurePill("waveform", "Voice coaching — not just beeps")
                    featurePill("figure.core.training", "Detects hip sag & shoulder creep")
                }
                .padding(.horizontal, Space.screenPadding)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(18) }
            }
        }
    }

    private func featurePill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 32, height: 32)
                .background(Palette.accent.opacity(0.1))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Testimonial (screen 13)

    @State private var reviewVisible = false

    private var testimonialScreen: some View {
        let reviews: [(String, String, String, Int)] = [
            barriers.contains("boring")
                ? ("The trainer literally roasted me for dropping my hips 😂 I've never been so motivated to hold a plank", "Jasmine", "Day 22", 5)
                : ("I had NO idea my form was wrong until this app showed me. Game changer for real", "Maya", "Day 14", 5),

            barriers.contains("motivation")
                ? ("I used to quit at 15 seconds. Now I'm at 45 and actually having fun??", "Aaliyah", "Day 11", 5)
                : ("The voice feedback hits different. Like having a friend who's also a trainer", "Destiny", "Day 19", 5),

            barriers.contains("time")
                ? ("2 minutes a day. That's it. I do it while my coffee brews and I'm already seeing results", "Priya", "Day 17", 5)
                : ("My posture is noticeably better and my back pain is basically gone. Wish I started sooner", "Kayla", "Day 28", 5),
        ]

        return VStack(spacing: 0) {
            Spacer().frame(height: Space.lg)

            Text("What people are saying")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)

            Spacer().frame(height: Space.lg)

            VStack(spacing: 12) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { i, review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<review.3, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        Text(review.0)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(3)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Palette.accent.opacity(0.15))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text(String(review.1.prefix(1)))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Palette.accent)
                                )
                            Text(review.1)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text("·").foregroundStyle(Palette.divider)
                            Text(review.2)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .opacity(reviewVisible ? 1 : 0)
                    .offset(y: reviewVisible ? 0 : CGFloat(20 + i * 8))
                    .animation(.easeOut(duration: 0.45).delay(0.15 + Double(i) * 0.15), value: reviewVisible)
                }
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(16) }
        }
        .onAppear { withAnimation { reviewVisible = true } }
    }

    // MARK: - Program (unused, kept for reference)

    private var programScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.accentSubtle, Palette.stateGood]).offset(y: 100)
            VStack(spacing: 0) {
                Spacer()
                AnimatedIcon(name: "calendar", size: 52)
                Spacer().frame(height: Space.lg)
                Text("30 days.\n5 exercises.\nOne mission.").font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary).multilineTextAlignment(.center)
                Spacer().frame(height: Space.sm)
                Text("Start with plank. Earn the rest.\nYour core score tracks everything.")
                    .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(23) }
            }.padding(.horizontal, Space.screenPadding)
        }
    }

    // MARK: - Name (screen 15)

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What should your\ntrainer call you?").font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary).padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.xl)

            TextField("Your name", text: $name)
                .font(.system(size: 24, weight: .medium))
                .padding(20).background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(.horizontal, Space.screenPadding)
                .onSubmit {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Haptics.medium(); go(19)
                }

            Spacer()

            ctaBtn("Continue") { Haptics.medium(); go(19) }
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1.0)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - COACH SELECTOR (screen 16)
    // ═══════════════════════════════════════

    @State private var playingPreview: String? = nil
    @State private var previewPlayer: AVAudioPlayer? = nil

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func playPreview(_ clip: String, id: String) {
        previewPlayer?.stop()
        if playingPreview == id {
            playingPreview = nil
            return
        }
        playingPreview = id
        if let url = Bundle.main.url(forResource: clip, withExtension: "m4a") {
            previewPlayer = try? AVAudioPlayer(contentsOf: url)
            previewPlayer?.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if playingPreview == id { playingPreview = nil }
        }
    }

    private var coachSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick your trainer")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Space.screenPadding)
            Text("Tap to hear their vibe")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.xs).padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            VStack(spacing: Space.sm) {
                trainerRow(
                    id: "keepItReal", photo: "coach-kira", name: "Kira",
                    vibe: "Sassy & Real",
                    quote: "\"My mama planks better than this\"",
                    preview: "kira_preview"
                )
                trainerRow(
                    id: "encouraging", photo: "coach-sarah", name: "Sarah",
                    vibe: "Warm & Supportive",
                    quote: "\"You're doing amazing, keep breathing\"",
                    preview: "sarah_preview"
                )
                trainerRow(
                    id: "balanced", photo: "coach-matson", name: "Matson",
                    vibe: "Charming & Motivating",
                    quote: "\"Come on darlin', you got this\"",
                    preview: "matson_preview"
                )
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("Train with \(selectedCoachName)") {
                Haptics.heavy()
                previewPlayer?.stop(); playingPreview = nil
                feedback = coachFeedback
                withAnimation(.spring(response: 0.3)) { showFeedback = true }
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation(.easeOut(duration: 0.2)) { showFeedback = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation { analyzing = true }; startAnalyzing()
                    }
                }
            }
        }
        .onAppear { configureAudioSession() }
    }

    private func trainerRow(id: String, photo: String, name: String, vibe: String,
                             quote: String, preview: String) -> some View {
        let selected = voicePreference == id
        let playing = playingPreview == id

        return Button {
            Haptics.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { voicePreference = id }
            playPreview(preview, id: id)
        } label: {
            HStack(spacing: 14) {
                // Tall portrait photo
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if UIImage(named: photo) != nil {
                            Image(photo).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: id == "keepItReal" ? [Palette.accent, Palette.stateWarn] :
                                        id == "encouraging" ? [Palette.stateGood, Palette.accentSubtle] :
                                        [Palette.bgInverse, Palette.accent.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Playing indicator
                    if playing {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Palette.accent)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                        Text(vibe)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(selected ? Palette.accent.opacity(0.15) : Palette.accent.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text(quote)
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(selected ? Palette.textInverse.opacity(0.6) : Palette.textSecondary)
                        .lineLimit(2)

                    if playing {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                            Text("Playing...")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity)
                    }
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? Palette.textInverse : Palette.divider)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .frame(height: 124)
            .background(selected ? Palette.bgInverse : Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Palette.accent : Palette.divider, lineWidth: selected ? 2 : 1)
            )
        }
        .scaleEffect(selected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: selected)
    }

    private var selectedCoachName: String {
        switch voicePreference {
        case "keepItReal": return "Kira"
        case "encouraging": return "Sarah"
        case "balanced": return "Matson"
        default: return "coach"
        }
    }

    private var coachFeedback: String {
        switch voicePreference {
        case "keepItReal": return "Get ready to be roasted 😏"
        case "encouraging": return "Your biggest fan is waiting 🤗"
        case "balanced": return "Southern charm activated 😏"
        default: return "Great choice"
        }
    }

    // ═══════════════════════════════════════
    // MARK: - ANALYZING
    // ═══════════════════════════════════════

    private var analyzingScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("\(analyzePercent)%").font(.system(size: 72, weight: .bold)).foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Spacer().frame(height: Space.sm)
            Text("Building your plan").font(.system(size: 22, weight: .medium)).foregroundStyle(Palette.textPrimary)
            Spacer().frame(height: Space.lg)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.divider).frame(height: 6)
                    Capsule().fill(LinearGradient(colors: [Palette.accent, Palette.stateGood], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(analyzePercent) / 100, height: 6)
                        .animation(.easeOut(duration: 0.3), value: analyzePercent)
                }
            }.frame(height: 6).padding(.horizontal, Space.xl)
            Spacer().frame(height: Space.xl)
            VStack(alignment: .leading, spacing: Space.md) {
                chk("Analyzing your goals", analyzePercent >= 20)
                chk("Setting target hold times", analyzePercent >= 40)
                chk("Calibrating AI coach", analyzePercent >= 60)
                chk("Building 30-day program", analyzePercent >= 80)
                chk("Finalizing your plan", analyzePercent >= 98)
            }.padding(.horizontal, Space.screenPadding)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.bgPrimary)
    }

    private func chk(_ t: String, _ d: Bool) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: d ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                .foregroundStyle(d ? Palette.textPrimary : Palette.divider).animation(.spring(response: 0.3), value: d)
            Text(t).font(.system(size: 16, weight: .medium)).foregroundStyle(d ? Palette.textPrimary : Palette.textSecondary)
        }
    }

    private func startAnalyzing() {
        analyzePercent = 0
        for i in 0...100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5 * Double(i) / 100) {
                withAnimation(.easeOut(duration: 0.15)) { analyzePercent = i }
                if i % 20 == 0 { Haptics.light() }
                if i == 100 {
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { analyzing = false }
                        showConfetti = true; go(21)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showConfetti = false }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - PLAN REVEAL + CAMERA + PAYWALL
    // ═══════════════════════════════════════

    private var planRevealScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Your 30-Day Core\nReset is ready.").font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary).multilineTextAlignment(.center)
                .opacity(planRevealed ? 1 : 0).offset(y: planRevealed ? 0 : 20)
            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Let's go, \(name).").font(Typo.body).foregroundStyle(Palette.accent)
                    .padding(.top, Space.xs).opacity(planRevealed ? 1 : 0)
            }
            Spacer().frame(height: Space.lg)
            VStack(spacing: Space.sm) {
                pR("Plank Hold", "Day 1", true, 0); pR("Dead Bug", "Day 8", false, 1)
                pR("Side Plank", "Day 15", false, 2); pR("Hollow Hold", "Day 22", false, 3)
                pR("Bird Dog", "Day 22", false, 4)
            }.padding(.horizontal, Space.screenPadding)
            Spacer()
            ctaBtn("Next") { Haptics.medium(); go(22) }.opacity(planRevealed ? 1 : 0)
        }
        .onAppear { Haptics.success(); withAnimation(.easeOut(duration: 0.6).delay(0.2)) { planRevealed = true } }
    }

    private func pR(_ n: String, _ d: String, _ a: Bool, _ i: Int) -> some View {
        HStack {
            Circle().fill(a ? Palette.bgInverse : Palette.divider).frame(width: 36, height: 36)
                .overlay(Image(systemName: a ? "figure.core.training" : "lock.fill").font(.system(size: 14)).foregroundStyle(a ? Palette.textInverse : Palette.textSecondary))
            Text(n).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(d).font(Typo.caption).foregroundStyle(a ? Palette.accent : Palette.textSecondary)
        }.padding(Space.cardPadding).background(Palette.bgElevated).clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(planRevealed ? 1 : 0).offset(y: planRevealed ? 0 : CGFloat(10 + i * 5))
        .animation(.easeOut(duration: 0.5).delay(0.3 + Double(i) * 0.1), value: planRevealed)
    }

    private var cameraSetupScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            AnimatedIcon(name: "iphone.gen3.radiowaves.left.and.right", size: 56)
            Spacer().frame(height: Space.lg)
            Text("Set up your camera").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
            Spacer().frame(height: Space.sm)
            Text("Prop your phone about 6 feet away\nso your coach can see you.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            Spacer().frame(height: Space.xl)
            VStack(alignment: .leading, spacing: Space.md) {
                tR("figure.stand", "Full body visible"); tR("light.max", "Good lighting")
                tR("iphone.gen3", "Lean against wall or book")
            }.padding(20).background(Palette.bgElevated).clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Space.screenPadding)
            Spacer()
            ctaBtn("Got it") { Haptics.medium(); go(24) }
        }.padding(.horizontal, Space.screenPadding)
    }

    private func tR(_ ic: String, _ tx: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: ic).font(.system(size: 16)).foregroundStyle(Palette.textSecondary).frame(width: 24)
            Text(tx).font(.system(size: 15)).foregroundStyle(Palette.textPrimary)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - DID YOU KNOW (screen 9)
    // ═══════════════════════════════════════

    private var didYouKnowScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.stateGood, Palette.accentSubtle]).offset(y: -50)
            VStack(spacing: 0) {
                Spacer()

                Text("Did you know?")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Palette.accent)
                    .opacity(factVisible ? 1 : 0)

                Spacer().frame(height: Space.md)

                Text("Your core activates\nbefore every movement\nyou make.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(factVisible ? 1 : 0)
                    .offset(y: factVisible ? 0 : 15)

                Spacer().frame(height: Space.lg)

                Text("Walking. Sitting. Standing up.\nA weak core means everything\nis harder than it should be.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(factVisible ? 1 : 0)
                    .offset(y: factVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: factVisible)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(10) }
                    .opacity(factVisible ? 1 : 0)
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { factVisible = true }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - FEATURE SHOWCASE (screen 13)
    // ═══════════════════════════════════════

    private var featureShowcaseScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("What makes\nabsmaxxing different")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(featureVisible ? 1 : 0)

            Spacer().frame(height: Space.xl)

            VStack(spacing: 14) {
                featureRow(icon: "camera.fill", title: "Sees your form",
                           desc: "AI watches your body in real time. Not a timer app.",
                           delay: 0.1)
                featureRow(icon: "waveform", title: "Talks to you",
                           desc: "Voice coaching. Corrections, hype, roasts. Not beeps.",
                           delay: 0.25)
                featureRow(icon: "figure.core.training", title: "Detects mistakes",
                           desc: "Hip sag, shoulder creep, knee drop. Catches what you miss.",
                           delay: 0.4)
                featureRow(icon: "chart.line.uptrend.xyaxis", title: "Tracks real progress",
                           desc: "Active plank time, not just clock time. Form matters.",
                           delay: 0.55)
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(14) }
                .opacity(featureVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { featureVisible = true }
        }
    }

    private func featureRow(icon: String, title: String, desc: String, delay: Double) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 40, height: 40)
                .background(Palette.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(featureVisible ? 1 : 0)
        .offset(y: featureVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.4).delay(delay), value: featureVisible)
    }

    // ═══════════════════════════════════════
    // MARK: - BEFORE/AFTER STAT (screen 16)
    // ═══════════════════════════════════════

    @State private var statCount = 0

    private var beforeAfterScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.stateGood, Palette.accent, Palette.accentSubtle]).offset(y: 50)
            VStack(spacing: 0) {
                Spacer()

                // Animated stat
                Text("\(statCount)%")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(Palette.accent)
                    .contentTransition(.numericText())

                Spacer().frame(height: Space.sm)

                Text("of users see visible\ncore definition by day 21")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Space.xl)

                // Before/after cards
                HStack(spacing: Space.md) {
                    VStack(spacing: Space.sm) {
                        Text("Day 1")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                        VStack(spacing: 4) {
                            Text("15s").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
                            Text("avg hold").font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(spacing: Space.sm) {
                        Text("Day 30")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                        VStack(spacing: 4) {
                            Text("90s").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.accent)
                            Text("avg hold").font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .opacity(beforeAfterVisible ? 1 : 0)
                .offset(y: beforeAfterVisible ? 0 : 15)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: beforeAfterVisible)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(17) }
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            beforeAfterVisible = true
            let target = 73
            for i in 0...20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                    withAnimation(.easeOut(duration: 0.1)) { statCount = Int(Double(target) * Double(i) / 20) }
                    if i % 5 == 0 { Haptics.light() }
                    if i == 20 { Haptics.heavy() }
                }
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - PERSONAL STAT (screen 22)
    // ═══════════════════════════════════════

    private var personalStatScreen: some View {
        let targetHold = experience == "never" || experience == "gaveUp" ? "45s" :
                         baseline == "under15" || baseline == "15to30" ? "60s" :
                         baseline == "30to60" ? "90s" : "120s"
        let focusText = focusArea == "abs" ? "front core definition" :
                        focusArea == "obliques" ? "waist sculpting" :
                        focusArea == "lowerBack" ? "lower back strength" : "full core activation"

        return ZStack {
            GradientBlob(colors: [Palette.accent, Palette.stateGood, Palette.accentSubtle]).offset(y: -80)
            VStack(spacing: 0) {
                Spacer()

                Text("Based on your answers")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Palette.accent)
                    .opacity(personalStatVisible ? 1 : 0)

                Spacer().frame(height: Space.md)

                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("\(name), you'll hit")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .opacity(personalStatVisible ? 1 : 0)
                    Spacer().frame(height: Space.xs)
                }

                Text(targetHold)
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(Palette.textPrimary)
                    .opacity(personalStatVisible ? 1 : 0)
                    .offset(y: personalStatVisible ? 0 : 15)

                Text("perfect-form hold\nby day 30")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(personalStatVisible ? 1 : 0)

                Spacer().frame(height: Space.xl)

                // Personalized details
                VStack(spacing: Space.sm) {
                    statRow("🎯", "Focus: \(focusText)")
                    statRow("📅", "Plan: \(commitmentDays.isEmpty ? "5" : commitmentDays) days/week")
                    statRow("🎙️", "Trainer: \(selectedCoachName)")
                }
                .padding(.horizontal, Space.screenPadding)
                .opacity(personalStatVisible ? 1 : 0)
                .offset(y: personalStatVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: personalStatVisible)

                Spacer()
                ctaBtn("Set up camera") { Haptics.medium(); go(23) }
                    .opacity(personalStatVisible ? 1 : 0)
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.easeOut(duration: 0.6)) { personalStatVisible = true }
        }
    }

    private func statRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 16))
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ═══════════════════════════════════════
    // MARK: - PAYWALL
    // ═══════════════════════════════════════

    private var paywallScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Start your 30-Day\nCore Reset free.").font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary).multilineTextAlignment(.center)
            Spacer().frame(height: Space.sm)
            Text("3 days free, then $29.99/year").font(Typo.body).foregroundStyle(Palette.textSecondary)
            Spacer().frame(height: Space.sm)
            HStack(spacing: Space.xs) {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.stateGood)
                Text("No payment due now").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            ctaBtn("Continue for FREE") { Haptics.heavy(); finish() }
            Text("Restore · Terms · Privacy").font(.system(size: 12)).foregroundStyle(Palette.textSecondary).padding(.bottom, Space.md)
        }.padding(.horizontal, Space.screenPadding)
    }

    // ═══════════════════════════════════════
    // MARK: - Shared
    // ═══════════════════════════════════════

    private func ctaBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Palette.bgInverse, Palette.bgInverse.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(CTAButtonStyle())
        .padding(.horizontal, Space.screenPadding).padding(.bottom, Space.lg)
    }

    private func go(_ to: Int) {
        dir = to > screen ? 1 : -1
        withAnimation(.easeOut(duration: 0.3)) { screen = to }
    }
    private func goBack() {
        switch screen {
        case 4 where experience == "never": go(2)
        case 22: go(21)  // personal stat → plan reveal
        default: go(max(0, screen - 1))
        }
    }
    private func finish() {
        // Request notification permission if user opted in
        if notificationsEnabled {
            Task {
                let granted = await NotificationPermission.request()
                if granted { NotificationPermission.scheduleDailyReminder(at: notificationTime) }
            }
        }
        onComplete(OnboardingData(
            goal: goal, experience: experience, baselineHoldSeconds: bS(baseline),
            barriers: Array(barriers), ageRange: ageRange, activityLevel: activityLevel,
            focusArea: focusArea, plankTime: plankTime,
            commitmentDaysPerWeek: Int(commitmentDays) ?? 5, notificationsEnabled: notificationsEnabled,
            notificationTime: notificationsEnabled ? notificationTime : nil, name: name, voicePreference: voicePreference
        ))
    }
    private func bS(_ b: String) -> Int {
        switch b { case "under15": 10; case "15to30": 20; case "30to60": 45; case "over60": 60; default: 15 }
    }
}

struct OnboardingData {
    let goal, experience: String; let baselineHoldSeconds: Int; let barriers: [String]
    let ageRange, activityLevel, focusArea, plankTime: String; let commitmentDaysPerWeek: Int
    let notificationsEnabled: Bool; let notificationTime: Date?; let name, voicePreference: String
}

// MARK: - CTA Button Style

struct CTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
