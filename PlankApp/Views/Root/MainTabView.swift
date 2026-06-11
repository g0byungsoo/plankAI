import SwiftUI
import PlankFood
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

/// iOS 26 native TabView. Picking native over the prior custom HStack
/// pill so we get liquid glass styling for free — and so future tabs
/// (search, profile, etc.) can be added without reinventing chrome.
///
/// `Tab` (iOS 18+) gets us the cleanest declaration; on iOS 26 the bar
/// renders as liquid glass automatically.
///
/// 2026-06-05 — delta v7 D57: central cocoa camera FAB sits above the
/// 2-tab bar when FoodFlags.isEnabled. Cal AI pattern adapted to
/// JeniFit chrome — primary action (snap food) reachable from any
/// tab, not just Home.
struct MainTabView: View {

    enum AppTab: Hashable {
        case workout
        case log
    }

    @State private var selectedTab: AppTab = .workout
    @State private var showCaptureFlow = false

    // v1.1 program pivot — gates the program-era home (PlanView) vs
    // legacy HomeView. Default false; flipped to true when the user
    // commits to a program (ProgramSetupSubflow sets it directly).
    @AppStorage("programEraEnabled") private var programEraEnabled: Bool = false
    @AppStorage("progressGridEnabled") private var progressGridEnabled: Bool = false

    // Founder-locked: existing users see a full-screen "your program
    // is ready" cover once on first launch post-v1.1. Cover sets
    // hasSeenProgramIntro=true on dismiss so we never show it twice.
    @AppStorage("hasSeenProgramIntro") private var hasSeenProgramIntro: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasEnrolledInProgram") private var hasEnrolledInProgram: Bool = false

    /// One-shot trigger for the program intro cover. Initialized from
    /// the AppStorage flags on first body eval; flipped to false when
    /// the cover dismisses (success or skip). Keeping this as @State
    /// — not derived — is what lets the cover dismiss cleanly. A
    /// computed binding off @AppStorage doesn't re-render fast enough
    /// in iOS 17/18 to drive a fullScreenCover.
    @State private var showProgramIntro: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // v1.1 program pivot: "today" replaces "present" — points
                // explicitly at the daily checklist now that PlanView is
                // the surface here. "becoming" stays as the analytics
                // tab name (founder decision 2026-06-09: minimal rename
                // for Phase 1; 5-tab BetterMe IA deferred to Phase 6).
                //
                // Flag gate: when programEraEnabled (set by the program
                // subflow commit) PlanView replaces HomeView for this
                // tab. Flag false = existing render path, zero impact.
                Group {
                    if programEraEnabled {
                        PlanView()
                    } else {
                        HomeView()
                    }
                }
                .tabBloom(isActive: selectedTab == .workout)
                .tabItem {
                    Label("today", systemImage: "sparkles")
                }
                .tag(AppTab.workout)

