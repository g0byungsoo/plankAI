import { createClient } from "@supabase/supabase-js";

// Same dev project the iOS app uses. Publishable key + RLS is the
// sanctioned browser pattern — every privileged action is a
// SECURITY DEFINER RPC that enforces role + relationship + scope
// server-side. No service-role key is ever present in this bundle.
const URL = "https://mtecqvykyeueumdynatd.supabase.co";
const ANON = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu";

export const supabase = createClient(URL, ANON, {
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

export type Role = "owner" | "clinician" | "staff";

export interface Membership {
  org_id: string;
  role: Role;
  display_name: string;
  org_name: string;
}
