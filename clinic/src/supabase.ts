import { createClient } from "@supabase/supabase-js";
import { ENV, type CareEnv } from "./env";

// Publishable key + RLS is the sanctioned browser pattern — every
// privileged action is a SECURITY DEFINER RPC that enforces role +
// relationship + scope server-side. No service-role key is ever
// present in this bundle. URL + key come from the environment the
// build was made for (see env.ts).
export const supabase = createClient(ENV.supabaseUrl, ENV.supabaseAnonKey, {
  auth: { persistSession: true, autoRefreshToken: true },
});

// Thin typed RPC helper. Throws the server's plain-language message.
export async function rpc<T = unknown>(
  fn: string,
  params: Record<string, unknown>
): Promise<T> {
  const { data, error } = await supabase.rpc(fn, params);
  if (error) throw new Error(error.message);
  return data as T;
}

// ---- server environment identity ----

export interface ServerEnvironment {
  environment: CareEnv;
  min_dashboard_build: string | null;
}

export async function fetchServerEnvironment(): Promise<ServerEnvironment | null> {
  try {
    const { data, error } = await supabase.rpc("care_environment");
    if (error) return null;
    return data as ServerEnvironment;
  } catch {
    return null;
  }
}

// ---- operational events (structurally redacted) ----
//
// Single-token fields only; the server drops anything else. Never
// medication names, weights, symptoms, or free text — the schema
// cannot carry them. Fire-and-forget: reporting must never break
// the surface it reports on.

export type OpsKind =
  | "auth.failed"
  | "auth.reset_failed"
  | "roster.load_failed"
  | "chart.load_failed"
  | "packet.load_failed"
  | "assign.protocol_failed"
  | "assign.regimen_failed"
  | "correction.resolve_failed"
  | "invitation.create_failed"
  | "invitation.accept_failed"
  | "member.manage_failed"
  | "org.create_failed"
  | "revocation.failed"
  | "client.error";

export function reportOps(kind: OpsKind, opts?: { code?: string; rpc?: string; status?: number }) {
  const token = (s: string | undefined, max: number) =>
    s ? s.replace(/[^A-Za-z0-9_.:-]/g, "_").slice(0, max) : null;
  void supabase
    .rpc("care_log_client_event", {
      p_surface: "dashboard",
      p_kind: kind,
      p_code: token(opts?.code, 80),
      p_rpc: token(opts?.rpc, 60),
      p_status: opts?.status ?? null,
      p_trace_id: `t-${Math.random().toString(36).slice(2, 10)}`,
      p_build: ENV.build,
    })
    .then(
      () => {},
      () => {}
    );
}

export type Role = "owner" | "clinician" | "staff";

export interface Membership {
  org_id: string;
  role: Role;
  display_name: string;
  clinical_authority: boolean;
  org_name: string;
  org_status: "active" | "suspended" | "unknown";
  org_is_demo: boolean;
}

// The S5 role law, client-side mirror of private.has_clinical_authority
// (the server is the enforcement; this only decides what to OFFER).
export function canAssignCare(m: Membership): boolean {
  return m.role === "clinician" || (m.role === "owner" && m.clinical_authority);
}
