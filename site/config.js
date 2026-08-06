// Jeni Care site — runtime config. The pilot-request form POSTs to a
// bounded, anon-granted RPC (care_submit_pilot_request) under the
// publishable key; RLS + the RPC body are the boundary, and no API
// role can read the requests back. Point this at the environment that
// should receive pilot requests. Overridable at deploy time by
// replacing this file (e.g. a Vercel build step) — never commit a
// service key here.
window.JENI_CARE = {
  // Default: the development project (the only one today). A pilot
  // deploy replaces these with the pilot project's values.
  supabaseUrl: "https://mtecqvykyeueumdynatd.supabase.co",
  supabaseAnonKey: "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu",
};
