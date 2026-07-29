import { useCallback, useEffect, useState } from "react";
import { rpc, type Membership } from "../supabase";
import type { Chart, Correction, VisitPacketPayload } from "../types";
import { fmtDate, weekdayWord } from "../types";
import { Banner, DL, Empty, Sheet, Spinner, Token } from "../kit";
import { PacketView } from "./PacketView";
import { AssignRegimenSheet, AssignProtocolSheet } from "./AssignSheets";

export function PatientDetail({ membership, patientId, label, onBack }: {
  membership: Membership; patientId: string; label: string; onBack: () => void;
}) {
  const [chart, setChart] = useState<Chart | null>(null);
  const [packet, setPacket] = useState<VisitPacketPayload | null | "none">(null);
  const [err, setErr] = useState<string | null>(null);
  const [sheet, setSheet] = useState<null | "regimen" | "protocol" | { dismiss: Correction }>(null);
  const canAssign = (membership.role === "clinician" || membership.role === "owner");

  const load = useCallback(async () => {
    setErr(null);
    try {
      const c = await rpc<Chart>("care_open_patient_chart", { p_org: membership.org_id, p_patient: patientId });
      setChart(c);
      if (c.scopes.includes("visit_packet_view")) {
        const p = await rpc<{ payload: VisitPacketPayload } | null>("care_get_visit_packet", { p_org: membership.org_id, p_patient: patientId });
        setPacket(p ? p.payload : "none");
      } else {
        setPacket("none");
      }
    } catch (e: any) { setErr(e.message); }
  }, [membership.org_id, patientId]);

  useEffect(() => { void load(); }, [load]);

  if (err) return <div className="page"><button className="btn quiet small" onClick={onBack}>‹ patients</button><div style={{ marginTop: 16 }}><Banner kind="err">{err}</Banner></div></div>;
  if (!chart) return <div className="page"><button className="btn quiet small" onClick={onBack}>‹ patients</button><div style={{ marginTop: 30 }}><Spinner /> opening record…</div></div>;

  const activeRegimen = chart.care_team_regimens.find((r) => !r.ended_at) ?? null;
  const openCorrections = chart.corrections.filter((c) => c.status === "open");
  const scopeLabel = (s: string) => ({ visit_packet_view: "visit packet", observation_view: "daily records", care_assignment: "assign care" }[s] ?? s);

  return (
    <div className="page">
      <button className="btn quiet small" onClick={onBack}>‹ patients</button>
      <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", flexWrap: "wrap", gap: 12, marginTop: 12 }}>
        <div>
          <span className="eyebrow">patient record</span>
          <h1 className="title">{chart.relationship.label || label}</h1>
          <p className="sub num">
            connected {fmtDate(chart.relationship.established_at)}
            {chart.relationship.reviewed_at ? ` · last reviewed ${fmtDate(chart.relationship.reviewed_at)}` : " · not yet reviewed"}
            {chart.lookback_start ? ` · sees records from ${fmtDate(chart.lookback_start)}` : ""}
          </p>
        </div>
        <div className="actions">
          {chart.relationship.status === "active"
            ? <Token kind="active">connected</Token>
            : <Token kind="off">access ended</Token>}
        </div>
      </div>

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 14 }}>
        {chart.scopes.length === 0 && <Token kind="off">no access granted</Token>}
        {chart.scopes.map((s) => <Token key={s} kind="active">{scopeLabel(s)}</Token>)}
      </div>

      {chart.relationship.status !== "active" && (
        <div style={{ marginTop: 18 }}>
          <Banner kind="info">this patient turned off your clinic's access. their earlier records and any plan you assigned remain in their chart; you can no longer see new records or make changes. treatment questions go through your usual channels with the patient directly.</Banner>
        </div>
      )}

      {/* corrections needing a decision come first — the work */}
      {openCorrections.length > 0 && (
        <>
          <div className="section-label">needs your decision</div>
          {openCorrections.map((c) => (
            <CorrectionCard key={c.id} c={c} canAssign={canAssign}
              onDismiss={() => setSheet({ dismiss: c })}
              onAccept={() => setSheet("regimen")} />
          ))}
        </>
      )}

      <div className="section-label">assigned care</div>
      <div className="panel">
        <div style={{ padding: "16px 18px" }}>
          <DL items={[
            ["protocol", chart.assignment ? `${chart.assignment.protocol_title} · v${chart.assignment.protocol_version}` : "the standard plan (default)"],
            ["assigned", chart.assignment ? fmtDate(chart.assignment.assigned_at) : "—"],
          ]} />
        </div>
        {activeRegimen ? (
          <div style={{ padding: "0 18px 16px", borderTop: "1px solid var(--hair-2)" }}>
            <div style={{ paddingTop: 14 }}>
              <DL items={[
                ["medication", activeRegimen.display_name],
                ["dose", activeRegimen.strength_value ? `${activeRegimen.strength_value} ${activeRegimen.strength_unit ?? "mg"}` : "—"],
                ["schedule", `weekly · ${weekdayWord(activeRegimen.anchor_weekday)}s`],
                ["started", fmtDate(activeRegimen.started_at)],
                ...(activeRegimen.instruction ? [["instruction", activeRegimen.instruction] as [string, string]] : []),
              ]} />
            </div>
          </div>
        ) : (
          <div style={{ padding: "0 18px 18px" }}>
            <p className="sub">no care-team medication plan recorded.</p>
            {chart.self_regimen?.exists && (
              <p className="disclaimer">the patient records a weekly medication herself (she reports {weekdayWord(chart.self_regimen.anchor_weekday)}s). assigning a plan lets your clinic's schedule lead her check-ins; her earlier records stay in her chart.</p>
            )}
          </div>
        )}
        {canAssign && chart.relationship.status === "active" && chart.scopes.includes("care_assignment") && (
          <div style={{ padding: "14px 18px", borderTop: "1px solid var(--hair-2)" }} className="actions">
            <button className="btn small" onClick={() => setSheet("regimen")}>{activeRegimen ? "update medication plan" : "assign medication plan"}</button>
            <button className="btn small ghost" onClick={() => setSheet("protocol")}>assign protocol</button>
          </div>
        )}
        {canAssign && chart.relationship.status === "active" && !chart.scopes.includes("care_assignment") && (
          <div style={{ padding: "14px 18px", borderTop: "1px solid var(--hair-2)" }}>
            <p className="disclaimer">the patient hasn't granted care-assignment access, so you can review but not assign. ask them to enable it in the app.</p>
          </div>
        )}
      </div>

      <div className="section-label">the record · last 4 weeks</div>
      {packet === null ? <Spinner />
        : packet === "none" ? (
          <div className="panel"><Empty big="no record shared">
            <p>{chart.scopes.includes("visit_packet_view") ? "the patient hasn't opened the app to publish her packet yet." : "the patient hasn't granted visit-packet access."}</p>
          </Empty></div>
        ) : <PacketView packet={packet} />}

      {/* resolved corrections, quiet, for the trail */}
      {chart.corrections.some((c) => c.status !== "open") && (
        <>
          <div className="section-label">correction history</div>
          {chart.corrections.filter((c) => c.status !== "open").map((c) => (
            <CorrectionCard key={c.id} c={c} canAssign={false} onDismiss={() => {}} onAccept={() => {}} />
          ))}
        </>
      )}

      {canAssign && chart.relationship.status === "active" && (
        <div style={{ marginTop: 34 }} className="actions">
          <ReviewButton membership={membership} patientId={patientId} chart={chart} onDone={load} />
        </div>
      )}

      <p className="disclaimer" style={{ marginTop: 30, maxWidth: 620 }}>
        this is the plan your clinic records in jenifit, and the patient's own recent record. it is not a prescription and is not transmitted to a pharmacy. the patient's daily records are not monitored in real time; review them at the visit. urgent concerns go through your clinic's usual channels.
      </p>

      {sheet === "regimen" && (
        <AssignRegimenSheet
          membership={membership} patientId={patientId} existing={activeRegimen}
          openCorrection={openCorrections[0] ?? null}
          onClose={() => setSheet(null)}
          onDone={() => { setSheet(null); void load(); }} />
      )}
      {sheet === "protocol" && (
        <AssignProtocolSheet
          membership={membership} patientId={patientId}
          current={chart.assignment?.protocol_id ?? null}
          onClose={() => setSheet(null)}
          onDone={() => { setSheet(null); void load(); }} />
      )}
      {sheet && typeof sheet === "object" && "dismiss" in sheet && (
        <DismissSheet membership={membership} correction={sheet.dismiss}
          onClose={() => setSheet(null)}
          onDone={() => { setSheet(null); void load(); }} />
      )}
    </div>
  );
}

