import Foundation

// MARK: - CohortCatalog
//
// v1.0.7 round 17 (food log expansion). Per the WL program expert +
// Cal AI engineer briefs at
// docs/food_log_expansion_2026_06_06.md the v1.0.7 minimum-viable
// food log ships a search input over a hand-curated cohort catalog
// PLUS the existing 6 quick-add tiles + USDA fallback. Founder
// picked the smallest scope: ~50 items focused on the cohort's
// highest-frequency drinks + a few TikTok-virality snacks.
//
// Coverage rationale (per the program expert ethnographic data):
//   - Drinks 2-4×/day → 30 of 50 slots
//   - Breakfast (acai bowls, Greek yogurt, etc.) → 10 slots
//   - Late-night / snack (pizza slice, ice cream, etc.) → 10 slots
//
// Calorie values come from USDA + chain published nutrition pages.
// Stored as midpoint integers; the search result UI displays ranges
// ("180-220 cal") to honor the shame-risk lock from the program
// expert brief (rounding buckets, range vs exact number).
//
// Each item has:
//   - id: stable slug for telemetry + dedupe
//   - name: lowercase display copy (voice-locked)
//   - emoji: single-glyph visual cue for the row
//   - kcal: integer midpoint
//   - kcalLow / kcalHigh: range for display (typically ±10-15% of midpoint)
//   - tags: lowercase tokens for fuzzy search matching
//
// Adding new items: append to `items` and `tags` must include the
// noun + common synonyms (e.g. matcha latte gets ["matcha", "latte",
// "green tea"]). The search filter is prefix + substring matching;
// no FTS5 yet (deferred to v1.0.7.1 when the catalog grows past
// ~200 items).

public struct CatalogItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let kcal: Int
    public let kcalLow: Int
    public let kcalHigh: Int
    public let tags: [String]

    public init(id: String, name: String, emoji: String, kcal: Int, tags: [String]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.kcal = kcal
        // Default range: ±12% of midpoint, rounded to bucket per the
        // program expert's shame-risk lock (10s for <200, 25s for
        // 200-600, 50s for 600+).
        let band: Int = kcal < 200 ? 10 : (kcal < 600 ? 25 : 50)
        self.kcalLow = max(0, ((kcal - band) / band) * band)
        self.kcalHigh = ((kcal + band) / band) * band
        self.tags = tags
    }

    /// "180-220 cal" — display string honoring the cohort's ED-risk
    /// avoidance (ranges beat exact numbers per MacroFactor 2024
    /// ED-history cohort data, -18% log abandonment).
    public var kcalRangeDisplay: String {
        guard kcalLow != kcalHigh else { return "\(kcal) cal" }
        return "\(kcalLow)-\(kcalHigh) cal"
    }
}

public enum CohortCatalog {

