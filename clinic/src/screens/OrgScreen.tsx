import { useCallback, useEffect, useState } from "react";
import { supabase, rpc, reportOps, type Membership } from "../supabase";
import type { User } from "@supabase/supabase-js";
import { SUPPORT_CONTACT } from "../env";
import { Banner, Empty, Sheet, Spinner, Token } from "../kit";
import { fmtDate } from "../types";

interface MemberRow {
  user_id: string; role: string; display_name: string; status: string;
  clinical_authority: boolean; credential_label: string | null;
}
interface InviteRow { id: string; patient_label: string; status: string; expires_at: string; created_at: string }

export function OrgScreen({ membership, onBack }: { membership: Membership; onBack: () => void }) {
  const [members, setMembers] = useState<MemberRow[] | null>(null);
  const [invites, setInvites] = useState<InviteRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [showInvite, setShowInvite] = useState(false);
  const [showAdd, setShowAdd] = useState(false);
  const [editing, setEditing] = useState<MemberRow | null>(null);
  const [reveal, setReveal] = useState<{ code: string; label: string; expires: string } | null>(null);
  const [me, setMe] = useState<User | null>(null);

  useEffect(() => { supabase.auth.getUser().then(({ data }) => setMe(data.user)); }, []);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const { data: m, error: em } = await supabase.from("org_members")
        .select("user_id, role, display_name, status, clinical_authority, credential_label")
        .eq("org_id", membership.org_id)
        .order("created_at", { ascending: true });
      if (em) throw em;
      setMembers((m ?? []) as MemberRow[]);
      const { data: i, error: ei } = await supabase.from("patient_invitations")
        .select("id, patient_label, status, expires_at, created_at")
        .eq("org_id", membership.org_id).order("created_at", { ascending: false });
      if (ei) throw ei;
      setInvites((i ?? []) as InviteRow[]);
    } catch (e: any) {
      reportOps("member.manage_failed", { rpc: "org_members.select" });
      setErr(e.message);
    }
  }, [membership.org_id]);

  useEffect(() => { void load(); }, [load]);

  const cancelInvite = async (id: string) => {
    try { await rpc("care_cancel_invitation", { p_id: id }); await load(); }
    catch (e: any) {
      reportOps("member.manage_failed", { rpc: "care_cancel_invitation" });
      setErr(e.message);
    }
  };

  const now = Date.now();
  const pending = (invites ?? []).filter((i) => i.status === "pending" && new Date(i.expires_at).getTime() > now);
  const isOwner = membership.role === "owner";

  const roleLine = (m: MemberRow) => {
    const parts: string[] = [m.role];
    if (m.credential_label) parts.push(m.credential_label);
    if (m.role === "clinician" || (m.role === "owner" && m.clinical_authority)) parts.push("assigns care");
    return parts.join(" · ");
  };

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
        {isOwner && <button className="btn small ghost" onClick={() => setShowAdd(true)}>add member</button>}
      </div>
      {members === null ? <Spinner /> : (
        <div className="panel rows">
          {members.map((m) => (
            <div className="row" key={m.user_id}>
              <div className="grow">
                <div className="name">{m.display_name || (me && m.user_id === me.id ? "you" : "unnamed member")}</div>
                <div className="meta">{roleLine(m)}{me && m.user_id === me.id && m.display_name ? " · you" : ""}</div>
              </div>
              {m.status === "active" ? <Token kind="active">active</Token> : <Token kind="off">disabled</Token>}
              {isOwner && (!me || m.user_id !== me.id) && (
                <button className="btn quiet small" onClick={() => setEditing(m)}>manage</button>
              )}
            </div>
          ))}
        </div>
      )}
      {isOwner && (
        <p className="disclaimer" style={{ marginTop: 10 }}>
          removing someone takes effect immediately — their sign-in stops seeing this clinic. your clinic is responsible for keeping access limited to authorized personnel.
        </p>
      )}

      <div className="section-label">support</div>
      <p className="disclaimer" style={{ maxWidth: 560 }}>
        questions, access changes, or a security concern: {SUPPORT_CONTACT}. jeni care is not an emergency channel — urgent clinical concerns go through your clinic's usual pathways.
      </p>

      {showInvite && (
        <InviteSheet
          orgId={membership.org_id}
          onClose={() => setShowInvite(false)}
          onCreated={(code, label, expires) => { setShowInvite(false); setReveal({ code, label, expires }); void load(); }}
        />
      )}
      {showAdd && (
        <AddMemberSheet orgId={membership.org_id} onClose={() => setShowAdd(false)} onDone={() => { setShowAdd(false); void load(); }} />
      )}
      {editing && (
        <ManageMemberSheet
          orgId={membership.org_id} member={editing}
          onClose={() => setEditing(null)}
          onDone={() => { setEditing(null); void load(); }}
        />
      )}
      {reveal && (
        <Sheet title="hand this code to the patient" sub="it works once, and expires. it is shown only now." onClose={() => setReveal(null)}>
          <div className="reveal-code num">{reveal.code}</div>
          <p className="sub" style={{ textAlign: "center" }}>for {reveal.label} · expires {fmtDate(reveal.expires)}</p>
          <p className="disclaimer" style={{ marginTop: 14 }}>
            they enter this in their Jeni app under “connect with your clinic.” you'll see them on your patient list once they accept and choose what to share.
          </p>
          <div className="actions" style={{ marginTop: 16, justifyContent: "flex-end" }}>
            <button className="btn" onClick={() => setReveal(null)}>done</button>
          </div>
        </Sheet>
      )}
    </div>
  );
}

