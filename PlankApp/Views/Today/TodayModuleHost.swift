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

    /// v25 E8.1 — today's Method note, or nil. Composed at render time
    /// from the SAME snapshot this host already holds, so the note can
    /// never contradict the Today page it opened from.
    private var methodNote: ResolvedMethodNote? {
        guard let snapshot else { return nil }
        var clinic = MethodClinicSource.Resolved.empty
        #if DEBUG
        clinic = MethodClinicSource.resolve(MethodClinicSource.debugBundle)
        #endif
        return MethodEngine.note(
            MethodInputBuilder.input(
                userId: userId, snapshot: snapshot,
                clinic: clinic, in: modelContext
            )
        )
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                state.modelContext = modelContext
                state.userId = userId
                state.onMutation = onMutation
                #if DEBUG
                // v9 P1 QA door — land directly on the scan module
                // (pairs with --uitest-scan-allow-manual on the sim).
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-body-scan"),
                   state.activeCover == nil {
                    state.present(cover: .bodyScan)
                }
                // v25 E8.1 — the Method note, opened directly. The beat's
                // own row is inside a scrollable to-do list, and a
                // synthesized drag cannot scroll the iOS 26 simulator
                // (probe-proven, v12), so without this door the surface
                // could not be filmed at all.
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-method"),
                   state.activeCover == nil {
                    state.present(cover: .lesson(
                        programDay: snapshot?.programDay ?? 1,
                        totalDays: snapshot?.totalDays ?? 140
                    ))
                }
                #endif
            }
            .onChange(of: userId) { _, uid in
                state.userId = uid
            }
            // v25 E4 (J1 fix): ANY plate that lands today marks the
            // food beat — the camera, the book's "log it again", and
            // jeni's log_food_text all count. Before this, only the
            // capture flow's own dismiss marked, so a meal logged
            // through jeni left the row unchecked and the kept-day
            // ring unearned. Guarded on count so a deletion that
            // empties the day never marks.
            .onReceive(FoodLogPersister.changeNotifier) { _ in
                guard state.activeCover == nil,
                      FoodLogPersister.todayAndWeekly(userId: userId).today > 0
                else { return }
                state.markAuto(.snapMeal)
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
            .presentationCornerRadius(28)

        case .lesson:
            // v25 E8.1 — THE METHOD IS A NOTE, NOT A LESSON.
            //
            // This beat used to resolve today's slot out of an 84-lesson
            // manifest by program day. On a base where 82% of onboarded
            // users have exactly one active day and the payer median is
            // 2.0, that meant lessons 3 through 84 were unreachable by
            // construction — and it meant the "scale is up two pounds"
            // rep fired on program day 19 whether or not her scale had
            // moved.
            //
            // `MethodEngine` reads her actual record and returns at most
            // one note, or NOTHING. When it returns nothing the cover
            // dismisses immediately and the beat marks itself, which is
            // the point: there is no generic fallback, because a
            // fallback is what makes a teaching surface into wallpaper.
            if let resolved = methodNote {
                MethodNoteView(
                    resolved: resolved,
                    onKept: { state.markAuto(.lesson(lessonId: nil)) },
                    onClose: { state.dismissCover() }
                )
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
            } else if snapshot == nil {
                // NOT the same as "no note". The snapshot loads
                // asynchronously, so a cover opened on the first frame
                // would find nil and dismiss itself before the engine had
                // any inputs at all. Filming caught it: the surface
                // flashed and vanished. Wait for the record.
                Color.clear
            } else {
                // Silence is a first-class outcome. Nothing renders and
                // the beat closes rather than manufacturing something to
                // say.
                Color.clear
                    .onAppear {
                        state.markAuto(.lesson(lessonId: nil))
                        state.dismissCover()
                    }
            }

        case .captureFlow:
            // v23 pass 4 — the Lottie explosion retired (founder
            // steer); the reading's own choreography is the moment.
            CaptureFlowView(
                userId: userId,
                cuisineProfile: cuisineProfileCSV.isEmpty ? nil : cuisineProfileCSV,
                archetypeHint: snapshot?.day?.archetype.rawValue,
                // v25 E3 — present = jeni opened this with the user's
                // own words; the flow starts on describe, not camera.
                describePrefill: state.describePrefill,
                // v25 E7 — the capture surface's field submits straight
                // through; jeni's prefill still opens the field.
                entry: state.describeWasSpoken ? .words : .camera,
                autoSubmitPrefill: state.describeWasSpoken,
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
                }
            )
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)

        case .bodyScan:
            BodyScanFlowView(
                userId: userId,
                onClose: { state.dismissCover() }
            )
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)

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
            .presentationCornerRadius(28)

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
            .presentationCornerRadius(28)
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
            .presentationDetents(JeniSheetHeight.tallFixed)
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)

        case .markAsDone(let prescription):
            MarkAsDoneSheet(
                prescription: prescription,
                onConfirm: {
                    state.mark(prescription, state: .complete)
                    state.dismissSheet()
                },
                onDismiss: { state.dismissSheet() }
            )
            .presentationDetents(JeniSheetHeight.tall)
            .presentationDragIndicator(.hidden)
            .presentationBackground(Palette.bgElevated)
            .presentationCornerRadius(28)

        case .profileHub:
            ProfileHubView(onClose: { state.activeSheet = nil })
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)

        case .stepsDetail:
            // v25 E8.1 — JENI MOVE. The case name stays `stepsDetail`
            // because every existing entry point, deep link and QA arg
            // uses it; what it presents is now the movement record.
            MoveSheet(
                goal: snapshot?.targets.steps ?? TargetsService.stepsGoal(plan: nil),
                weightKg: snapshot?.latestWeightKg,
                openSession: {
                    state.dismissSheet()
                    let beat = snapshot?.day?.beats.first(where: {
                        if case .workout = $0 { return true } else { return false }
                    }) ?? .workout(tier: .soft, minutes: 10, bodyFocus: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        state.open(beat, snapshot: snapshot)
                    }
                }
            )
            // MOVE IS A PAGE, NOT A PEEK — founder, 2026-08-12: "make
            // this either 3/4 screen or almost full screen as user
            // having to scroll on this half pop up screen is not a good
            // ux design."
            //
            // It was `tallFixed`, whose own doc says it is for "a sheet
            // that must not be dragged taller (a camera or a canvas
            // underneath needs the room it has)". Move has neither. So
            // it sat at a single fixed 0.68 fraction while
            // `JKSheetChrome` hides the grabber — a sheet that opened
            // already scrolled, with no second detent and no affordance
            // to expand. At accessibility sizes exactly five items fit
            // and the entire record was below the fold.
            //
            // `.large` is what every other sheet that carries a RECORD
            // already uses (the plate detail, the profile hub, care
            // connect), and `JeniSheetHeight`'s own comment says full-page
            // surfaces stay there. E8.2 reached for `tallFixed` to stop
            // the header center-clipping; the ScrollView fixed that, and
            // the fraction was never the part that had to stay.
            .presentationDetents([.large])
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)
            .onAppear {
                Analytics.track(.moveOpened, properties: [
                    "health": StepsService.shared.authStatus == .authorized
                        ? "authorized" : "unavailable",
                ])
            }

        case .regimen:
            RegimenSheet(
                userId: userId,
                onDone: {
                    state.dismissSheet()
                    onMutation()
                }
            )
            .presentationDetents(JeniSheetHeight.tall)
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)

        case .methodTold:
            // E8.2 — the method door on a silent day: her kept notes,
            // the same surface settings shows. The empty state carries
            // the silence-first stance in its own words.
            NavigationStack { MethodToldView() }
                .presentationDetents(JeniSheetHeight.tall)
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)

        case .doseSheet(let slotDayKey):
            DoseSheet(
                userId: userId,
                slotDayKey: slotDayKey,
                onDone: {
                    state.dismissSheet()
                    onMutation()
                }
            )
            .presentationDetents(JeniSheetHeight.tall)
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)

        // v25 E4 — the plate's memory: the one-tap relog rail. The
        // beat-mark rides the changeNotifier listener above, so a
        // relog earns the ring exactly like a camera log.
        case .recentMeals:
            RecentMealsSheet(
                userId: userId,
                onLogged: { state.dismissSheet() },
                onClose: { state.dismissSheet() }
            )
            .presentationDetents(JeniSheetHeight.tall)
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)

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
