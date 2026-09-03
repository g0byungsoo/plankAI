import Foundation

// MARK: - CapturedFood
//
// Common output type returned by FoodCaptureDispatcher for every
// FoodCapture variant. The result card renders the same shape
// regardless of capture source — that's the seam that lets the UI
// stay simple while the pipelines stay specialized.
//
// Mirrors the LLM response schema in supabase/functions/food-vision/
// index.ts (FOOD_VISION_SCHEMA) but with USDA-joined kcal/macros
// populated where available. The .quickAdd and .imOutTonight paths
// produce CapturedFood with kcal already known (from canonical_pantry
// or rule-based estimate); the .photo path produces CapturedFood where
// kcal lands after the USDA join completes app-side.

public struct CapturedFood: Sendable {
    /// `var` on purpose. Every "copy this plate but change one thing"
    /// site in this package used to be a hand-written init with defaulted
    /// parameters, and the compiler cannot see an omission in one of
    /// those: `reattributeEntries` silently dropped a newly-added field
    /// three separate times (sugar + itemsDetail, sodium + satFat,
    /// corrections) and `SnapRefineMerge.withId` dropped `micros`. A
    /// mutation carries every field it did not name, by construction.
    public var items: [CapturedItem]
    public let plateType: PlateType
    /// WHICH DOOR this plate came through — the value that lands in
    /// `food_logs.source` and rides `food_log_saved` as `entry_method`.
    ///
    /// A `var` with an `.unknown` default because the decoders CANNOT
    /// know: `FoodVisionService` serves the photo, label and words doors
    /// from one response shape. The truth lives in the `FoodCapture`
    /// case, so `FoodCaptureDispatcher.dispatch` is the single
    /// chokepoint that stamps it, and `BarcodeRead` — which never passes
    /// through the dispatcher because it reads live off the video
    /// output — stamps its own.
    public var source: EntryMethod = .unknown
    public let confidence: Double?       // 0...1, nil for non-LLM sources
    public let needsSecondPhoto: Bool
    public let secondPhotoHint: String?  // nil unless needsSecondPhoto
    /// Range fields for `.imOutTonight` / `.restaurantRange` sources.
    /// nil for single-value sources. Per v3 §Honesty Doctrine:
    /// uncertainty is in COPY, not in a %, but range data drives the
    /// RestaurantRangeBar atom.
    ///
    /// `var` (pass 51): the two plate-rebuild sites (`rebuiltFood`,
    /// `PlatePriors.scale`) scale these with the total, and both used
    /// to re-init the whole plate to do it — the same field-drop shape
    /// as the item helpers, one level up.
    public var kcalLow: Double?
    public var kcalHigh: Double?

    /// p61 — the model's own answer to "did I actually see a nutrition
    /// facts panel?". `false` is definitive (she photographed food, or
    /// a wall, through the label door); nil is an EF that predates the
    /// field or a door that never asks. The label arm refuses the
    /// label's provenance on `false` — the exact lie E8.1 was named
    /// for, one door over: a guess wearing a declaration's clothes.
    public var modelSawNutritionLabel: Bool? = nil

    /// v25 E4 — every fix-with-words sentence applied to this plate,
    /// in order. Persisted with the entry (the corrections flywheel's
    /// raw material); empty for untouched plates.
    public var appliedCorrections: [String] = []

    /// p53 — structured notes for DELIBERATE hand edits (stepper,
    /// fraction, editor, remove, add). Their own channel: rendered
    /// beside her spoken fixes, persisted, carried by relog — but
    /// NEVER a PlatePriors source (pass 27's law: only a spoken fix
    /// describes the DISH; a hand edit describes her plate today).
    public var editNotes: [String] = []

    /// p53 — provenance of a plate served from HER OWN record (the
    /// same sentence, or the same barcode, answered from a prior
    /// entry instead of a fresh estimate). Rendered, never silent;
    /// the fresh estimate stays one tap away.
    public struct UsualApplied: Equatable, Sendable {
        public enum Via: String, Equatable, Sendable { case words, barcode }
        public var title: String
        public var lastAt: Date
        public var timesLogged: Int
        public var verified: Bool
        public var via: Via
        public init(
            title: String, lastAt: Date, timesLogged: Int,
            verified: Bool, via: Via
        ) {
            self.title = title
            self.lastAt = lastAt
            self.timesLogged = timesLogged
            self.verified = verified
            self.via = via
        }
    }
    public var usualApplied: UsualApplied? = nil

