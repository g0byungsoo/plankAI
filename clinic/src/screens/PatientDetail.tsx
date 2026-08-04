import { useCallback, useEffect, useState } from "react";
import { supabase, rpc, reportOps, canAssignCare, type Membership } from "../supabase";
import type { Chart, Correction, VisitPacketPayload, WeeklySummaryRow, PatientSeries } from "../types";
import { fmtDate, weekdayWord, weekLine } from "../types";
import { Banner, DL, Empty, Sheet, Spinner, Token } from "../kit";
import { PacketView } from "./PacketView";
import { AssignRegimenSheet, AssignProtocolSheet } from "./AssignSheets";

interface AuditRow { occurred_at: string; action: string; actor_role: string }

const AUDIT_WORDS: Record<string, string> = {
  "invitation.accepted": "patient accepted the invitation",
  "relationship.activated": "connection established",
  "relationship.ended": "connection ended by the clinic",
  "consent.granted": "patient chose what to share",
  "consent.revoked": "patient changed sharing",
  "chart.opened": "record opened",
  "packet.viewed": "visit packet opened",
  "series.viewed": "daily records opened",
  "protocol.assigned": "protocol assigned",
  "regimen.assigned": "medication plan assigned",
  "regimen.updated": "medication plan updated",
  "regimen.ended": "medication plan ended",
  "reconciliation.confirmed": "patient reviewed the assigned plan",
  "correction.requested": "patient reported something looks wrong",
  "correction.resolved": "correction resolved",
  "relationship.review_set": "marked reviewed",
};

