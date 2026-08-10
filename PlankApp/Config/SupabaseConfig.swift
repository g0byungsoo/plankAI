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
    static let productionURL = URL(string: "https://mtecqvykyeueumdynatd.supabase.co")!
    static let productionAnonKey = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu"

    #if DEBUG
    // THE DEMO BACKEND (scripts/demo/). `--demo-backend` points a
    // debug build at the local Supabase stack that carries the full
    // real migration chain and the fictional Sage Metabolic Health
    // clinic. It exists so the clinic loop can be demonstrated end to
    // end without a single row of demo data reaching the consumer
    // project. Release builds cannot see this flag at all.
    //
    // The simulator reaches the host stack over the loopback address;
    // the key is the Supabase CLI's fixed local publishable key.
    static let demoURL = URL(string: "http://127.0.0.1:54321")!
    static let demoAnonKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

    static var isDemoBackend: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo-backend")
    }

    static var url: URL { isDemoBackend ? demoURL : productionURL }
    static var anonKey: String { isDemoBackend ? demoAnonKey : productionAnonKey }
    #else
    static var url: URL { productionURL }
    static var anonKey: String { productionAnonKey }
    #endif
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
//
// `--demo-backend` deliberately lands on a DIFFERENT keychain key
// (the host differs), which is exactly what a demo wants: the demo
// patient is a separate anonymous identity that can never collide
// with, or inherit from, a real session on the same simulator.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
