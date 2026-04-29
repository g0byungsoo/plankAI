import Foundation
import Supabase

// MARK: - Supabase configuration
//
// The anon/publishable key below is intentionally checked into source. It is
// safe to expose in client code: every user-data table has Row Level Security
// enabled (see scripts/rls_policies.sql), so this key alone cannot read or
// write any user's rows. RLS enforces `auth.uid() = user_id` on every row.
//
// The service_role key (full DB access, bypasses RLS) must NEVER appear in
// the iOS bundle — it stays in your secrets manager only.

enum SupabaseConfig {
    static let url = URL(string: "https://mtecqvykyeueumdynatd.supabase.co")!
    static let anonKey = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu"
}

// Shared client. Sessions are persisted to Keychain by the Supabase SDK's
// default storage adapter, so anonymous user_ids survive app restarts.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