                Group {
                    if progressGridEnabled {
                        ProgressGridView()
                    } else {
                        AnalyticsView()
                    }
                }
                .tabBloom(isActive: selectedTab == .log)
                .tabItem {
                    // "becoming" leans into Dweck/Burnette growth-mindset
                    // research — present-progressive framing accommodates
                    // plateaus better than the static "past" frame did.
                    Label("becoming", systemImage: "book.closed.fill")
                }
                .tag(AppTab.log)
            }
            .tint(Palette.accent)
            .onAppear {
                #if DEBUG
                print("[FUNNEL] main_tab_appeared | paywall cover dismissed, user is now in the app")
                #endif
                // Evaluate one-shot program intro on first tab appear.
                // Same trigger conditions every time the tab gains focus
                // — re-firing is fine because hasSeenProgramIntro flips
                // to true the moment the cover dismisses, preventing
                // a second show.
                if hasCompletedOnboarding
                    && !hasEnrolledInProgram
                    && !hasSeenProgramIntro
                    && !programEraEnabled
                {
                    showProgramIntro = true
                }
            }

            // Central camera FAB per delta v7 D57. Visible only when
            // food rail is enabled. Cocoa circle with cream camera glyph
            // and the brand's signature hard-offset shadow + 1.5pt
            // accent border. Positioned above the native tab bar.
            if FoodFlags.isEnabled {
                cameraFAB
                    .padding(.bottom, 30)
                    .accessibilityIdentifier("home_camera_fab")
            }
        }
        .fullScreenCover(isPresented: $showCaptureFlow) {
            CaptureFlowView(
                userId: AuthService.shared.currentUser?.id.uuidString ?? "",
                cuisineProfile: UserDefaults.standard
                    .string(forKey: "onboardingCuisinePreference"),
                onDismiss: { showCaptureFlow = false }
            )
        }
        // v1.1 program pivot — existing-user opt-in. Fires once for
        // users who completed v1.0 onboarding pre-v1.1, before they
        // see PlanView (or stay on HomeView if they decline). Founder
        // locked the full-screen cover (commitment device) over the
        // quieter home-card approach 2026-06-09.
        .fullScreenCover(isPresented: $showProgramIntro) {
            ProgramIntroFullScreenCover {
                showProgramIntro = false
                // hasSeenProgramIntro is flipped by the cover internally
                // on dismiss. If user committed, programEraEnabled is
                // also true → next tab render shows PlanView.
            }
        }
    }

    @ViewBuilder private var cameraFAB: some View {
        Button {
            Haptics.light()
            Analytics.track(.foodCardTapped, properties: ["source": "tab_bar_fab"])
            showCaptureFlow = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.bgPrimary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Palette.textPrimary)
                )
                .overlay(
                    Circle()
                        .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
                )
                .shadow(color: Palette.textPrimary.opacity(0.25), radius: 0, x: 3, y: 3)
        }
        .accessibilityLabel("snap food")
        .accessibilityHint("opens the camera to log a meal")
    }
}

/// Tab-arrival "bloom": when a tab becomes active, its content resolves from
/// a soft blur + slight scale + dimmed opacity into focus (~0.5s), with a
/// soft haptic — so switching present ↔ becoming reads smooth and magical
/// rather than an instant content swap. The native liquid-glass bar stays
/// crisp (this only affects the tab's content, not the bar).
///
/// `appearedOnce` is seeded to the tab's initial active state so each tab's
/// own first-load entrance (HomeView / AnalyticsView animateIn) owns the
/// first reveal, and the bloom takes over on every subsequent arrival —
/// the two never double up. Reduce-motion snaps with no bloom.
private struct TabBloom: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearedOnce: Bool
    @State private var blur: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var offsetY: CGFloat = 0

    init(isActive: Bool) {
        self.isActive = isActive
        _appearedOnce = State(initialValue: isActive)
    }

    func body(content: Content) -> some View {
        // Opaque cream backdrop under the blooming content so the blur + fade
        // never reveal the black window behind the tab. No scaleEffect — the
        // earlier scale shrank the content and exposed black gaps at the
        // top/bottom edges. Blur resolving into focus + an 8pt upward
        // settle (founder 2026-06-11: "modern, simple but premium
        // transition between today and becoming") — the page arrives
        // like a card laid on the desk, never a slide.
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            content
                .blur(radius: blur)
                .opacity(opacity)
                .offset(y: offsetY)
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            guard appearedOnce else { appearedOnce = true; return }
            guard !reduceMotion else { return }
            // Set the bloom-from state this frame, then resolve to clear next
            // runloop so the blur is actually rendered before it animates away.
            blur = 5; opacity = 0.85; offsetY = 8
            Haptics.soft()
            DispatchQueue.main.async {
                withAnimation(Motion.gentleSpring) {
                    blur = 0; opacity = 1; offsetY = 0
                }
            }
        }
    }
}

private extension View {
    func tabBloom(isActive: Bool) -> some View { modifier(TabBloom(isActive: isActive)) }
}