function InviteSheet({ orgId, onClose, onCreated }: { orgId: string; onClose: () => void; onCreated: (code: string, label: string, expires: string) => void }) {
  const [label, setLabel] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const create = async () => {
    setErr(null); setBusy(true);
    try {
      const res = await rpc<{ code: string; expires_at: string }>("care_create_invitation", { p_org: orgId, p_label: label });
      onCreated(res.code, label, res.expires_at);
    } catch (e: any) {
      reportOps("invitation.create_failed", { rpc: "care_create_invitation" });
      setErr(e.message); setBusy(false);
    }
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
  const [ownerClinical, setOwnerClinical] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const add = async () => {
    setErr(null); setBusy(true);
    try {
      await rpc("care_add_member", {
        p_org: orgId, p_email: email, p_role: role, p_display_name: name,
        p_credential: cred || null,
        p_clinical: role === "owner" ? ownerClinical : null,
      });
      onDone();
    } catch (e: any) {
      reportOps("member.manage_failed", { rpc: "care_add_member" });
      setErr(e.message); setBusy(false);
    }
  };
  return (
    <Sheet title="add a team member" sub="they must already have a Jeni Care account with this email." onClose={onClose}>
      {err && <Banner kind="err">{err}</Banner>}
      <label className="field"><span className="lbl">email</span>
        <input type="email" autoFocus value={email} onChange={(e) => setEmail(e.target.value)} /></label>
      <label className="field"><span className="lbl">name</span>
        <input type="text" value={name} onChange={(e) => setName(e.target.value)} /></label>
      <label className="field"><span className="lbl">role</span>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="clinician">clinician — reviews and assigns care</option>
          <option value="staff">staff — invites and reads, never assigns</option>
          <option value="owner">owner — manages the team</option>
        </select></label>
      {role === "owner" && (
        <label className="scope-toggle" style={{ marginBottom: 16 }}>
          <input type="checkbox" checked={ownerClinical} onChange={(e) => setOwnerClinical(e.target.checked)} />
          <div>
            <div className="st-name">this owner is a clinician</div>
            <div className="st-desc">owners manage the team; they assign care only if they're clinicians too.</div>
          </div>
        </label>
      )}
      <label className="field"><span className="lbl">credential (optional)</span>
        <input type="text" placeholder="MD, NP, PA, RN…" value={cred} onChange={(e) => setCred(e.target.value)} /></label>
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy || !email} onClick={add}>{busy ? <Spinner /> : "add member"}</button>
      </div>
    </Sheet>
  );
}

// Owner-side administration of one member: role, clinical authority,
// active/disabled. The server holds the guards (last active owner,
// staff never clinical); this surface just makes the state honest.
function ManageMemberSheet({ orgId, member, onClose, onDone }: {
  orgId: string; member: MemberRow; onClose: () => void; onDone: () => void;
}) {
  const [role, setRole] = useState(member.role);
  const [clinical, setClinical] = useState(member.clinical_authority);
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const saveRole = async () => {
    setErr(null); setBusy("role");
    try {
      await rpc("care_set_member_role", {
        p_org: orgId, p_user: member.user_id, p_role: role,
        p_clinical: role === "owner" ? clinical : null,
      });
      onDone();
    } catch (e: any) {
      reportOps("member.manage_failed", { rpc: "care_set_member_role" });
      setErr(e.message); setBusy(null);
    }
  };

  const setStatus = async (status: "active" | "disabled") => {
    setErr(null); setBusy(status);
    try {
      await rpc("care_set_member_status", { p_org: orgId, p_user: member.user_id, p_status: status });
      onDone();
    } catch (e: any) {
      reportOps("member.manage_failed", { rpc: "care_set_member_status" });
      setErr(e.message); setBusy(null);
    }
  };

  return (
    <Sheet
      title={member.display_name || "team member"}
      sub={`currently ${member.role}${member.status === "disabled" ? " · disabled" : ""}`}
      onClose={onClose}
    >
      {err && <Banner kind="err">{err}</Banner>}
      <label className="field"><span className="lbl">role</span>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="clinician">clinician — reviews and assigns care</option>
          <option value="staff">staff — invites and reads, never assigns</option>
          <option value="owner">owner — manages the team</option>
        </select></label>
      {role === "owner" && (
        <label className="scope-toggle" style={{ marginBottom: 16 }}>
          <input type="checkbox" checked={clinical} onChange={(e) => setClinical(e.target.checked)} />
          <div>
            <div className="st-name">this owner is a clinician</div>
            <div className="st-desc">owners manage the team; they assign care only if they're clinicians too.</div>
          </div>
        </label>
      )}
      <div className="actions" style={{ justifyContent: "space-between" }}>
        {member.status === "active" ? (
          <button className="btn danger small" disabled={!!busy} onClick={() => setStatus("disabled")}>
            {busy === "disabled" ? <Spinner /> : "remove access now"}
          </button>
        ) : (
          <button className="btn ghost small" disabled={!!busy} onClick={() => setStatus("active")}>
            {busy === "active" ? <Spinner /> : "restore access"}
          </button>
        )}
        <span style={{ display: "inline-flex", gap: 10 }}>
          <button className="btn ghost" onClick={onClose}>cancel</button>
          <button className="btn" disabled={!!busy} onClick={saveRole}>{busy === "role" ? <Spinner /> : "save"}</button>
        </span>
      </div>
      <p className="disclaimer" style={{ marginTop: 14 }}>
        removal is immediate and reversible. it changes what this person can see — it never deletes patient records or the audit trail.
      </p>
    </Sheet>
  );
}
