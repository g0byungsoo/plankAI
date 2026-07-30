// Environment identity — docs/app_v8/11_S5_PILOT_READY.md §7.
//
// The dashboard is BUILT for exactly one environment (VITE_CARE_ENV)
// and the server DECLARES which environment it is (care_environment
// RPC). The two must agree; a mismatch renders a hard banner instead
// of silently operating against the wrong database.
//
// Development keeps its baked-in defaults so `npm run dev` works
// with zero setup. Any other environment must provide its own URL +
// publishable key via .env.<mode> — and the build FAILS in
// vite.config.ts if a non-development build points at the
// development project.

export type CareEnv = "development" | "staging" | "pilot" | "production";

const DEV_URL = "https://mtecqvykyeueumdynatd.supabase.co";
const DEV_ANON = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu";

const builtFor = (import.meta.env.VITE_CARE_ENV as CareEnv) || "development";

export const ENV: {
  builtFor: CareEnv;
  supabaseUrl: string;
  supabaseAnonKey: string;
  build: string;
} = {
  builtFor,
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL || (builtFor === "development" ? DEV_URL : ""),
  supabaseAnonKey:
    import.meta.env.VITE_SUPABASE_ANON_KEY || (builtFor === "development" ? DEV_ANON : ""),
  build: (typeof __CARE_BUILD__ !== "undefined" && __CARE_BUILD__) || "dev",
};

// The support pathway. Pilot builds must carry a real mailbox
// (enforced at build time in vite.config.ts); development names the
// honest internal channel instead of inventing an unstaffed address.
export const SUPPORT_CONTACT: string =
  import.meta.env.VITE_CARE_SUPPORT_EMAIL ||
  (builtFor === "development"
    ? "this is the internal development build — reach the founding team directly"
    : "");

// Wear a quiet badge on internal environments only. The visible
// pilot product carries no environment chrome.
export function envBadge(serverEnv: CareEnv | null): string | null {
  const env = serverEnv ?? ENV.builtFor;
  if (env === "development") return "development";
  if (env === "staging") return "staging";
  return null;
}

declare global {
  // Injected by vite.config.ts at build time (YYYYMMDD.HHmm).
  const __CARE_BUILD__: string;
}
