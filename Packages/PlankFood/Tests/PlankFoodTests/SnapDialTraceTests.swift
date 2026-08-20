#if canImport(UIKit)
import XCTest
@testable import PlankFood

// PASS 48 — the dial's reading has to drive itself.
//
// The defect these pin: `SnapDial` drove its trace ONLY from
// `.onChange(of: isScanning)` / `.onChange(of: scanComplete)`, and
// `.onChange` never fires for the value a view is born with. The
// onboarding demo inserts the dial with `if phase != .pick` at the
// instant phase becomes `.scanning`, so the dial arrived already
// reading, no change was ever seen, and the trace stayed at 0 for the
// whole wait. Measured before the fix: two independent launches gave
// byte-identical screenshots 0.38s apart, mid-reading.
//
// So the question a test has to answer is not "does onChange work" —
// it is "given the state the dial is IN, what should the trace do?".
// That is what `plan` decides, and the born-scanning row is the row
// that did not exist.
final class SnapDialTraceTests: XCTestCase {

    // MARK: the row that was missing

    func testAReadingInFlightDrawsTheTrace() {
        let plan = SnapDial.plan(isScanning: true, scanComplete: false, reduceMotion: false)
        XCTAssertNotNil(plan, "a dial that is reading must have something to draw")
        XCTAssertEqual(plan?.target, 0.96,
                       "the trace draws to its hold point, not shut — the frame closes when the understanding lands")
        XCTAssertEqual(plan?.duration, 2.4)
        XCTAssertEqual(plan?.restartsFromZero, true,
                       "a reading always begins from a closed frame")
    }

    /// The same call the appearance hook makes. Stated separately
    /// because the whole defect was that this state was only ever
    /// reachable at birth, never as a transition.
    ///
    /// The first draft of this asserted only `born == changed`, which a
    /// before-state stub satisfies with nil == nil — the refusal trap
    /// this repo has recorded for ten sessions. It asserts a drawn
    /// trace now.
    func testTheTraceDrawsWhetherItArrivedByChangeOrWasBornThatWay() {
        let born = SnapDial.plan(isScanning: true, scanComplete: false, reduceMotion: false)
        let changed = SnapDial.plan(isScanning: true, scanComplete: false, reduceMotion: false)
        XCTAssertEqual(born, changed,
                       "the trace cannot depend on how the dial got here")
        XCTAssertEqual(born?.target, 0.96, "and it must actually draw")
    }

    // MARK: the understanding landing

    func testTheUnderstandingLandingClosesTheFrame() {
        let plan = SnapDial.plan(isScanning: false, scanComplete: true, reduceMotion: false)
        XCTAssertEqual(plan?.target, 1.0, "the frame closes")
        XCTAssertEqual(plan?.duration, 0.26)
        XCTAssertEqual(plan?.restartsFromZero, false,
                       "closing must continue from wherever the reading got to, never snap back")
    }

    /// Both flags flip in the same update when the reading lands. The
    /// two change hooks each re-plan, so they must agree.
    func testBothChangeHooksAgreeWhenTheReadingLands() {
        let viaScanning = SnapDial.plan(isScanning: false, scanComplete: true, reduceMotion: false)
        let viaComplete = SnapDial.plan(isScanning: true, scanComplete: true, reduceMotion: false)
        XCTAssertEqual(viaScanning, viaComplete,
                       "a landed reading closes the frame no matter which flag is read first")
    }

    // MARK: reduce motion

    func testReduceMotionDrawsNoTrace() {
        let plan = SnapDial.plan(isScanning: true, scanComplete: false, reduceMotion: true)
        XCTAssertEqual(plan?.target, 0, "no trace under reduce motion — the caption carries the wait")
        XCTAssertEqual(plan?.duration, 0, "and it does not animate to nothing")
    }

    /// A state change is not a flourish: the frame still closes when the
    /// reading lands, because that is the product saying it is done.
    /// This is the behaviour that shipped before this pass, kept.
    func testReduceMotionStillClosesTheFrameOnLanding() {
        let plan = SnapDial.plan(isScanning: false, scanComplete: true, reduceMotion: true)
        XCTAssertEqual(plan?.target, 1.0)
    }

    // MARK: the resting aim — the control

    /// `PhotoCaptureView` mounts the dial idle and leaves it idle; it is
    /// the only other call site in the product. The appearance hook must
    /// be a no-op there, or this pass would have put an animation on the
    /// camera's resting frame.
    func testTheRestingAimIsLeftClosed() {
        let plan = SnapDial.plan(isScanning: false, scanComplete: false, reduceMotion: false)
        XCTAssertEqual(plan?.target, 0,
                       "an idle dial has a closed trace and nothing to draw")
    }

    func testAReadingThatDidNotLandLetsGo() {
        // failure / cancel: scanning stops without completion.
        let plan = SnapDial.plan(isScanning: false, scanComplete: false, reduceMotion: false)
        XCTAssertEqual(plan?.target, 0, "the trace lets go")
        XCTAssertEqual(plan?.duration, 0.25, "quietly")
        XCTAssertEqual(plan?.restartsFromZero, false)
    }
}
#endif
