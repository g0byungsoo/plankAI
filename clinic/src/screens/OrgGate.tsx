import { useState } from "react";
import { rpc } from "../supabase";
import { Banner, Spinner } from "../kit";

// Shown when a signed-in account belongs to no active organization.
// Org creation stays a deliberate act (never self-serve marketing);
// for the alpha, the first clinician creates the org and becomes its
// owner. Being added to an existing org is done by that org's owner.
export function OrgGate({ email, onCreated, onSignOut }: {
  email: string; onCreated: () => Promise<void>; onSignOut: () => void;
}) {
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const create = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(null); setBusy(true);
    try {
      await rpc("care_create_org", { p_name: name });
      await onCreated();
    } catch (e: any) {
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
        <div className="actions">
          <button className="btn" disabled={busy || name.trim().length < 2} type="submit">
            {busy ? <Spinner /> : "create organization"}
          </button>
          <button className="btn quiet" type="button" onClick={onSignOut}>sign out</button>
        </div>
      </form>
      <p className="disclaimer" style={{ marginTop: 32 }}>
        if a colleague already set up your clinic, ask them to add you — you don't create a second organization.
      </p>
    </div>
  );
}
