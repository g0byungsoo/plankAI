import Foundation

// MARK: - DietaryProfileResolver
//
// App v2 (docs/app_v2/06_DATA_SUPABASE.md §E). One resolver for the
// dietary hint the food-vision EF receives. Before v2 two sources
// coexisted without meeting: the onboarding CSV
// (`onboarding_dietary`, sent since v1.1.3) and the in-app Food
// Settings keys (`foodDietaryPattern` + `foodExclusionsCSV`, editable
// but never transmitted — a user updating her allergies in settings
// changed nothing about recognition).
//
// The profile is a loose comma-joined token hint for the vision
// prompt, so the merge is a de-duplicated union with settings tokens
// FIRST (most recently expressed intent wins prompt position).

public enum DietaryProfileResolver {

    /// Merged dietary hint, or nil when the user never expressed any
    /// dietary context (the EF omits the block entirely).
    public static func current(_ d: UserDefaults = .standard) -> String? {
        let settingsPattern = tokens(d.string(forKey: "foodDietaryPattern"))
        let settingsExclusions = tokens(d.string(forKey: "foodExclusionsCSV"))
        let onboarding = tokens(d.string(forKey: "onboarding_dietary"))

        var seen = Set<String>()
        var merged: [String] = []
        for token in settingsPattern + settingsExclusions + onboarding {
            let key = token.lowercased()
            guard !key.isEmpty, key != "none", !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(token)
        }
        return merged.isEmpty ? nil : merged.joined(separator: ", ")
    }

    private static func tokens(_ csv: String?) -> [String] {
        (csv ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