function CorrectionCard({ c, canAssign, onAccept, onDismiss }: {
  c: Correction; canAssign: boolean; onAccept: () => void; onDismiss: () => void;
}) {
  const catWord = { name: "medication name", strength: "dose", schedule: "schedule", not_taking: "not the medication I take", other: "a concern" }[c.category] ?? c.category;
  return (
    <div className={`corr ${c.status !== "open" ? "resolved" : ""}`}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 10 }}>
        <span className="cat">{catWord} looks wrong</span>
        {c.status === "open" ? <Token kind="review">open</Token>
          : c.status === "accepted" ? <Token kind="active">updated</Token> : <Token kind="off">dismissed</Token>}
      </div>
      {c.note && <p style={{ margin: "6px 0 0", color: "var(--ink-2)" }}>“{c.note}”</p>}
      {c.resolution_note && <p className="disclaimer" style={{ marginTop: 6 }}>your reason: {c.resolution_note}</p>}
      <p className="disclaimer num" style={{ marginTop: 6 }}>reported {fmtDate(c.created_at)}{c.resolved_at ? ` · resolved ${fmtDate(c.resolved_at)}` : ""}</p>
      {c.status === "open" && canAssign && (
        <div className="actions" style={{ marginTop: 10 }}>
          <button className="btn small" onClick={onAccept}>update the plan</button>
          <button className="btn small ghost" onClick={onDismiss}>dismiss with a reason</button>
        </div>
      )}
    </div>
  );
}

