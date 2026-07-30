import { useState } from "react";
import { rpc, reportOps } from "../supabase";
import { Banner, Spinner } from "../kit";

// Shown when a signed-in account belongs to no active organization.
// Org creation is a deliberate act: in pilot/staging environments the
// server requires a founder-issued setup code (org_creation_mode =
// restricted); development stays open for fixtures. The clinical
// checkbox is the S5 role law — an owner assigns care ONLY if they
// are a clinician, and they say so here, explicitly.
export function OrgGate({ email, onCreated, onSignOut }: {
  email: string; onCreated: () => Promise<void>; onSignOut: () => void;
}) {
  const [name, setName] = useState("");
  const [isClinician, setIsClinician] = useState(false);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const create = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(null); setBusy(true);
    try {
      await rpc("care_create_org", {
        p_name: name,
        p_owner_is_clinician: isClinician,
        p_provision_code: code.trim() || null,
      });
      await onCreated();
    } catch (e: any) {
      reportOps("org.create_failed", { rpc: "care_create_org" });
      setErr(e.message ?? "could not create the organization.");
      setBusy(false);
    }
  };

  return (
    <div className="page narrow">
      <span className="eyebrow">welcome</span>
      <h1 className="title">set up your clinic</h1>
      <p className="sub">signed in as {email}. name your organization to begin — you'll be its owner, and you can add clinicians and staff next.</p>
      {err && <div style={{ marginTop: 16 }}><Banner kind="err">{err}</Banner></div>}
      <form onSubmit={create} style={{ marginTop: 22, maxWidth: 440 }}>
        <label className="field">
          <span className="lbl">organization name</span>
          <input type="text" required placeholder="e.g. Cedar Metabolic Health" value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className="scope-toggle" style={{ marginBottom: 16 }}>
          <input type="checkbox" checked={isClinician} onChange={(e) => setIsClinician(e.target.checked)} />
          <div>
            <div className="st-name">I'm a clinician at this clinic</div>
            <div className="st-desc">only clinicians can assign protocols and medication plans. you can change this later, and add other clinicians either way.</div>
          </div>
        </label>
        <label className="field">
          <span className="lbl">pilot setup code <span style={{ fontWeight: 400, color: "var(--ink-3)" }}>· if you were given one</span></span>
          <input type="text" placeholder="XXXX-XXXX" value={code} onChange={(e) => setCode(e.target.value)} autoComplete="off" />
        </label>
        <div className="actions">
          <button className="btn" disabled={busy || name.trim().length < 2} type="submit">
            {busy ? <Spinner /> : "create organization"}
          </button>
          <button className="btn quiet" type="button" onClick={onSignOut}>sign out</button>
        </div>
      </form>
      <p className="disclaimer" style={{ marginTop: 32 }}>
        if a colleague already set up your clinic, ask them to add you — you don't create a second organization. your clinic is responsible for giving access only to authorized personnel.
      </p>
    </div>
  );
}
