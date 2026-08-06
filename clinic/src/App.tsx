import { useCallback, useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import {
  supabase, rpc, fetchServerEnvironment,
  type Membership, type ServerEnvironment,
} from "./supabase";
import { ENV, envBadge, SUPPORT_CONTACT } from "./env";
import { SignIn, NewPassword } from "./screens/SignIn";
import { OrgGate } from "./screens/OrgGate";
import { Roster } from "./screens/Roster";
import { PatientDetail } from "./screens/PatientDetail";
import { OrgScreen } from "./screens/OrgScreen";
import { HelpSheet } from "./screens/HelpSheet";
import { Banner, Spinner, Token } from "./kit";

type View = { name: "roster" } | { name: "patient"; id: string; label: string } | { name: "org" };

export function Wordmark() {
  return (
    <span className="wordmark">
      <b>jeni</b> <span style={{ fontWeight: 400 }}>care</span>
      <span className="dot">.</span>
    </span>
  );
}

export function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [recovery, setRecovery] = useState(false);
  const [membership, setMembership] = useState<Membership | null>(null);
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [loadingOrg, setLoadingOrg] = useState(false);
  const [view, setView] = useState<View>({ name: "roster" });
  const [rosterCache, setRosterCache] = useState<import("./types").PatientRow[] | null>(null);
  const [serverEnv, setServerEnv] = useState<ServerEnvironment | null>(null);
  const [help, setHelp] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      if (event === "PASSWORD_RECOVERY") setRecovery(true);
      setSession(s);
    });
    void fetchServerEnvironment().then(setServerEnv);
    return () => sub.subscription.unsubscribe();
  }, []);

  const loadMemberships = useCallback(async () => {
    if (!session) return;
    setLoadingOrg(true);
    try {
      // org_members + organizations are directly readable to the
      // member (RLS); no RPC needed for the member's own list. A
      // suspended org's row is NOT readable — that renders below as
      // "organization unavailable", deliberately without detail.
      const { data, error } = await supabase
        .from("org_members")
        .select("org_id, role, display_name, status, clinical_authority, organizations(name, status, is_demo)")
        .eq("user_id", session.user.id)
        .eq("status", "active");
      if (error) throw error;
      const rows: Membership[] = (data ?? []).map((r: any) => ({
        org_id: r.org_id,
        role: r.role,
        display_name: r.display_name,
        clinical_authority: !!r.clinical_authority,
        org_name: r.organizations?.name ?? "your clinic",
        org_status: r.organizations ? (r.organizations.status ?? "active") : "unknown",
        org_is_demo: !!r.organizations?.is_demo,
      }));
      setMemberships(rows);
      setMembership((cur) => cur ?? rows.find((m) => m.org_status === "active") ?? rows[0] ?? null);
    } finally {
      setLoadingOrg(false);
    }
  }, [session]);

  useEffect(() => { if (session) void loadMemberships(); }, [session, loadMemberships]);

  const signOut = async () => {
    await supabase.auth.signOut();
    setMembership(null);
    setMemberships([]);
    setRecovery(false);
    setView({ name: "roster" });
  };

  // Environment guards (11_S5 §7): built-for vs server-declared must
  // agree; stale long-lived tabs get a reload nudge.
  const envMismatch =
    serverEnv !== null && serverEnv.environment !== ENV.builtFor;
  const stale =
    serverEnv?.min_dashboard_build && ENV.build !== "dev" &&
    ENV.build < serverEnv.min_dashboard_build;
  const badge = envBadge(serverEnv?.environment ?? null);

  if (!ready) return <div className="page"><Spinner /></div>;

  if (envMismatch) {
    return (
      <div className="page narrow">
        <Wordmark />
        <div style={{ marginTop: 20 }}>
          <Banner kind="err">
            this build was made for “{ENV.builtFor}” but the server says it is “{serverEnv!.environment}”.
            to protect clinic data, jeni care won't operate across environments. contact support.
          </Banner>
        </div>
      </div>
    );
  }

  if (recovery && session) {
    return <NewPassword onDone={() => setRecovery(false)} />;
  }

  if (!session) return <SignIn badge={badge} serverEnv={serverEnv?.environment ?? null} />;

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

  if (membership.org_status !== "active") {
    return (
      <div className="page narrow">
        <Wordmark />
        <div style={{ marginTop: 20 }}>
          <Banner kind="info">
            your organization isn't available right now. if this is unexpected,
            contact support — {SUPPORT_CONTACT}.
          </Banner>
        </div>
        <button className="btn quiet small" onClick={signOut}>sign out</button>
      </div>
    );
  }

  return (
    <div className="shell">
      <header className="masthead">
        <Wordmark />
        <span className="crumb">{membership.org_name}</span>
        {membership.org_is_demo && <Token kind="review">demo clinic</Token>}
        {badge && <Token kind="off">{badge}</Token>}
        <span className="spacer" />
        <button className="btn quiet small" onClick={() => setView({ name: "roster" })}>patients</button>
        <button className="btn quiet small" onClick={() => setView({ name: "org" })}>clinic</button>
        <button className="btn quiet small" onClick={() => setHelp(true)}>help</button>
        <span className="who"><b>{membership.display_name || session.user.email}</b> · {membership.role}</span>
        <button className="btn quiet small" onClick={signOut}>sign out</button>
      </header>

      {stale && (
        <div style={{ maxWidth: 1120, margin: "0 auto", padding: "12px 28px 0", width: "100%" }}>
          <Banner kind="info">a newer version of jeni care is available — reload this page to get it.</Banner>
        </div>
      )}

      {memberships.length > 1 && (
        <div style={{ maxWidth: 1120, margin: "0 auto", padding: "10px 28px 0", width: "100%" }}>
          <select
            aria-label="organization"
            value={membership.org_id}
            onChange={(e) => { setRosterCache(null); setMembership(memberships.find((m) => m.org_id === e.target.value)!); setView({ name: "roster" }); }}
            style={{ maxWidth: 320 }}
          >
            {memberships.map((m) => <option key={m.org_id} value={m.org_id}>{m.org_name} · {m.role}</option>)}
          </select>
        </div>
      )}

      {view.name === "roster" && (
        <Roster
          membership={membership}
          cache={rosterCache}
          onLoaded={setRosterCache}
          onOpen={(id, label) => setView({ name: "patient", id, label })}
          onOpenClinic={() => setView({ name: "org" })}
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

      {help && <HelpSheet membership={membership} serverEnv={serverEnv?.environment ?? null} onClose={() => setHelp(false)} />}
    </div>
  );
}

export { rpc };