    /// v25 E4 — set when PlatePriors rewrote this plate from the
    /// user's own corrected record. Carries provenance for the
    /// reading's "your numbers" line and the one-tap revert.
    public var priorApplied: PlatePriors.Applied? = nil

    /// p72 — the day SHE stated, when her words named one ("last night
    /// i had…" → 1). nil = no day spoken, file to now. Stamped once at
    /// the words door (`SpokenDayReference`), read once at persist
    /// (`FoodLogPersister.statedLoggedAt`), shown on the reading before
    /// she confirms. Her stated numbers survive verbatim (p61); the day
    /// she names is the same class of fact.
    public var statedDaysAgo: Int? = nil

    public init(
        items: [CapturedItem],
        plateType: PlateType,
        source: EntryMethod = .unknown,
        confidence: Double?,
        needsSecondPhoto: Bool,
        secondPhotoHint: String?,
        kcalLow: Double?,
        kcalHigh: Double?
    ) {
        self.items = items
        self.plateType = plateType
        self.source = source
        self.confidence = confidence
        self.needsSecondPhoto = needsSecondPhoto
        self.secondPhotoHint = secondPhotoHint
        self.kcalLow = kcalLow
        self.kcalHigh = kcalHigh
    }

    /// Sum of all items' kcal. nil if any item is missing kcal (the
    /// USDA join hasn't completed for at least one). Caller can show
    /// a loading state until non-nil.
    public var totalKcal: Double? {
        // Empty items means "no plate identified" — return nil so
        // consumers can distinguish from "plate identified, totals
        // zero." Without this guard the reduce(0, +) returned 0 for
        // both cases, which can mask the empty-capture failure path
        // downstream (caught by EmptyCaptureGuardTests 2026-06-05).
        guard !items.isEmpty else { return nil }
        let kcalValues = items.compactMap { $0.kcal }
        guard kcalValues.count == items.count else { return nil }
        return kcalValues.reduce(0, +)
    }

    /// p61 — **THE plate's energy. One rule, one place.**
    ///
    /// The items price the plate. The model's `kcalLow…kcalHigh` band
    /// is honesty metadata ABOUT that sum — the ± label under the hero
    /// — and becomes the number itself only where there are no items to
    /// sum (the restaurant-range door, which identifies none).
    ///
    /// Rounded to the nearest 5, because precision theatre is dishonest
    /// at ±15-20% model accuracy, and because the reading rounds the
    /// same way: **the number in the record must be the number she saw
    /// and agreed to**, so that a day's plates add up to the day total
    /// Home shows her.
    ///
    /// Before this existed the reading and the record computed energy
    /// separately and disagreed by construction (the band's midpoint is
    /// the sum of the items' BOUNDS; the hero is the sum of their point
    /// estimates — nothing made them equal), and the physics clamp that
    /// tidies a 27-million-calorie candy bar reached the screen but not
    /// the record. See `PlateEnergyRecordTests`.
    public var recordedKcal: Double {
        let raw: Double
        if items.isEmpty {
            raw = ((kcalLow ?? 0) + (kcalHigh ?? 0)) / 2
        } else {
            raw = items.compactMap { $0.kcal }.reduce(0, +)
        }
        return (raw / 5).rounded() * 5
    }
}

// MARK: - CapturedItem

public struct CapturedItem: Sendable, Identifiable {
    /// `var` so re-identifying a corrected item is a mutation — see the
    /// note on `SnapRefineMerge.withId`.
    public var id: String
    /// v25 pass 51 — every field an edit path rewrites is `var`, for
    /// the same reason `CapturedFood.items` is: the copy helpers used
    /// to re-init through the memberwise initializer, whose defaulted
    /// parameters hide an omission from the compiler, and that shape
    /// dropped a newly-added field FIVE recorded times (most recently
    /// `micros`, erased by every portion edit). A copy helper is now a
    /// mutation of `self` — it names what it changes and carries
    /// everything else by construction. Fields no edit path touches
    /// stay `let`.
    public var name: String
    public var portionGrams: Double
    public var portionGramsLow: Double
    public var portionGramsHigh: Double
    /// USDA search terms ordered specific → generic. Populated by LLM
    /// for .photo source; empty for .quickAdd (already resolved via
    /// PantryItemID) and .imOutTonight (no item-level data).
    public let usdaSearchTerms: [String]
    public let preparation: String?
    public let cuisineHint: String?
    public let confidence: Double?
    public let notes: String?

