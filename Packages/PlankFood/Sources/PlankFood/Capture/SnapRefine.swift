import Foundation

// MARK: - SnapRefine
//
// v1.2 snap-food rebuild (2026-07-01) — the natural-language
// correction pipeline behind "fix it with words" and "+ add
// something" on the result card. The single most-loved correction
// affordance in the category (Cal AI's Fix Results, Lifesum's chat
// edit), built on the food-vision EF's EXISTING text path — the same
// endpoint quick-add has shipped on since v1.0.9, so this works
// against the currently-deployed backend with no server change.
//
// How: the correction prompt carries the current estimate (names,
// portions, kcal, macros) as context plus the user's words, and asks
// for the full corrected plate back through the same strict JSON
// schema. Additions ask for only the new item(s).
//
// A richer photo+prior+note mode (image attached to the correction)
// needs the EF to read `text` alongside `image_base64`; that server
// patch ships separately and this client composes the same prompts
// either way.

public enum SnapRefineRequest {
    /// "tell jeni what's off" — free-text correction of the whole plate.
    case fixWords(current: CapturedFood, note: String)
    /// "+ add something" — describe an item the scan missed.
    case addItem(note: String)
}

public enum SnapRefineOutcome {
    case rebased(CapturedFood)
    case added([CapturedItem])
}

@MainActor
enum SnapRefine {

    enum RefineError: Error {
        case emptyResponse
    }

    static func run(
        _ request: SnapRefineRequest,
        dispatcher: FoodCaptureDispatcher,
        cuisineProfile: String? = nil
    ) async throws -> SnapRefineOutcome {
        switch request {

        case .fixWords(let current, let note):
            let prompt = fixPrompt(current: current, note: note)
            let response = try await dispatcher.dispatch(
                .text(prompt, cuisineProfile: cuisineProfile)
            )
            guard !response.items.isEmpty else { throw RefineError.emptyResponse }
            // The corrected items + honesty bounds come from the model;
            // plate identity (type, capture source, second-photo state)
            // stays with the original scan — it's still the same photo.
            let merged = CapturedFood(
                items: response.items,
                plateType: current.plateType,
                source: current.source,
                confidence: response.confidence,
                needsSecondPhoto: current.needsSecondPhoto,
                secondPhotoHint: current.secondPhotoHint,
                kcalLow: response.kcalLow,
                kcalHigh: response.kcalHigh
            )
            return .rebased(merged)

        case .addItem(let note):
            let prompt = addPrompt(note: note)
            let response = try await dispatcher.dispatch(
                .text(prompt, cuisineProfile: cuisineProfile)
            )
            guard !response.items.isEmpty else { throw RefineError.emptyResponse }
            return .added(response.items)
        }
    }

    // MARK: - Prompts

    /// The current estimate, serialized compactly so the model corrects
    /// FROM our numbers instead of re-guessing the whole plate.
    static func fixPrompt(current: CapturedFood, note: String) -> String {
        let ledger = current.items.map { item in
            let kcal = Int((item.kcal ?? 0).rounded())
            let p = Int((item.proteinG ?? 0).rounded())
            let c = Int((item.carbsG ?? 0).rounded())
            let f = Int((item.fatG ?? 0).rounded())
            return "\(item.name): \(Int(item.portionGrams.rounded()))g, "
                + "\(kcal) kcal, \(p)g protein, \(c)g carbs, \(f)g fat"
        }
        .joined(separator: "; ")
        let total = Int(current.items.compactMap(\.kcal).reduce(0, +).rounded())
        return "correct a previous meal estimate. the current estimate is: "
            + "\(ledger) (plate total about \(total) kcal). "
            + "the user's correction: \"\(sanitized(note))\". "
            + "apply the correction and return the FULL corrected plate: "
            + "every item including unchanged ones, with corrected portions, "
            + "kcal and macros. keep items the correction doesn't mention as they are."
    }

    static func addPrompt(note: String) -> String {
        "the user is adding to an already-logged meal: \"\(sanitized(note))\". "
            + "return ONLY the added food item or items, with portion, kcal and "
            + "macros. if the portion isn't specified, assume one standard "
            + "serving and reflect the uncertainty in the confidence and ranges."
    }

    /// Strip quote characters that would break the prompt's framing.
    private static func sanitized(_ note: String) -> String {
        note.replacingOccurrences(of: "\"", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
