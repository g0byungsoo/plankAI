import Foundation

// Single source of truth for the standing safety line shown on every
// Learn screen in The JeniFit Method flow. Imported by both the lesson
// view AND the content invariant test suite so the two cannot drift.
// If a future copy author wants to soften this, they must edit it here
// and the test still passes — the invariant is "the line is present and
// identical to this constant," not "any safety line is acceptable."
enum JeniMethodSafetyLine {
    static let text = "JeniFit is a fitness app, not medical advice. If you're pregnant, have a medical condition, or a history of disordered eating, talk to a healthcare professional before changing how you eat."
}