    /// Populated after the USDA join completes. nil during the
    /// streaming-result-card phase.
    public var kcal: Double?
    public var proteinG: Double?
    public var carbsG: Double?
    public var fatG: Double?
    public var fiberG: Double?
    /// 2026-06-05 — extra nutrients the cohort cares about (per
    /// founder on-device feedback: P/C/F alone reads MFP-era).
    public var sugarG: Double?
    public var sodiumMg: Double?
    public var saturatedFatG: Double?

    /// Lookup source attribution — which DB answered when the join
    /// completes, or `.labelDeclared` when the numbers were transcribed
    /// off a package. nil until then.
    ///
    /// `var` so a re-stamp is a mutation rather than a full re-init —
    /// see the note on `CapturedFood.items`.
    public var nutritionSource: NutritionSource?

    /// 2026-06-23 accuracy fields (populated by the food-vision EF once
    /// deployed; nil on legacy/pre-deploy responses, so all of these are
    /// optional + safe to ignore until the EF ships them).
    /// - englishName: plain-english gloss when `name` is a native dish
    ///   name (e.g. name "bulgogi", englishName "marinated grilled beef").
    /// - count + unit: the visible quantity ("5" + "piece"). nil or
    ///   count<=1 means a single/continuous serving.
    /// - servingsInDish: how many standard servings the WHOLE visible
    ///   food is, for the shared-food split (nil ⇒ treat as 1).
    /// - isShareable: a whole/shared dish the user can apply their share
    ///   to (whole pizza, platter). nil/false = a single personal serving.
    public let englishName: String?
    public let count: Int?
    public let unit: String?
    public let servingsInDish: Int?
    public let isShareable: Bool?

    /// v25 E7 — the ten micronutrients, scaled to this portion, when
    /// the item was grounded in a source that publishes them (USDA
    /// FDC, or a pantry override for a brand that lists them). nil OR
    /// `.isEmpty` means UNKNOWN, never "none": a described meal that
    /// never touched USDA carries nothing here and every render site
    /// must stay silent rather than print a zero.
    public var micros: CalorieMathService.Micronutrients? = nil

    /// WHETHER THIS ITEM'S SOURCE PUBLISHES MICRONUTRIENTS AT ALL.
    ///
    /// Exactly one database in the pipeline does: USDA FDC, which
    /// `USDAClient` has parsed ten nutrients from since v1.0.9. Nothing
    /// else carries them — `llm_direct` is the model answering with kcal
    /// and macros only (and it is the DEFAULT path since v1.0.7, so it
    /// is most items), `OpenFoodFactsClient` parses none, the
    /// `canonical_pantry` row has no micro columns, and the rule-based
    /// restaurant estimate is arithmetic.
    ///
    /// Used to decide whether a PLATE may state micronutrients: a plate
    /// where some items were grounded and others were not can only
    /// produce a partial sum, and a partial sum presented as the plate's
    /// nutrition is an estimate wearing a measurement's clothes.
    ///
    /// A grounded item whose USDA record simply lists no vitamin C is
    /// still `true` here — it was asked and answered. That distinction is
    /// the point: "asked, and there is none" is knowledge; "never asked"
    /// is not.
    public var publishesMicros: Bool {
        switch nutritionSource {
        case .usdaFDC, .usdaCalibrated, .usdaOverride:
            return true
        case .openFoodFacts, .canonicalPantry, .ruleBasedEstimate,
             .llmDirect, .none:
            return false
        case .labelDeclared:
            // A US panel PRINTS vitamin D, calcium, iron and potassium —
            // 21 CFR 101.9(c)(8)(iv) makes all four mandatory. So the
            // label is the one source in this pipeline that could publish
            // micronutrients with better provenance than USDA's.
            //
            // It returns false anyway, and the distinction is the point:
            // the current food-vision schema does not ASK for them, so we
            // have not asked and do not know. "Asked, and there is none"
            // is knowledge; "never asked" is not — and a source that
            // publishes nothing must not claim a plate publishes.
            //
            // This flips to `true` in the same change that lands the four
            // fields in FOOD_VISION_SCHEMA. That change is written and
            // NOT deployed (1.2.0 (30) is in review); see
            // docs/app_v25/27_*.md §EF.
            return false
        case .userStated:
            // p61 — she stated kcal and macros; nobody asked her for
            // vitamins and the product must not pretend it did.
            return false
        }
    }

