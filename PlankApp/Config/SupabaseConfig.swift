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
//
// SESSION STORAGE: LOCKED. DO NOT CHANGE. (2026-07-25)
// The SDK's default `KeychainLocalStorage` persists the session under
// keychain service "supabase.gotrue.swift", key
// "sb-mtecqvykyeueumdynatd-auth-token" (SupabaseClient derives the key
// from the project host; the raw Auth default would be
// "supabase.auth.token"). Items are written with
// kSecAttrAccessibleAfterFirstUnlock, hard-coded inside the SDK's
// internal Keychain wrapper; supabase-swift 2.44 exposes no public
// accessibility option, so there is nothing safe to make explicit here.
// Changing the service, key, storageKey, or storage adapter would strand
// every existing install's session: on next launch bootstrap() would find
// no session and mint a NEW anonymous user_id, orphaning all
// userId-scoped data and the RevenueCat entitlement. Any future
// migration must read the old location first and write-through.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
