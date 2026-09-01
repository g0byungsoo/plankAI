import Foundation

// MARK: - SnapRefineMerge (v25 E2 — B11)
//
// The deterministic guard behind "fix it with words". Primary
// evidence (SnappyMeal ablation, 07_NEXT_ERA_DECISION §3.1): letting
// a model re-estimate a whole plate after a correction DEGRADES the
// items the correction never mentioned — a correct answer about
// bacon moved the eggs. The fix is scope, applied client-side where
// it cannot be disobeyed:
//
// - the NOTE decides which items the correction may touch (token
//   overlap between her words and each item's name — deterministic,
//   testable, no second model call);
// - a mentioned, changed item takes the model's correction;
// - an UNMENTIONED item keeps its exact current values and identity,
//   whatever the model returned for it (echo drift is discarded);
// - new items survive only when the note names them (hallucinated
//   additions die here);
// - a one-for-one swap (old dish named, new dish named, both
//   unmatched) is a rename and replaces in place;
// - nothing is ever silently deleted;
// - a note that names nothing is a plate-global correction ("half
//   of all that") and the model's answer applies wholesale — the
//   guard scopes targeted corrections, it doesn't break global ones.

enum SnapRefineMerge {

    static let kcalEpsilon = 1.0
    static let gramEpsilon = 0.5
    static let portionEpsilon = 1.0

    static func merge(
        current: [CapturedItem],
        response: [CapturedItem],
        note: String
    ) -> [CapturedItem] {
        let noteTokens = tokens(of: note)
        let anyMention = current.contains { isMentioned($0, in: noteTokens) }
            || response.contains { isMentioned($0, in: noteTokens) }

        // A note that names nothing is plate-global: the model's
        // interpretation is the only one available.
        guard anyMention else { return response }

        var consumed = Set<Int>()   // response indices already used
        var merged: [CapturedItem] = []
        var unmatchedCurrentIdx: [Int] = []

        for (ci, item) in current.enumerated() {
            let match = response.indices.first { ri in
                !consumed.contains(ri)
                    && normalized(response[ri].name) == normalized(item.name)
            }
            if let ri = match {
                consumed.insert(ri)
                let r = response[ri]
                if nutritionApproxEqual(item, r) || !isMentioned(item, in: noteTokens) {
                    // Unchanged echo, or drift on an item her words
                    // never touched — her current item stands,
                    // identity and provenance intact.
                    merged.append(item)
                } else {
                    // A mentioned item, corrected: the model's answer
                    // lands on the EXISTING identity.
                    merged.append(withId(item.id, from: r))
                }
            } else {
                merged.append(item)   // provisionally kept; rename may replace
                unmatchedCurrentIdx.append(ci)
            }
        }

        let newcomers = response.indices
            .filter { !consumed.contains($0) }
            .map { response[$0] }
            .filter { isMentioned($0, in: noteTokens) }

        // The one-for-one swap: exactly one item of each side
        // unmatched, and the note reads as a REPLACEMENT. Two ways to
        // qualify:
        //   - the old dish is named ("that's not carbonara, it's cacio
        //     e pepe") — the original rule; or
        //   - p61: only the NEW dish is named, but the note's shape is
        //     a correction and not an addition ("that's actually a
        //     panini"). The old rule refused this — the commonest
        //     rename there is — and kept BOTH dishes, a spoken
        //     correction that doubled the plate.
        // An addition-shaped note ("add the fries", "forgot the
        // yogurt") never swaps: if the model dropped an unmentioned
        // item alongside her addition, both are kept — nothing is ever
        // silently deleted.
        if unmatchedCurrentIdx.count == 1, newcomers.count == 1,
           let oldIdx = unmatchedCurrentIdx.first,
           isMentioned(current[oldIdx], in: noteTokens)
               || readsAsReplacement(noteTokens),
           let mergedIdx = merged.firstIndex(where: { $0.id == current[oldIdx].id }) {
            // p61 — the identity survives the rename, exactly as the
            // matched-name correction path keeps it: the photograph is
            // keyed by the item's plate, and a swap is a correction,
            // not a new fact.
            merged[mergedIdx] = withId(current[oldIdx].id, from: newcomers[0])
            return merged
        }

        return merged + newcomers
    }

    /// Does the note's shape say "what I told you was wrong" rather
    /// than "there was more"? Addition markers veto (an addition must
    /// never delete); replacement markers qualify. Deterministic token
    /// sets, no model.
    static func readsAsReplacement(_ noteTokens: Set<String>) -> Bool {
        let addition: Set<String> = [
            "add", "added", "adding", "also", "plus", "another",
            "extra", "side", "forgot", "missed", "missing", "include",
        ]
        guard noteTokens.isDisjoint(with: addition) else { return false }
        let replacement: Set<String> = [
            "actually", "instead", "not", "wrong", "meant", "swap",
            "replace", "replaced", "change", "changed", "make",
            "mistake", "really", "rather",
        ]
        return !noteTokens.isDisjoint(with: replacement)
    }

    // MARK: mention detection

    static func isMentioned(_ item: CapturedItem, in noteTokens: Set<String>) -> Bool {
        var nameTokens = tokens(of: item.name.foodNameCleaned)
        if let english = item.englishName {
            nameTokens.formUnion(tokens(of: english))
        }
        return nameTokens.contains { name in
            noteTokens.contains { note in
                note == name || note == name + "s" || name == note + "s"
            }
        }
    }

    static func tokens(of text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
        )
    }

    private static func normalized(_ name: String) -> String {
        name.foodNameCleaned.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nutritionApproxEqual(
        _ a: CapturedItem, _ b: CapturedItem
    ) -> Bool {
        func close(_ x: Double?, _ y: Double?, _ eps: Double) -> Bool {
            switch (x, y) {
            case (nil, nil): return true
            case let (x?, y?): return abs(x - y) <= eps
            default: return false
            }
        }
        return close(a.kcal, b.kcal, kcalEpsilon)
            && close(a.proteinG, b.proteinG, gramEpsilon)
            && close(a.carbsG, b.carbsG, gramEpsilon)
            && close(a.fatG, b.fatG, gramEpsilon)
            && abs(a.portionGrams - b.portionGrams) <= portionEpsilon
    }

    /// The model's corrected values on the existing item's identity.
    ///
    /// A mutation of the model's item, not a 25-parameter re-init. The
    /// re-init dropped `micros` — the fourth time in this package that a
    /// hand-written init with defaulted parameters silently lost a field
    /// the compiler could not see was missing. Identity is the only thing
    /// that has to be carried across, so it is the only thing named.
    private static func withId(_ id: String, from r: CapturedItem) -> CapturedItem {
        var out = r
        out.id = id
        return out
    }
}
