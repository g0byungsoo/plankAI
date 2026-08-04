import SwiftUI
import SwiftData
import PlankSync
import PlankFood

// MARK: - TodayModuleHost
//
// The cover/sheet attachment point for TodayView — the same module
// views PlanView hosted, with identical completion semantics,
// wrapped as one modifier so TodayView stays composition.

private struct TodayModuleHost: ViewModifier {
    // @Observable class — passed by reference; mutations observed.
    let state: TodayModuleState
    let userId: String
    let snapshot: TodaySnapshot?
    let onMutation: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false
    @AppStorage("onboardingCuisinePreference") private var cuisineProfileCSV: String = ""
    @State private var scanExplosionTrigger = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                state.modelContext = modelContext
                state.userId = userId
                state.onMutation = onMutation
                // v9 P1 QA door — land directly on the scan module
                // (pairs with --uitest-scan-allow-manual on the sim).
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-body-scan"),
                   state.activeCover == nil {
                    state.present(cover: .bodyScan)
                }
            }
            .onChange(of: userId) { _, uid in
                state.userId = uid
            }
            .fullScreenCover(item: coverBinding) { cover in
                coverContent(cover)
            }
            .sheet(item: sheetBinding) { sheet in
                sheetContent(sheet)
            }
    }

    private var coverBinding: Binding<TodayModuleState.Cover?> {
        Binding(get: { state.activeCover }, set: { state.activeCover = $0 })
    }
    private var sheetBinding: Binding<TodayModuleState.Sheet?> {
        Binding(get: { state.activeSheet }, set: { state.activeSheet = $0 })
    }

    // MARK: - Covers

    @ViewBuilder
    private func coverContent(_ cover: TodayModuleState.Cover) -> some View {
        switch cover {
        case .jeniNote:
            JeniNoteView(
                brief: snapshot?.brief ?? DailyBriefEngine.Brief(
                    line: "today is yours", italic: [], chatSeed: nil
                ),
                dateline: Date.now.formatted(.dateTime.weekday(.wide)).lowercased(),
                onReply: {
                    let seed = snapshot?.brief.chatSeed
                    state.dismissCover()
                    AppRouter.shared.openChat(seed: seed)
                },
                onClose: { state.dismissCover() }
            )
            .presentationBackground(Palette.bgPrimary)

        case .lesson:
            // v3: the method's daily moment is THE REP (practice, not
            // reading); the reader survives as "the whole idea" inside
            // it. ONE resolver (MethodResolver — fixes the two sites
            // that still read the zero-writer CohortFlags.fromAppStorage,
            // silently resolving cohort variants on defaults). The
            // legacy JeniMethodRitualView fallback is gone: the rep
            // runs even when no lesson resolves.
            if let resolution = MethodResolver.resolve(
                plan: snapshot?.plan,
                programDay: snapshot?.programDay ?? 0
            ) {
                RepView(
                    rep: RepEngine.rep(for: resolution.ref),
                    resolution: resolution,
                    onKept: { state.markAuto(.lesson(lessonId: nil)) },
                    onClose: { state.dismissCover() }
                )
                .presentationBackground(Palette.bgPrimary)
            } else {
                RepView(
                    rep: RepEngine.beginAgainRep,
                    resolution: nil,
                    onKept: { state.markAuto(.lesson(lessonId: nil)) },
                    onClose: { state.dismissCover() }
                )
                .presentationBackground(Palette.bgPrimary)
            }

        case .captureFlow:
            ZStack {
                CaptureFlowView(
                    userId: userId,
                    cuisineProfile: cuisineProfileCSV.isEmpty ? nil : cuisineProfileCSV,
                    archetypeHint: snapshot?.day?.archetype.rawValue,
                    onDismiss: {
                        state.dismissCover()
                        // userId-SCOPED check (v4 fix): the unscoped
                        // todayKcalTotal() summed every identity on
                        // the device, so a stale account's plates
                        // could mark THIS user's snap beat kept while
                        // her band read empty — the same viewport
                        // contradicting itself.
                        if FoodLogPersister.todayAndWeekly(userId: userId).today > 0 {
                            state.markAuto(.snapMeal)
                        }
                    },
                    onResultLanded: { scanExplosionTrigger += 1 }
                )
                FoodResultExplosion(triggerId: scanExplosionTrigger)
                    .allowsHitTesting(false)
            }
            .presentationBackground(Palette.bgPrimary)

        case .bodyScan:
            BodyScanFlowView(
                userId: userId,
                onClose: { state.dismissCover() }
            )
            .presentationBackground(Palette.bgPrimary)

        case .preRoutine(let workout):
            Group {
                if state.routineStep == .pre {
                    PreRoutineView(
                        workout: workout,
                        onStart: {
                            Analytics.track(.workoutStart, properties: [
                                "workout_name": workout.name,
                                "duration_min": workout.estimatedDuration,
                                "source": "today_beats"
                            ])
                            if !hasCompletedFirstSession {
                                Analytics.track(.firstWorkoutStart, properties: [
                                    "workout_name": workout.name
                                ])
                            }
                            withAnimation(Motion.crossFade) {
                                state.routineStep = .session
                            }
                        },
                        onCancel: { state.dismissCover() },
                        onShrink: { state.shrinkWorkoutToFloor() }
                    )
                    .transition(.opacity)
                } else {
                    RoutineSessionView(workout: workout) { results, duration, rating in
                        let didMeet = SessionCompletion.didMeetThreshold(
                            results, isGentle: workout.isGentle
                        )
                        if didMeet {
                            if !hasCompletedFirstSession {
                                Analytics.track(.firstWorkoutComplete, properties: [
                                    "workout_name": workout.name,
                                    "duration_seconds": Int(duration)
                                ])
                            }
                            Analytics.track(.workoutComplete, properties: [
                                "workout_name": workout.name,
                                "duration_seconds": Int(duration)
                            ])
                            state.saveRoutineSession(
                                workout: workout, results: results,
                                duration: duration, rating: rating
                            )
                            hasCompletedFirstSession = true
                            state.markAuto(.workout(tier: .medium, minutes: 0, bodyFocus: nil))
                        }
                        state.dismissCover()
                    }
                    .transition(.opacity)
                }
            }
            .presentationBackground(Palette.bgPrimary)

        case .breathSession:
            BreathworkFlowView(
                onComplete: { minutes, techProtocol in
                    let style: ProgramDayPrescription.BreathStyle =
                        techProtocol == .energizing ? .energizing : .calming
                    state.markAuto(.breath(minutes: minutes, style: style))
                    state.dismissCover()
                },
                onDismiss: { state.dismissCover() }
            )
            .presentationBackground(Palette.bgPrimary)
        }
    }

    /// Weigh-ins already on file — the ritual's confirmation copy is
    /// count-aware (first / second / steady-state).
    private func priorWeighInCount() -> Int {
        guard !userId.isEmpty else { return 0 }
        let uid = userId
        let d = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid }
        )
        return (try? modelContext.fetchCount(d)) ?? 0
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: TodayModuleState.Sheet) -> some View {
        switch sheet {
        case .logWeight:
            JKWeightRitual(
                startingFromKg: snapshot?.latestWeightKg ?? 65,
                priorLoggedCount: priorWeighInCount(),
                isUpdatingToday: snapshot?.lastWeighInDaysAgo == 0,
                bandWhisper: {
                    // Keeping chapter: the save moment speaks the band
                    // (a zone is an action-opener, never an alarm).
                    guard snapshot?.chapter == .keeping,
                          let settle = BandModel.settleWeightKg(plan: snapshot?.plan),
                          let ema = snapshot?.latestWeightKg  // whisper reads today's save context
                    else { return nil }
                    switch BandModel.zone(emaKg: ema, settleKg: settle) {
                    case .steady: return "inside your band. steady"
                    case .drifting: return "a touch above your band. this week steadies it, gently."
                    case .reset: return "above your band. jeni has the plan. no alarm, just a plan."
                    }
                }(),
                onSave: { newKg in
                    // Persist immediately; the sheet owns its exit via
                    // onDone so the kept-beat is never cut short.
                    state.persistWeight(kg: newKg)
                    state.markAuto(.weighIn)
                },
                onDone: { state.dismissSheet() },
                onCancel: { state.dismissSheet() }
            )
            .presentationDetents([.fraction(0.7)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)

        case .markAsDone(let prescription):
            MarkAsDoneSheet(
                prescription: prescription,
                onConfirm: {
                    state.mark(prescription, state: .complete)
                    state.dismissSheet()
                },
                onDismiss: { state.dismissSheet() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Palette.bgElevated)

        case .profileHub:
            ProfileHubView(onClose: { state.activeSheet = nil })
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)

        case .stepsDetail:
            TodayStepsSheet(goal: snapshot?.targets.steps ?? TargetsService.stepsGoal(plan: nil))
                .presentationDetents([.fraction(0.7)])
                .presentationBackground(Palette.bgPrimary)

        case .regimen:
            RegimenSheet(
                userId: userId,
                onDone: {
                    state.dismissSheet()
                    onMutation()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)

        }
        // v4: dayPeek / dayLock / herDays / dayReview mounts died with
        // the journey rebuild — past days are becoming's ledger now.
    }
}

extension View {
    func todayModuleHost(
        state: TodayModuleState,
        userId: String,
        snapshot: TodaySnapshot?,
        onMutation: @escaping () -> Void
    ) -> some View {
        modifier(TodayModuleHost(
            state: state,
            userId: userId,
            snapshot: snapshot,
            onMutation: onMutation
        ))
    }
}
