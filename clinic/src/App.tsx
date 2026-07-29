import { useCallback, useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase, rpc, type Membership } from "./supabase";
import { SignIn } from "./screens/SignIn";
import { OrgGate } from "./screens/OrgGate";
import { Roster } from "./screens/Roster";
import { PatientDetail } from "./screens/PatientDetail";
import { OrgScreen } from "./screens/OrgScreen";
import { Spinner } from "./kit";

type View = { name: "roster" } | { name: "patient"; id: string; label: string } | { name: "org" };

export function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [membership, setMembership] = useState<Membership | null>(null);
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [loadingOrg, setLoadingOrg] = useState(false);
  const [view, setView] = useState<View>({ name: "roster" });

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  const loadMemberships = useCallback(async () => {
    if (!session) return;
    setLoadingOrg(true);
    try {
      // org_members + organizations are directly readable to the
      // member (RLS); no RPC needed for the member's own list.
      const { data, error } = await supabase
        .from("org_members")
        .select("org_id, role, display_name, status, organizations(name)")
        .eq("user_id", session.user.id)
        .eq("status", "active");
      if (error) throw error;
      const rows: Membership[] = (data ?? []).map((r: any) => ({
        org_id: r.org_id,
        role: r.role,
        display_name: r.display_name,
        org_name: r.organizations?.name ?? "your clinic",
      }));
      setMemberships(rows);
      setMembership((cur) => cur ?? rows[0] ?? null);
    } finally {
      setLoadingOrg(false);
    }
  }, [session]);

  useEffect(() => { if (session) void loadMemberships(); }, [session, loadMemberships]);

  const signOut = async () => {
    await supabase.auth.signOut();
    setMembership(null);
    setMemberships([]);
    setView({ name: "roster" });
  };

  if (!ready) return <div className="page"><Spinner /></div>;
  if (!session) return <SignIn />;

  if (loadingOrg && !membership) return <div className="page"><Spinner /> loading your clinic…</div>;

  if (!membership) {
    return (
      <OrgGate
        email={session.user.email ?? ""}
        onCreated={async () => { await loadMemberships(); }}
        onSignOut={signOut}
      />
    );
  }

  return (
    <div className="shell">
      <header className="masthead">
        <span className="wordmark"><b>jenifit</b> <span style={{ fontWeight: 400 }}>care</span><span className="dot">.</span></span>
        <span className="crumb">{membership.org_name}</span>
        <span className="spacer" />
        <button className="btn quiet small" onClick={() => setView({ name: "roster" })}>patients</button>
        {membership.role === "owner" && (
          <button className="btn quiet small" onClick={() => setView({ name: "org" })}>clinic</button>
        )}
        <span className="who"><b>{membership.display_name || session.user.email}</b> · {membership.role}</span>
        <button className="btn quiet small" onClick={signOut}>sign out</button>
      </header>

      {memberships.length > 1 && (
        <div style={{ maxWidth: 1120, margin: "0 auto", padding: "10px 28px 0", width: "100%" }}>
          <select
            aria-label="organization"
            value={membership.org_id}
            onChange={(e) => { setMembership(memberships.find((m) => m.org_id === e.target.value)!); setView({ name: "roster" }); }}
            style={{ maxWidth: 320 }}
          >
            {memberships.map((m) => <option key={m.org_id} value={m.org_id}>{m.org_name} · {m.role}</option>)}
          </select>
        </div>
      )}

      {view.name === "roster" && (
        <Roster
          membership={membership}
          onOpen={(id, label) => setView({ name: "patient", id, label })}
        />
      )}
      {view.name === "patient" && (
        <PatientDetail
          membership={membership}
          patientId={view.id}
          label={view.label}
          onBack={() => setView({ name: "roster" })}
        />
      )}
      {view.name === "org" && (
        <OrgScreen membership={membership} onBack={() => setView({ name: "roster" })} />
      )}
    </div>
  );
}

export { rpc };
