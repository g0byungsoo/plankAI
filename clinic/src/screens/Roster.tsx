import { useCallback, useEffect, useState } from "react";
import { rpc, type Membership } from "../supabase";
import type { PatientRow } from "../types";
import { fmtDateShort } from "../types";
import { Banner, Empty, Spinner, Token } from "../kit";

export function Roster({ membership, onOpen, cache, onLoaded }: {
  membership: Membership;
  onOpen: (id: string, label: string) => void;
  cache?: PatientRow[] | null;
  onLoaded?: (rows: PatientRow[]) => void;
}) {
  // Seed from the App-level cache so back-navigation shows the last
  // list instantly and refreshes underneath — no spinner flash on
  // every return (frame-audit finding).
  const [rows, setRows] = useState<PatientRow[] | null>(cache ?? null);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const data = await rpc<PatientRow[]>("care_list_patients", { p_org: membership.org_id });
      setRows(data ?? []);
      onLoaded?.(data ?? []);
    } catch (e: any) { setErr(e.message); }
  }, [membership.org_id, onLoaded]);

  useEffect(() => { void load(); }, [load]);

  const active = (rows ?? []).filter((r) => r.status === "active");
  const past = (rows ?? []).filter((r) => r.status !== "active");

  return (
    <div className="page">
      <span className="eyebrow">{membership.org_name}</span>
      <h1 className="title">patients</h1>
      <p className="sub">everyone who connected to your clinic. open a patient to read their record before a visit.</p>

      {err && <div style={{ marginTop: 16 }}><Banner kind="err">{err}</Banner></div>}
      {rows === null && <div style={{ marginTop: 30 }}><Spinner /> loading roster…</div>}

      {rows !== null && active.length === 0 && past.length === 0 && (
        <div style={{ marginTop: 20 }} className="panel">
          <Empty big="no patients yet">
            <p style={{ maxWidth: 380, margin: "0 auto" }}>invite a patient from the <b>clinic</b> tab — you'll get a short code to hand them. once they accept in the app, they appear here.</p>
          </Empty>
        </div>
      )}

      {active.length > 0 && (
        <>
          <div className="section-label">connected · {active.length}</div>
          <div className="panel rows">
            {active.map((r) => <PatientListRow key={r.patient_id} r={r} onOpen={onOpen} />)}
          </div>
        </>
      )}

      {past.length > 0 && (
        <>
          <div className="section-label">access ended · {past.length}</div>
          <div className="panel rows">
            {past.map((r) => <PatientListRow key={r.patient_id} r={r} onOpen={onOpen} />)}
          </div>
        </>
      )}
    </div>
  );
}

function PatientListRow({ r, onOpen }: { r: PatientRow; onOpen: (id: string, label: string) => void }) {
  const meta: string[] = [];
  if (r.packet_generated_at) meta.push(`record updated ${fmtDateShort(r.packet_generated_at)}`);
  else meta.push("no record shared yet");
  if (r.follow_up_on) meta.push(`follow-up ${fmtDateShort(r.follow_up_on)}`);

  return (
    <button className="row" onClick={() => onOpen(r.patient_id, r.label)}>
      <div className="grow">
        <div className="name">{r.label}</div>
        <div className="meta num">{meta.join(" · ")}</div>
      </div>
      {r.open_corrections > 0 && <Token kind="review">{r.open_corrections} to review</Token>}
      {r.status === "active"
        ? (r.needs_attention ? <Token kind="review">worth a look</Token> : <Token kind="active">connected</Token>)
        : <Token kind="off">access off</Token>}
      <span className="chev" aria-hidden="true">›</span>
    </button>
  );
}