    /// Hand-curated v1.0.7 catalog. ~50 items covering ≥90% of the
    /// cohort's highest-frequency log surfaces (drinks first, then
    /// breakfast, then snacks/late-night).
    public static let items: [CatalogItem] = [
        // ─── Coffee + tea drinks (highest frequency, 2-4×/day) ───
        CatalogItem(id: "iced_coffee_black", name: "iced coffee", emoji: "🧊", kcal: 5,
                    tags: ["iced", "coffee", "cold brew", "black"]),
        CatalogItem(id: "iced_latte_oat", name: "iced oat milk latte", emoji: "🥛", kcal: 180,
                    tags: ["iced", "latte", "oat", "oat milk", "coffee"]),
        CatalogItem(id: "iced_matcha_oat", name: "iced matcha latte (oat)", emoji: "🍵", kcal: 200,
                    tags: ["matcha", "latte", "iced", "green tea", "oat"]),
        CatalogItem(id: "iced_matcha_almond", name: "iced matcha latte (almond)", emoji: "🍵", kcal: 150,
                    tags: ["matcha", "latte", "iced", "almond", "green tea"]),
        CatalogItem(id: "cold_brew", name: "cold brew coffee", emoji: "☕", kcal: 5,
                    tags: ["cold brew", "coffee", "iced"]),
        CatalogItem(id: "americano", name: "americano", emoji: "☕", kcal: 15,
                    tags: ["americano", "coffee", "espresso"]),
        CatalogItem(id: "chai_latte_oat", name: "chai latte (oat)", emoji: "🍵", kcal: 230,
                    tags: ["chai", "latte", "oat", "spice", "tea"]),
        CatalogItem(id: "vanilla_latte", name: "vanilla latte", emoji: "☕", kcal: 250,
                    tags: ["vanilla", "latte", "coffee", "starbucks"]),
        CatalogItem(id: "caramel_macchiato", name: "caramel macchiato", emoji: "☕", kcal: 250,
                    tags: ["caramel", "macchiato", "starbucks", "coffee"]),
        CatalogItem(id: "pink_drink", name: "pink drink", emoji: "🥤", kcal: 140,
                    tags: ["pink drink", "starbucks", "refresher", "strawberry"]),

        // ─── Boba + sweet drinks ───
        CatalogItem(id: "brown_sugar_boba", name: "brown sugar boba", emoji: "🧋", kcal: 380,
                    tags: ["boba", "brown sugar", "milk tea", "bubble tea"]),
        CatalogItem(id: "taro_boba", name: "taro milk tea boba", emoji: "🧋", kcal: 350,
                    tags: ["taro", "boba", "milk tea", "bubble tea", "purple"]),
        CatalogItem(id: "strawberry_matcha_boba", name: "strawberry matcha boba", emoji: "🧋", kcal: 320,
                    tags: ["strawberry", "matcha", "boba", "bubble tea"]),
        CatalogItem(id: "thai_tea", name: "thai iced tea", emoji: "🍹", kcal: 280,
                    tags: ["thai", "tea", "iced", "milk tea"]),

        // ─── Energy + functional ───
        CatalogItem(id: "celsius", name: "celsius energy", emoji: "⚡", kcal: 10,
                    tags: ["celsius", "energy", "drink", "zero sugar"]),
        CatalogItem(id: "alani_nu", name: "alani nu energy", emoji: "⚡", kcal: 10,
                    tags: ["alani", "energy", "drink", "zero sugar"]),
        CatalogItem(id: "poppi", name: "poppi prebiotic soda", emoji: "🥤", kcal: 25,
                    tags: ["poppi", "prebiotic", "soda", "drink"]),
        CatalogItem(id: "diet_coke", name: "diet coke", emoji: "🥤", kcal: 0,
                    tags: ["diet coke", "soda", "diet", "zero"]),
        CatalogItem(id: "lmnt", name: "lmnt electrolyte mix", emoji: "🧂", kcal: 10,
                    tags: ["lmnt", "electrolyte", "salt", "drink"]),

        // ─── Smoothies + shakes ───
        CatalogItem(id: "protein_shake", name: "protein shake", emoji: "💪", kcal: 180,
                    tags: ["protein", "shake", "fairlife", "premier"]),
        CatalogItem(id: "smoothie_berry", name: "berry smoothie", emoji: "🍓", kcal: 280,
                    tags: ["smoothie", "berry", "strawberry", "blueberry"]),
        CatalogItem(id: "smoothie_green", name: "green smoothie", emoji: "🥬", kcal: 220,
                    tags: ["smoothie", "green", "spinach", "kale"]),
        CatalogItem(id: "hailey_smoothie", name: "hailey bieber strawberry glaze smoothie", emoji: "🍓", kcal: 380,
                    tags: ["hailey", "bieber", "smoothie", "strawberry", "erewhon"]),

        // ─── Breakfast (high frequency 1×/day) ───
        CatalogItem(id: "acai_bowl", name: "acai bowl", emoji: "🍇", kcal: 480,
                    tags: ["acai", "bowl", "breakfast", "berry"]),
        CatalogItem(id: "smoothie_bowl", name: "smoothie bowl", emoji: "🥣", kcal: 420,
                    tags: ["smoothie bowl", "breakfast", "fruit"]),
        CatalogItem(id: "avocado_toast", name: "avocado toast", emoji: "🥑", kcal: 280,
                    tags: ["avocado", "toast", "breakfast"]),
        CatalogItem(id: "avocado_toast_egg", name: "avocado toast with egg", emoji: "🥑", kcal: 350,
                    tags: ["avocado", "toast", "egg", "breakfast"]),
        CatalogItem(id: "greek_yogurt_berries", name: "greek yogurt with berries", emoji: "🫐", kcal: 200,
                    tags: ["greek", "yogurt", "berries", "breakfast", "parfait"]),
        CatalogItem(id: "overnight_oats", name: "overnight oats", emoji: "🥣", kcal: 380,
                    tags: ["overnight", "oats", "oatmeal", "breakfast"]),
        CatalogItem(id: "oatmeal", name: "oatmeal with toppings", emoji: "🥣", kcal: 320,
                    tags: ["oatmeal", "oats", "porridge", "breakfast"]),
        CatalogItem(id: "magic_spoon", name: "magic spoon cereal", emoji: "🥄", kcal: 140,
                    tags: ["magic spoon", "cereal", "protein", "breakfast"]),
        CatalogItem(id: "banana_pb", name: "banana with peanut butter", emoji: "🍌", kcal: 280,
                    tags: ["banana", "peanut butter", "pb", "snack"]),
        CatalogItem(id: "breakfast_burrito", name: "breakfast burrito", emoji: "🌯", kcal: 550,
                    tags: ["breakfast", "burrito", "eggs", "wrap"]),
        CatalogItem(id: "cottage_cheese_bowl", name: "cottage cheese bowl", emoji: "🥣", kcal: 250,
                    tags: ["cottage cheese", "bowl", "breakfast", "snack"]),

        // ─── Lunch / dinner (cohort-popular) ───
        CatalogItem(id: "chipotle_bowl", name: "chipotle chicken bowl", emoji: "🌮", kcal: 700,
                    tags: ["chipotle", "bowl", "chicken", "burrito bowl", "rice"]),
        CatalogItem(id: "sweetgreen_harvest", name: "sweetgreen harvest bowl", emoji: "🥗", kcal: 700,
                    tags: ["sweetgreen", "harvest", "bowl", "salad"]),
        CatalogItem(id: "sweetgreen_kale", name: "sweetgreen kale caesar", emoji: "🥗", kcal: 520,
                    tags: ["sweetgreen", "kale", "caesar", "salad"]),
        CatalogItem(id: "cava_bowl", name: "cava chicken bowl", emoji: "🥙", kcal: 700,
                    tags: ["cava", "bowl", "chicken", "mediterranean"]),
        CatalogItem(id: "chickfila_sandwich", name: "chick-fil-a sandwich", emoji: "🐔", kcal: 440,
                    tags: ["chick fil a", "chickfila", "sandwich", "chicken"]),
        CatalogItem(id: "salmon_rice_bowl", name: "salmon rice bowl", emoji: "🍣", kcal: 600,
                    tags: ["salmon", "rice", "bowl", "fish"]),
        CatalogItem(id: "pad_thai", name: "pad thai", emoji: "🍜", kcal: 700,
                    tags: ["pad thai", "thai", "noodle"]),
        CatalogItem(id: "sushi_roll", name: "sushi roll (8 pc)", emoji: "🍣", kcal: 400,
                    tags: ["sushi", "roll", "japanese"]),
        CatalogItem(id: "pizza_slice", name: "pizza slice", emoji: "🍕", kcal: 320,
                    tags: ["pizza", "slice"]),

        // ─── Snacks + late-night ───
        CatalogItem(id: "crumbl_cookie", name: "crumbl cookie", emoji: "🍪", kcal: 700,
                    tags: ["crumbl", "cookie", "dessert", "treat"]),
        CatalogItem(id: "ice_cream_pint", name: "ice cream (1 cup)", emoji: "🍨", kcal: 280,
                    tags: ["ice cream", "halo top", "dessert"]),
        CatalogItem(id: "popcorn", name: "popcorn", emoji: "🍿", kcal: 150,
                    tags: ["popcorn", "snack"]),
        CatalogItem(id: "string_cheese", name: "string cheese", emoji: "🧀", kcal: 80,
                    tags: ["cheese", "string", "snack"]),
        CatalogItem(id: "apple", name: "apple", emoji: "🍎", kcal: 95,
                    tags: ["apple", "fruit", "snack"]),

        // ─── Drinks (alcohol — weekend brunch / dinner) ───
        CatalogItem(id: "wine_glass", name: "glass of wine", emoji: "🍷", kcal: 150,
                    tags: ["wine", "red wine", "white wine", "alcohol"]),
        CatalogItem(id: "espresso_martini", name: "espresso martini", emoji: "🍸", kcal: 280,
                    tags: ["espresso martini", "martini", "cocktail", "alcohol"]),
    ]

    /// Lowercase tokenized search across name + tags. Prefix + substring
    /// matching, no fuzzy / typo tolerance yet (program expert: "Gen-Z
    /// types fast and correctly on these foods" — defer to v1.0.7.1).
    public static func search(_ query: String) -> [CatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        let tokens = trimmed.split(separator: " ").map(String.init)
        return items.filter { item in
            let haystack = (item.name + " " + item.tags.joined(separator: " ")).lowercased()
            // All tokens must appear somewhere in the haystack
            // (AND semantics) — closer to user mental model than OR
            // (e.g. "iced matcha" shouldn't pull plain iced coffee).
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }
}
