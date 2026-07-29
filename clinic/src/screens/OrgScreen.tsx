import { useCallback, useEffect, useState } from "react";
import { supabase, rpc, type Membership } from "../supabase";
import type { User } from "@supabase/supabase-js";
import { Banner, Empty, Sheet, Spinner, Token } from "../kit";
import { fmtDate } from "../types";

interface MemberRow { user_id: string; role: string; display_name: string; status: string }
interface InviteRow { id: string; patient_label: string; status: string; expires_at: string; created_at: string }

export function OrgScreen({ membership, onBack }: { membership: Membership; onBack: () => void }) {
  const [members, setMembers] = useState<MemberRow[] | null>(null);
  const [invites, setInvites] = useState<InviteRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [showInvite, setShowInvite] = useState(false);
  const [showAdd, setShowAdd] = useState(false);
  const [reveal, setReveal] = useState<{ code: string; label: string } | null>(null);
  const [me, setMe] = useState<User | null>(null);

  useEffect(() => { supabase.auth.getUser().then(({ data }) => setMe(data.user)); }, []);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const { data: m } = await supabase.from("org_members")
        .select("user_id, role, display_name, status").eq("org_id", membership.org_id);
      setMembers((m ?? []) as MemberRow[]);
      const { data: i } = await supabase.from("patient_invitations")
        .select("id, patient_label, status, expires_at, created_at")
        .eq("org_id", membership.org_id).order("created_at", { ascending: false });
      setInvites((i ?? []) as InviteRow[]);
    } catch (e: any) { setErr(e.message); }
  }, [membership.org_id]);

  useEffect(() => { void load(); }, [load]);

  const cancelInvite = async (id: string) => {
    try { await rpc("care_cancel_invitation", { p_id: id }); await load(); }
    catch (e: any) { setErr(e.message); }
  };

  const now = Date.now();
  const pending = (invites ?? []).filter((i) => i.status === "pending" && new Date(i.expires_at).getTime() > now);

  return (
    <div className="page">
      <button className="btn quiet small" onClick={onBack}>‹ patients</button>
      <span className="eyebrow" style={{ display: "block", marginTop: 12 }}>{membership.org_name}</span>
      <h1 className="title">clinic</h1>
      <p className="sub">your team, and the invitations you've handed to patients.</p>
      {err && <div style={{ marginTop: 14 }}><Banner kind="err">{err}</Banner></div>}

      <div className="section-label" style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <span>invitations</span>
        <button className="btn small" onClick={() => setShowInvite(true)}>invite a patient</button>
      </div>
      {invites === null ? <Spinner /> : pending.length === 0 ? (
        <div className="panel"><Empty big="no open invitations"><p>invite a patient to generate a code you can hand them.</p></Empty></div>
      ) : (
        <div className="panel rows">
          {pending.map((i) => (
            <div className="row" key={i.id}>
              <div className="grow">
                <div className="name">{i.patient_label}</div>
                <div className="meta num">expires {fmtDate(i.expires_at)}</div>
              </div>
              <Token kind="review">awaiting patient</Token>
              <button className="btn quiet small" onClick={() => cancelInvite(i.id)}>cancel</button>
            </div>
          ))}
        </div>
      )}

      <div className="section-label" style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <span>team</span>
        {membership.role === "owner" && <button className="btn small ghost" onClick={() => setShowAdd(true)}>add member</button>}
      </div>
      {members === null ? <Spinner /> : (
        <div className="panel rows">
          {members.map((m) => (
            <div className="row" key={m.user_id}>
              <div className="grow">
                <div className="name">{m.display_name || (me && m.user_id === me.id ? "you" : "unnamed member")}</div>
                <div className="meta">{m.role}{me && m.user_id === me.id && m.display_name ? " · you" : ""}</div>
              </div>
              {m.status === "active" ? <Token kind="active">active</Token> : <Token kind="off">disabled</Token>}
            </div>
          ))}
        </div>
      )}

      {showInvite && (
        <InviteSheet
          orgId={membership.org_id}
          onClose={() => setShowInvite(false)}
          onCreated={(code, label) => { setShowInvite(false); setReveal({ code, label }); void load(); }}
        />
      )}
      {showAdd && (
        <AddMemberSheet orgId={membership.org_id} onClose={() => setShowAdd(false)} onDone={() => { setShowAdd(false); void load(); }} />
      )}
      {reveal && (
        <Sheet title="hand this code to the patient" sub="it works once, and expires. it is shown only now." onClose={() => setReveal(null)}>
          <div className="reveal-code num">{reveal.code}</div>
          <p className="sub" style={{ textAlign: "center" }}>for {reveal.label}</p>
          <p className="disclaimer" style={{ marginTop: 14 }}>
            they enter this in the jenifit app under “connect with your clinic.” you'll see them appear on your patient list once they accept and choose what to share.
          </p>
          <div className="actions" style={{ marginTop: 16, justifyContent: "flex-end" }}>
            <button className="btn" onClick={() => setReveal(null)}>done</button>
          </div>
        </Sheet>
      )}
    </div>
  );
}

function InviteSheet({ orgId, onClose, onCreated }: { orgId: string; onClose: () => void; onCreated: (code: string, label: string) => void }) {
  const [label, setLabel] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const create = async () => {
    setErr(null); setBusy(true);
    try {
      const res = await rpc<{ code: string }>("care_create_invitation", { p_org: orgId, p_label: label });
      onCreated(res.code, label);
    } catch (e: any) { setErr(e.message); setBusy(false); }
  };
  return (
    <Sheet title="invite a patient" sub="give them a label you'll recognize. this is your own note, never shown to them." onClose={onClose}>
      {err && <Banner kind="err">{err}</Banner>}
      <label className="field">
        <span className="lbl">patient label</span>
        <input type="text" autoFocus placeholder="e.g. Jordan M. (Tue visits)" value={label} onChange={(e) => setLabel(e.target.value)} />
      </label>
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy || label.trim().length < 1} onClick={create}>{busy ? <Spinner /> : "generate code"}</button>
      </div>
    </Sheet>
  );
}

function AddMemberSheet({ orgId, onClose, onDone }: { orgId: string; onClose: () => void; onDone: () => void }) {
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [role, setRole] = useState("clinician");
  const [cred, setCred] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const add = async () => {
    setErr(null); setBusy(true);
    try {
      await rpc("care_add_member", { p_org: orgId, p_email: email, p_role: role, p_display_name: name, p_credential: cred || null });
      onDone();
    } catch (e: any) { setErr(e.message); setBusy(false); }
  };
  return (
    <Sheet title="add a team member" sub="they must already have a jenifit care account with this email." onClose={onClose}>
      {err && <Banner kind="err">{err}</Banner>}
      <label className="field"><span className="lbl">email</span>
        <input type="email" autoFocus value={email} onChange={(e) => setEmail(e.target.value)} /></label>
      <label className="field"><span className="lbl">name</span>
        <input type="text" value={name} onChange={(e) => setName(e.target.value)} /></label>
      <label className="field"><span className="lbl">role</span>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="clinician">clinician — assigns care</option>
          <option value="staff">staff — invites, reads, no assigning</option>
          <option value="owner">owner — manages the team</option>
        </select></label>
      <label className="field"><span className="lbl">credential (optional)</span>
        <input type="text" placeholder="MD, NP, PA, RN…" value={cred} onChange={(e) => setCred(e.target.value)} /></label>
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy || !email} onClick={add}>{busy ? <Spinner /> : "add member"}</button>
      </div>
    </Sheet>
  );
}
