import Foundation

// MARK: - USDA FoodData Central configuration
//
// USDA's free-tier API key is rate-limited (1,000 requests/hour per
// key) but not authenticated against any user data — same risk
// profile as `SupabaseConfig.anonKey`. Safe to ship in source.
//
// If the key gets leaked or abused, the worst case is that we hit
// the per-key rate limit. Mitigation: register a new key at
// https://fdc.nal.usda.gov/api-key-signup.html (~1 minute, free)
// and update the constant below. Old key still works for the previous
// app build until the user updates.
//
// Same key value is also set in Supabase Edge Function secrets (for
// the W2-T4 nutrition-lookup Edge Function skeleton that ships when
// migration triggers fire — per W2-T4 Option A architect decision).

enum USDAConfig {
    static let apiKey = "kv9Q9m2FYp78KgSJ36OsAhgoTyGGh0Y7FU8XGjiL"
}
