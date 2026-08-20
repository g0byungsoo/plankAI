import Foundation

// MARK: - FoodUsuals (app v25 pass 53 — THE ANSWERING RECORD)
//
// The personal food graph, computed — never stored. People eat the
// same ~20 foods; the record already holds every plate she ever
// filed, so "her usuals" is a pure fold over it: group by the SAME
// normalized title PlatePriors uses (one normalizer, or "pad thai"
// is one prior and two rails), rank by frequency then recency, and
// let each usual answer with her LATEST VERIFIED numbers (a spoken
// fix or a hand edit outranks a stale estimate).
//
// Two match doors, both exact:
// - the SAME typed sentence (normalized) → her usual, served as a
//   plate with `usualApplied` provenance and the fresh estimate one
//   tap away. A qualifier ("half a…", "…with berries") is
//   contradictory evidence and never matches — the pass-27 law that
//   a memory must not overrule what she stated.
// - the SAME barcode, only when she VERIFIED the entry — the
//   package's printed numbers are otherwise the freshest truth.
//
// A usual is not a PlatePriors prior: priors scale a MODEL estimate
// of a dish; a usual replays HER OWN filed plate. The two memories
// never stack (`plate(from:)` leaves `priorApplied` nil and stamps
// `.again`, the door that already tells this truth).

public enum FoodUsuals {

    public struct Usual: Sendable {
        /// The display title (the representative entry's own).
        public var title: String
        /// How many times this food has been filed.
        public var useCount: Int
        /// The most recent filing.
        public var lastAt: Date
        /// The representative entry: latest VERIFIED, else latest.
        public var entry: FoodLogPersister.FoodLogEntry
        /// True when the representative carries her own fix or edit.
        public var isVerified: Bool
    }

    /// Frequency-then-recency, one usual per normalized title. Each
    /// usual answers with her latest VERIFIED entry when one exists
    /// (a fix outranks a stale estimate), else the latest filing.
    public static func rank(
        _ entries: [FoodLogPersister.FoodLogEntry], limit: Int = 6
    ) -> [Usual] {
        // `allEntries` hands rows newest-first; the fold keeps that
        // order inside each group so "latest" is index 0.
        var order: [String] = []
        var groups: [String: [FoodLogPersister.FoodLogEntry]] = [:]
        for entry in entries {
            let key = PlatePriors.normalize(entry.title)
            guard !key.isEmpty, entry.kcal > 0 else { continue }
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(entry)
        }
        let usuals: [Usual] = order.compactMap { key in
            guard let list = groups[key], let newest = list.first else { return nil }
            let representative = list.first(where: \.wasVerified) ?? newest
            return Usual(
                title: representative.title,
                useCount: list.count,
                lastAt: newest.loggedAt,
                entry: representative,
                isVerified: representative.wasVerified
            )
        }
        return Array(
            usuals.sorted {
                $0.useCount != $1.useCount
                    ? $0.useCount > $1.useCount
                    : $0.lastAt > $1.lastAt
            }.prefix(limit)
        )
    }

    /// Her usual for an exactly-matching typed sentence, or nil. A
    /// qualifier ("half a…", "…with berries") normalizes to a
    /// different key and never matches — contradictory evidence runs
    /// the estimate fresh, always.
    public static func match(
        sentence: String, in entries: [FoodLogPersister.FoodLogEntry]
    ) -> Usual? {
        let key = PlatePriors.normalize(sentence)
        guard !key.isEmpty else { return nil }
        let typed = sentence.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rank(entries, limit: .max).first { usual in
            let raw = usual.entry.title.lowercased()
            // Naming the whole plate, artifact and all, always works.
            if typed == raw { return true }
            guard PlatePriors.normalize(usual.entry.title) == key else { return false }
            // p55 — the SUBTRACTIVE half of the qualifier law. The
            // normalizer strips the persister's " + N more" suffix, so
            // "greek yogurt" exact-matched a filed "greek yogurt +
            // 2 more" and re-served granola and honey she never said.
            // A plate holding foods beyond the sentence is
            // contradictory evidence, exactly like "half a…".
            let holdsMore = raw.range(
                of: #" \+ \d+ more$"#, options: .regularExpression
            ) != nil || (usual.entry.itemsDetail?.count ?? 1) > 1
            return !holdsMore
        }
    }