    public init(
        id: String,
        name: String,
        portionGrams: Double,
        portionGramsLow: Double,
        portionGramsHigh: Double,
        usdaSearchTerms: [String],
        preparation: String?,
        cuisineHint: String?,
        confidence: Double?,
        notes: String?,
        kcal: Double?,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        fiberG: Double?,
        nutritionSource: NutritionSource?,
        sugarG: Double? = nil,
        sodiumMg: Double? = nil,
        saturatedFatG: Double? = nil,
        englishName: String? = nil,
        count: Int? = nil,
        unit: String? = nil,
        servingsInDish: Int? = nil,
        isShareable: Bool? = nil,
        micros: CalorieMathService.Micronutrients? = nil
    ) {
        self.id = id
        self.name = name
        self.portionGrams = portionGrams
        self.portionGramsLow = portionGramsLow
        self.portionGramsHigh = portionGramsHigh
        self.usdaSearchTerms = usdaSearchTerms
        self.preparation = preparation
        self.cuisineHint = cuisineHint
        self.confidence = confidence
        self.notes = notes
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.nutritionSource = nutritionSource
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.saturatedFatG = saturatedFatG
        self.englishName = englishName
        self.count = count
        self.unit = unit
        self.servingsInDish = servingsInDish
        self.isShareable = isShareable
        self.micros = micros
    }
}

// MARK: - PlateType

/// Raw values match the strings the Edge Function returns (per
/// `FOOD_VISION_SCHEMA.properties.plate_type.enum` in
/// supabase/functions/food-vision/index.ts). Renaming a case here
/// requires a matching enum update in the schema + a release migration.
public enum PlateType: String, Sendable, CaseIterable {
    case single
    case mixed
    case bowl
    case charcuterie
    case shared
    case restaurantRange = "restaurant_range"
}

// MARK: - Food name hygiene