function DismissSheet({ membership, correction, onClose, onDone }: {
  membership: Membership; correction: Correction; onClose: () => void; onDone: () => void;
}) {
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const go = async () => {
    setErr(null); setBusy(true);
    try { await rpc("care_resolve_correction", { p_org: membership.org_id, p_correction_id: correction.id, p_note: note }); onDone(); }
    catch (e: any) { setErr(e.message); setBusy(false); }
  };
  return (
    <Sheet title="dismiss this report" sub="the patient will see your brief reason. the plan is unchanged." onClose={onClose}>
      {err && <Banner kind="err">{err}</Banner>}
      <label className="field"><span className="lbl">reason (the patient sees this)</span>
        <textarea rows={3} maxLength={200} autoFocus value={note} onChange={(e) => setNote(e.target.value)}
          placeholder="e.g. the 2.5 mg is correct for this titration step — we'll revisit at your visit." /></label>
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy || note.trim().length < 2} onClick={go}>{busy ? <Spinner /> : "dismiss with reason"}</button>
      </div>
    </Sheet>
  );
}

function ReviewButton({ membership, patientId, chart, onDone }: {
  membership: Membership; patientId: string; chart: Chart; onDone: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const mark = async () => {
    setBusy(true);
    try { await rpc("care_set_patient_review", { p_org: membership.org_id, p_patient: patientId, p_mark_reviewed: true }); onDone(); }
    finally { setBusy(false); }
  };
  return (
    <button className="btn ghost small" disabled={busy} onClick={mark}>
      {busy ? <Spinner /> : chart.relationship.reviewed_at ? "mark reviewed again" : "mark as reviewed"}
    </button>
  );
}