    /// Her VERIFIED usual for a package code, or nil. Unverified
    /// entries stay quiet: the package's printed numbers are the
    /// freshest truth until she says otherwise.
    public static func match(
        barcode: String, in entries: [FoodLogPersister.FoodLogEntry]
    ) -> Usual? {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let matching = entries.filter { $0.barcode == code }
        guard let verified = matching.first(where: \.wasVerified) else { return nil }
        return Usual(
            title: verified.title,
            useCount: matching.count,
            lastAt: matching.first?.loggedAt ?? verified.loggedAt,
            entry: verified,
            isVerified: true
        )
    }

    /// The usual, served as a plate: her items, her numbers, `.again`
    /// provenance (the door that already means "from your record"),
    /// `usualApplied` stamped for the reading's banner, no prior.
    public static func plate(
        from usual: Usual, via: CapturedFood.UsualApplied.Via
    ) -> CapturedFood {
        let entry = usual.entry
        // The code rides the first item's id (the reader's own
        // shape), so re-filing keeps the verify-once key.
        func itemId(_ index: Int) -> String {
            if index == 0, let code = entry.barcode {
                return "barcode-" + code
            }
            return UUID().uuidString
        }
        var items: [CapturedItem]
        if let detail = entry.itemsDetail, !detail.isEmpty {
            items = detail.enumerated().map { index, d in
                CapturedItem(
                    id: itemId(index),
                    name: d.name,
                    portionGrams: d.portionG,
                    portionGramsLow: d.portionG,
                    portionGramsHigh: d.portionG,
                    usdaSearchTerms: [d.name],
                    preparation: nil, cuisineHint: nil,
                    confidence: nil, notes: nil,
                    kcal: d.kcal, proteinG: d.protein,
                    carbsG: d.carbs, fatG: d.fat,
                    fiberG: nil, nutritionSource: nil,
                    sodiumMg: d.sodiumMg, saturatedFatG: d.satFatG
                )
            }
            // Fiber + sugar live at plate level only — the first
            // item carries them so re-filing keeps the totals true.
            if entry.fiber > 0 { items[0].fiberG = entry.fiber }
            if entry.sugar > 0 { items[0].sugarG = entry.sugar }
        } else {
            items = [CapturedItem(
                id: itemId(0),
                name: entry.title,
                portionGrams: 0, portionGramsLow: 0, portionGramsHigh: 0,
                usdaSearchTerms: [entry.title],
                preparation: nil, cuisineHint: nil,
                confidence: nil, notes: nil,
                kcal: entry.kcal, proteinG: entry.protein,
                carbsG: entry.carbs, fatG: entry.fat,
                fiberG: entry.fiber > 0 ? entry.fiber : nil,
                nutritionSource: nil,
                sugarG: entry.sugar > 0 ? entry.sugar : nil,
                sodiumMg: entry.sodiumMg > 0 ? entry.sodiumMg : nil,
                saturatedFatG: entry.satFatG > 0 ? entry.satFatG : nil
            )]
        }
        var food = CapturedFood(
            items: items, plateType: .single, source: .again,
            confidence: nil, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        food.appliedCorrections = entry.corrections ?? []
        food.editNotes = entry.edits ?? []
        food.usualApplied = CapturedFood.UsualApplied(
            title: usual.title,
            lastAt: usual.lastAt,
            timesLogged: usual.useCount,
            verified: usual.isVerified,
            via: via
        )
        return food
    }
}