extension String {
    /// v23 pass 4 — display hygiene for model/database names: the
    /// occasional snake_case ("jeyuk_bokkeum") and squeezed spacing
    /// never reach a rendered name. Applied at ingest (vision +
    /// barcode mapping) and defensively at display sites so history
    /// logged before the fix reads clean too.
    var foodNameCleaned: String {
        guard contains("_") else { return self }
        return replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: " +", with: " ", options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - EntryMethod

/// WHICH DOOR this plate entered the record through. One vocabulary,
/// used verbatim in three places: `CapturedFood.source`, the
/// `food_logs.source` column, and the `entry_method` analytics property.
///
/// v25 E8 introduced this type for analytics only, alongside a
/// `CaptureSource` enum that mirrored the database CHECK constraint. Two
/// names for one idea is the bug that produced the whole defect it was
/// invented to fix: one shared decoder stamped `CaptureSource.photo` for
/// a photograph, a printed nutrition panel AND a typed sentence, so the
/// record could not tell three doors apart and told the user her typed
/// plate had been "read from your photo".
///
/// E8.1 collapsed them. `CaptureSource` is gone; this is the only
/// vocabulary, and migration `20260811120000_food_source_truth` widened
/// the CHECK constraint to accept it. Raw values are chosen so that NO
/// value already present in the column is renamed — `photo`,
/// `restaurant_estimate` and `quick_add` keep their historical spelling
/// even where a nicer word exists, because a rename would silently
/// break every insight filtering on them (E8 §3.1's precedent: split a
/// value, never rename one).
///
/// Categorical, lowercase, closed set: satisfies AnalyticsHygiene with
/// no allowlist exception and carries nothing about WHAT was eaten.
///
/// **Adding a case requires a migration** widening
/// `food_logs_source_door_check`. `EntryMethodTests` pins the full
/// vocabulary against that list so the two cannot drift.
public enum EntryMethod: String, Sendable, CaseIterable {
    /// A photograph of the food itself.
    case photo
    /// A photograph of a printed nutrition-facts panel.
    case label
    /// Typed or dictated words — E7's door.
    case words
    /// A scanned product barcode.
    case barcode
    /// Re-logged from her own record (E4's "again").
    case again
    /// The rule-based restaurant placeholder. Historical spelling.
    case restaurant = "restaurant_estimate"
    /// A pantry tile. Historical spelling.
    case pantry = "quick_add"
    /// Not attributed. Reachable only if a plate is persisted without
    /// passing a door — present so that absence is VISIBLE in the data
    /// rather than silently folded into a real category.
    case unknown

    /// Derived from the INPUT, which is the only place the distinction
    /// exists by the time a plate has been decoded. Exhaustive on
    /// purpose: a new `FoodCapture` case will fail to compile here until
    /// it declares which door it is.
    public init(_ capture: FoodCapture) {
        switch capture {
        case .photo:        self = .photo
        case .labelPhoto:   self = .label
        case .text:         self = .words
        case .quickAdd:     self = .pantry
        case .imOutTonight: self = .restaurant
        }
    }

    /// True when the numbers came off something printed. Printed truth
    /// is never rescaled by a prior and never described as an estimate
    /// of a photograph.
    public var isPrintedTruth: Bool {
        self == .label || self == .barcode
    }

    /// ONE LINE PER DOOR — the sentence a plate uses to say where its
    /// numbers came from.
    ///
    /// This vocabulary was written by E8.1 and lived as a private static
    /// on `PlateDetailSheet`, which is the SECOND surface a plate reaches.
    /// The first — `ResultDetailCopy.provenance`, read at the moment of
    /// the scan — had no door branch at all and returned "estimated from
    /// the photo · ranges, not exact" for a photographed nutrition panel,
    /// a barcode and a typed sentence alike. That is the exact lie E8.1
    /// was named for killing, still standing one surface upstream of the
    /// place it was killed.
    ///
    /// So it lives on the type that owns the doors, and both surfaces read
    /// it. A door added to this enum cannot ship without a sentence.
    ///
    /// Two rules it exists to keep: a plate never claims a provenance it
    /// does not have, and printed truth never apologises for being an
    /// estimate. A nutrition panel and a barcode are transcriptions of the
    /// package's own numbers; hedging them with "ranges, not exact" taught
    /// people to distrust the most accurate reading in the app.
    public var provenanceLine: String {
        switch self {
        case .photo:
            return "read from your photo \u{00B7} ranges, not exact"
        case .label, .barcode:
            return "copied from the label \u{00B7} these are the package's numbers"
        case .words:
            return "logged from your words \u{00B7} ranges, not exact"
        case .again:
            return "logged again from your record"
        case .restaurant:
            return "a restaurant estimate \u{00B7} a range, not a reading"
        case .pantry:
            return "from the pantry"
        case .unknown:
            // Covers pre-D3.B entries with no source at all and the three
            // legacy values (im_out / voice / menu) no build has written.
            // Rows written before E8.1 say `photo` for photographs, labels
            // and typed sentences alike; nothing here can recover which,
            // and that ambiguity is a fact about a date. Say the one thing
            // that is true of all of them.
            return "ranges, not exact"
        }
    }

    /// The stored-string form, for the persisted record where the door
    /// survives as `food_logs.source`. An unrecognised or absent value
    /// resolves to `.unknown` rather than guessing a door.
    public static func provenanceLine(for stored: String?) -> String {
        (stored.flatMap(EntryMethod.init(rawValue:)) ?? .unknown).provenanceLine
    }

    /// Values the `food_logs.source` CHECK accepts for historical rows
    /// but that this app will never write again. Two of them (`voice`,
    /// `menu`) were reserved in v1.0.7 and never shipped; `im_out` was
    /// superseded by `restaurant_estimate`; `text` predates the words
    /// door and no writer ever produced it.
    static let legacyTolerated: Set<String> = ["im_out", "voice", "menu", "text"]

    /// What to put in `food_logs.source` for a locally-stored entry.
    ///
    /// Three rules, in order:
    /// 1. A recognised door goes through unchanged.
    /// 2. A legacy value is PRESERVED, not translated. `text` looks like
    ///    it means `words`, but nothing has ever written it, so mapping
    ///    it would invent a fact about a row we cannot explain. History
    ///    is left exactly as found.
    /// 3. Anything else — including the absence of a source on entries
    ///    written before the field existed — becomes `unknown`. This
    ///    used to default to `photo`, which quietly inflated the largest
    ///    real category with rows that had no attribution at all.
    public static func persistedSourceValue(for stored: String?) -> String {
        guard let stored, !stored.isEmpty else { return unknown.rawValue }
        if let known = EntryMethod(rawValue: stored) { return known.rawValue }
        if legacyTolerated.contains(stored) { return stored }
        return unknown.rawValue
    }
}

// MARK: - NutritionSource

/// Which path produced the per-item kcal/macros. Tracked for
/// telemetry and the v1.0.8+ correction flywheel.
///
/// Three families:
///
/// - **Lookup-produced** — the original W2-T4 path. The LLM returned
///   portion grams only and `AppSideNutritionLookup` joined per-100g
///   density from `canonical_pantry` / `usda_fdc` / `open_food_facts`.
///   Still hit when the LLM returns `kcal == nil` (no longer the
///   default after v1.0.7 direct-kcal rewrite, but the fallback path
///   stays for resilience).
///
/// - **LLM-direct** (v1.0.7+) — the new default. `food-vision` Edge
///   Function returns kcal + macros directly from GPT-5 vision; no
///   USDA join needed. Marked `.llmDirect` for telemetry.
///
/// - **Hybrid calibrated** (v1.0.7+) — for low-confidence LLM items
///   (< 0.5), `FoodCaptureDispatcher.enrich` runs the USDA lookup as
///   a sanity check. If the USDA estimate sits within ±30% of the
///   LLM kcal, the LLM number is kept and tagged `.usdaCalibrated`
///   (we trust the model, but flagged the check ran). If drift
///   exceeds ±30%, the USDA number wins and the item is tagged
///   `.usdaOverride` so the cohort analyst sees how often LLM
///   accuracy drifts on ambiguous items.
public enum NutritionSource: String, Sendable, Codable, Hashable, CaseIterable {
    case usdaFDC = "usda_fdc"
    case openFoodFacts = "open_food_facts"
    case canonicalPantry = "canonical_pantry"
    case ruleBasedEstimate = "rule_based_estimate"
    /// LLM returned kcal + macros directly; no USDA join attempted
    /// (high-confidence path, v1.0.7+ default).
    case llmDirect = "llm_direct"
    /// LLM returned kcal; USDA lookup ran as a sanity check and
    /// agreed within ±30%. Kept LLM number, flagged the check.
    case usdaCalibrated = "usda_calibrated"
    /// LLM returned kcal; USDA lookup disagreed by >±30%. USDA
    /// number wins, LLM number logged for the correction flywheel.
    case usdaOverride = "usda_override"
    /// THE MANUFACTURER'S OWN DECLARATION, transcribed off a photographed
    /// Nutrition Facts panel.
    ///
    /// The one epistemic state this enum was missing. Every other case
    /// describes somebody ESTIMATING (a model, a rule) or a database
    /// being CONSULTED. A US nutrition panel is neither: 21 CFR 101.9
    /// obliges the manufacturer to declare those numbers, and reading
    /// them is transcription, not judgement.
    ///
    /// Before this, the label door was stamped `.llmDirect` — the same
    /// provenance as a guess about a bowl of stew — because
    /// `FoodVisionService` serves photo, label and words from one
    /// response shape and cannot tell them apart. The dispatcher can,
    /// and does, at the same chokepoint that stamps `EntryMethod`.
    case labelDeclared = "label_declared"
    /// p61 — HER OWN DECLARATION, typed into the words door with the
    /// number attached ("protein bar, 190 cal, 20g protein"). Not an
    /// estimate and not a database row: a statement. The model is
    /// never consulted, so no hedge may be printed over it.
    case userStated = "user_stated"
}