export function PatientDetail({ membership, patientId, label, onBack }: {
  membership: Membership; patientId: string; label: string; onBack: () => void;
}) {
  const [chart, setChart] = useState<Chart | null>(null);
  const [packet, setPacket] = useState<VisitPacketPayload | null | "none">(null);
  // v9 P6 — the between-visit series (both tolerate an un-migrated
  // server: the panels simply say nothing has accrued yet).
  const [packetAt, setPacketAt] = useState<string | null>(null);
  const [weeks, setWeeks] = useState<WeeklySummaryRow[] | "none" | null>(null);
  const [series, setSeries] = useState<PatientSeries | "none" | null>(null);
  const [activity, setActivity] = useState<AuditRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [sheet, setSheet] = useState<null | "regimen" | "protocol" | "end" | { dismiss: Correction }>(null);
  const canAssign = canAssignCare(membership);
  const canEnd = membership.role === "clinician" || membership.role === "owner";

  const load = useCallback(async () => {
    setErr(null);
    try {
      const c = await rpc<Chart>("care_open_patient_chart", { p_org: membership.org_id, p_patient: patientId });
      setChart(c);
      if (c.scopes.includes("visit_packet_view")) {
        try {
          const p = await rpc<{ payload: VisitPacketPayload; generated_at?: string } | null>("care_get_visit_packet", { p_org: membership.org_id, p_patient: patientId });
          setPacket(p ? p.payload : "none");
          setPacketAt(p?.generated_at ?? null);
        } catch (pe: any) {
          reportOps("packet.load_failed", { rpc: "care_get_visit_packet" });
          setPacket("none");
        }
        // v9 P6 — the weekly series (same consent class as the
        // packet; an un-migrated server just reads as empty).
        try {
          const w = await rpc<WeeklySummaryRow[]>("care_get_weekly_summaries", { p_org: membership.org_id, p_patient: patientId });
          setWeeks(w && w.length ? w : "none");
        } catch {
          setWeeks("none");
        }
      } else {
        setPacket("none");
        setWeeks("none");
      }
      if (c.scopes.includes("observation_view")) {
        // v9 P6 — the raw series RPC, finally consumed.
        try {
          const s = await rpc<PatientSeries>("care_get_patient_series", { p_org: membership.org_id, p_patient: patientId });
          setSeries(s && s.weights.length ? s : "none");
        } catch {
          setSeries("none");
        }
      } else {
        setSeries("none");
      }
      // The audit trail is org-readable under RLS — the same rows the
      // patient can see about herself. ids + kinds only, never values.
      const { data: audit } = await supabase
        .from("care_audit_events")
        .select("occurred_at, action, actor_role")
        .eq("org_id", membership.org_id)
        .eq("patient_id", patientId)
        .order("occurred_at", { ascending: false })
        .limit(8);
      setActivity((audit ?? []) as AuditRow[]);
    } catch (e: any) {
      reportOps("chart.load_failed", { rpc: "care_open_patient_chart" });
      setErr(e.message);
    }
  }, [membership.org_id, patientId]);

  useEffect(() => { void load(); }, [load]);

  if (err) return <div className="page"><button className="btn quiet small" onClick={onBack}>‹ patients</button><div style={{ marginTop: 16 }}><Banner kind="err">{err}</Banner></div></div>;
  if (!chart) return <div className="page"><button className="btn quiet small" onClick={onBack}>‹ patients</button><div style={{ marginTop: 30 }}><Spinner /> opening record…</div></div>;

  const activeRegimen = chart.care_team_regimens.find((r) => !r.ended_at) ?? null;
  const openCorrections = chart.corrections.filter((c) => c.status === "open");
  // v9 P6 — the consent-honest staleness word: how old the latest
  // publish is (packet_meta implies it already; this just says it).
  const stalenessWord = (() => {
    if (!packetAt) return null;
    const days = Math.floor((Date.now() - new Date(packetAt).getTime()) / 86400000);
    if (days <= 1) return "updated today";
    if (days < 14) return `updated ${days} days ago`;
    return `updated ${Math.floor(days / 7)} weeks ago`;
  })();
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

      <div className="section-label">
        the record · last 4 weeks{stalenessWord ? ` · ${stalenessWord}` : ""}
      </div>
      {packet === null ? <Spinner />
        : packet === "none" ? (
          <div className="panel"><Empty big="no record shared">
            <p>{chart.scopes.includes("visit_packet_view") ? "the patient hasn't opened the app to publish her packet yet." : "the patient hasn't granted visit-packet access."}</p>
          </Empty></div>
        ) : <PacketView packet={packet} />}

      {/* v9 P6 — the between-visit series: weekly summaries accrete
          as the patient's app runs; nothing here watches in real
          time (the same cadence as the packet). */}
      <div className="section-label">week by week</div>
      {weeks === null ? <Spinner />
        : weeks === "none" ? (
          <div className="panel"><Empty big="no weekly summaries yet">
            <p>summaries accrue one row per week as the patient's app runs. they arrive with the same consent as the visit packet.</p>
          </Empty></div>
        ) : (
          <div className="panel">
            {weeks.map((w) => (
              <div key={w.week_key} style={{ padding: "12px 18px", borderTop: "1px solid var(--hair-2)" }}>
                <div className="num" style={{ fontWeight: 600 }}>week of {fmtDate(w.week_key)}</div>
                <p className="sub num" style={{ marginTop: 2 }}>{weekLine(w.payload)}</p>
              </div>
            ))}
          </div>
        )}

      <div className="section-label">weight series</div>
      {series === null ? <Spinner />
        : series === "none" ? (
          <div className="panel"><Empty big="no series shared">
            <p>{chart.scopes.includes("observation_view") ? "no weigh-ins inside the shared window yet." : "the patient hasn't granted daily-records access."}</p>
          </Empty></div>
        ) : (
          <div className="panel">
            <div style={{ padding: "12px 18px" }}>
              <DL items={series.weights.slice(0, 8).map((w) => [
                fmtDate(w.logged_at),
                `${w.weight_kg.toFixed(1)} kg${w.source === "healthkit" ? " · scale" : ""}`,
              ] as [string, string])} />
            </div>
          </div>
        )}

      {/* resolved corrections, quiet, for the trail */}
      {chart.corrections.some((c) => c.status !== "open") && (
        <>
          <div className="section-label">correction history</div>
          {chart.corrections.filter((c) => c.status !== "open").map((c) => (
            <CorrectionCard key={c.id} c={c} canAssign={false} onDismiss={() => {}} onAccept={() => {}} />
          ))}
        </>
      )}

      {activity && activity.length > 0 && (
        <>
          <div className="section-label">recent activity</div>
          <div className="panel" style={{ padding: "6px 18px" }}>
            <ul className="activity" style={{ margin: 0, padding: 0 }}>
              {activity.map((a, i) => (
                <li key={i}>
                  <span>{AUDIT_WORDS[a.action] ?? a.action.replace(".", " · ")}</span>
                  <span className="when num">{fmtDate(a.occurred_at)}</span>
                </li>
              ))}
            </ul>
          </div>
          <p className="disclaimer" style={{ marginTop: 8 }}>
            every open and every change is recorded — the patient can see the same trail about her own record.
          </p>
        </>
      )}

      <div style={{ marginTop: 34, display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 10 }} className="actions">
        <span style={{ display: "inline-flex", gap: 10 }}>
          {canAssign && chart.relationship.status === "active" && (
            <ReviewButton membership={membership} patientId={patientId} chart={chart} onDone={load} />
          )}
        </span>
        {canEnd && chart.relationship.status === "active" && (
          <button className="btn danger small" onClick={() => setSheet("end")}>end this connection</button>
        )}
      </div>

      <p className="disclaimer" style={{ marginTop: 30, maxWidth: 620 }}>
        this is the plan your clinic records in jeni care, and the patient's own recent record. it is not a prescription and is not transmitted to a pharmacy. the patient's daily records are not monitored in real time; review them at the visit. urgent concerns go through your clinic's usual channels.
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
      {sheet === "end" && (
        <EndRelationshipSheet
          membership={membership} patientId={patientId}
          label={chart.relationship.label || label}
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

// Clinic-side administrative end (patient left the practice, pilot
// concluded). Access-only, like patient revocation: nothing about
// the patient's chart or assigned plan is deleted.
function EndRelationshipSheet({ membership, patientId, label, onClose, onDone }: {
  membership: Membership; patientId: string; label: string; onClose: () => void; onDone: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const go = async () => {
    setErr(null); setBusy(true);
    try {
      await rpc("care_end_relationship", { p_org: membership.org_id, p_patient: patientId });
      onDone();
    } catch (e: any) {
      reportOps("member.manage_failed", { rpc: "care_end_relationship" });
      setErr(e.message); setBusy(false);
    }
  };
  return (
    <Sheet title="end this connection" sub={`${label} will no longer share records with your clinic.`} onClose={onClose}>
      {err && <Banner kind="err">{err}</Banner>}
      <p className="sub" style={{ marginBottom: 16 }}>
        your clinic's access ends now. their records, the audit trail, and any plan you assigned stay in their chart — ending access never changes treatment. reconnecting later takes a fresh invitation.
      </p>
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy} onClick={go}>{busy ? <Spinner /> : "end connection"}</button>
      </div>
    </Sheet>
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
    catch (e: any) {
      reportOps("correction.resolve_failed", { rpc: "care_resolve_correction" });
      setErr(e.message); setBusy(false);
    }
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
