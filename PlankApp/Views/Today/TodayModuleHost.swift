import SwiftUI
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
        case let .lesson(programDay, totalDays):
            if let resolved = CBTCurriculumService.shared.lesson(
                forProgramDay: programDay,
                totalDays: totalDays,
                cohort: CohortFlags.fromAppStorage()
            ) {
                LessonReaderView(
                    scheduled: resolved.scheduled,
                    slot: resolved.slot,
                    variant: resolved.variant,
                    onComplete: {
                        state.markAuto(.lesson(lessonId: nil))
                        state.dismissCover()
                    },
                    onSkip: { _ in state.dismissCover() }
                )
                .presentationBackground(Palette.bgPrimary)
            } else {
                JeniMethodRitualView(
                    lesson: LessonID(rawValue: JeniMethodState.lessonId(forDay: programDay)) ?? .generic,
                    user: JeniMethodUserContext.fromAppStorage(),
                    onComplete: {
                        state.markAuto(.lesson(lessonId: nil))
                        state.dismissCover()
                    },
                    onSkip: { _ in state.dismissCover() }
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
                        if FoodLogPersister.todayKcalTotal() > 0 {
                            state.markAuto(.snapMeal)
                        }
                    },
                    onResultLanded: { scanExplosionTrigger += 1 }
                )
                FoodResultExplosion(triggerId: scanExplosionTrigger)
                    .allowsHitTesting(false)
            }
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
                        onCancel: { state.dismissCover() }
                    )
                    .transition(.opacity)
                } else {
                    RoutineSessionView(workout: workout) { results, duration, rating in
                        let didMeet = SessionCompletion.didMeetThreshold(results)
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

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: TodayModuleState.Sheet) -> some View {
        switch sheet {
        case .logWeight:
            LogWeightSheet(
                startingFromKg: snapshot?.latestWeightKg ?? 65,
                isUpdatingToday: snapshot?.lastWeighInDaysAgo == 0,
                onSave: { newKg in
                    state.persistWeight(kg: newKg)
                    state.markAuto(.weighIn)
                    state.dismissSheet()
                },
                onCancel: { state.dismissSheet() }
            )
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgElevated)

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
        }
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
