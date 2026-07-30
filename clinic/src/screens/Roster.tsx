import { useCallback, useEffect, useState } from "react";
import { rpc, reportOps, type Membership } from "../supabase";
import type { PatientRow } from "../types";
import { fmtDateShort } from "../types";
import { Banner, Empty, Spinner, Token } from "../kit";

export function Roster({ membership, onOpen, cache, onLoaded, onOpenClinic }: {
  membership: Membership;
  onOpen: (id: string, label: string) => void;
  cache?: PatientRow[] | null;
  onLoaded?: (rows: PatientRow[]) => void;
  onOpenClinic?: () => void;
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
    } catch (e: any) {
      reportOps("roster.load_failed", { rpc: "care_list_patients" });
      setErr(e.message);
    }
  }, [membership.org_id, onLoaded]);

  useEffect(() => { void load(); }, [load]);

  const active = (rows ?? []).filter((r) => r.status === "active");
  const past = (rows ?? []).filter((r) => r.status !== "active");

  return (
    <div className="page">
      <span className="eyebrow">{membership.org_name}</span>
      <h1 className="title">patients</h1>
      <p className="sub">everyone who connected to your clinic. open a patient to read their record before a visit.</p>

      {err && (
        <div style={{ marginTop: 16 }}>
          <Banner kind="err">
            {err}{" "}
            <button className="btn quiet small" onClick={() => void load()}>try again</button>
          </Banner>
        </div>
      )}
      {rows === null && !err && <div style={{ marginTop: 30 }}><Spinner /> loading roster…</div>}

      {rows !== null && active.length === 0 && past.length === 0 && (
        <div style={{ marginTop: 20 }} className="panel">
          <Empty big="welcome to jeni care">
            <ol className="firstrun">
              <li><span className="n">1</span><span>add your clinicians and staff under <b>clinic</b> — each role sees exactly what it should.</span></li>
              <li><span className="n">2</span><span>invite a patient — you hand them a one-time code, and they choose what to share.</span></li>
              <li><span className="n">3</span><span>open their record before a visit — their last four weeks, organized, every line from their own entries.</span></li>
              <li><span className="n">4</span><span>assign the plan — it becomes their daily care in the Jeni app, marked as from your clinic.</span></li>
            </ol>
            {onOpenClinic && (
              <p style={{ marginTop: 16 }}>
                <button className="btn small" onClick={onOpenClinic}>open clinic setup</button>
              </p>
            )}
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
