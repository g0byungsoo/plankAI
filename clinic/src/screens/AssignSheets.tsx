import { useEffect, useState } from "react";
import { supabase, rpc, type Membership } from "../supabase";
import type { CareTeamRegimen, Correction } from "../types";
import { WEEKDAY_WORDS } from "../types";
import { Banner, Sheet, Spinner } from "../kit";

// The care-team regimen form (10_S4 §6): name · mg per
// administration · weekly anchor · start date · optional
// instruction. mg ONLY — the field refuses units/mL (FDA 2024
// compounded-dosing alert). This records a care plan; it is NOT a
// prescription and is not transmitted anywhere.
export function AssignRegimenSheet({ membership, patientId, existing, openCorrection, onClose, onDone }: {
  membership: Membership; patientId: string; existing: CareTeamRegimen | null;
  openCorrection: Correction | null; onClose: () => void; onDone: () => void;
}) {
  const [name, setName] = useState(existing?.display_name ?? "");
  const [mg, setMg] = useState(existing?.strength_value?.toString() ?? "");
  const [weekday, setWeekday] = useState<number>(existing?.anchor_weekday ?? 1);
  const [start, setStart] = useState(existing?.started_at?.slice(0, 10) ?? new Date().toISOString().slice(0, 10));
  const [instruction, setInstruction] = useState(existing?.instruction ?? "");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const go = async () => {
    setErr(null); setBusy(true);
    try {
      const mgNum = parseFloat(mg);
      if (existing) {
        await rpc("care_update_regimen", {
          p_org: membership.org_id, p_regimen_id: existing.id,
          p_name: name, p_strength_mg: mgNum, p_anchor_weekday: weekday,
          p_instruction: instruction || null,
          p_correction_id: openCorrection?.id ?? null,
        });
      } else {
        await rpc("care_assign_regimen", {
          p_org: membership.org_id, p_patient: patientId,
          p_name: name, p_strength_mg: mgNum, p_anchor_weekday: weekday,
          p_started_on: start, p_instruction: instruction || null,
        });
      }
      onDone();
    } catch (e: any) { setErr(e.message); setBusy(false); }
  };

  const valid = name.trim().length >= 1 && parseFloat(mg) > 0 && parseFloat(mg) <= 50;

  return (
    <Sheet
      title={existing ? "update the medication plan" : "assign a medication plan"}
      sub="recording the plan your clinic has this patient on. this is not a prescription and is not sent to a pharmacy."
      onClose={onClose}
    >
      {err && <Banner kind="err">{err}</Banner>}
      {openCorrection && !existing === false && (
        <Banner kind="info">saving this will also resolve the patient's open correction.</Banner>
      )}
      <label className="field"><span className="lbl">medication name (the patient sees this)</span>
        <input type="text" autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. semaglutide" /></label>
      <label className="field"><span className="lbl">dose per injection — mg</span>
        <input type="number" step="0.05" min="0" max="50" value={mg} onChange={(e) => setMg(e.target.value)} placeholder="e.g. 0.5" />
        <span className="disclaimer">milligrams per administration only. never units or mL.</span>
      </label>
      <label className="field"><span className="lbl">weekly day</span>
        <div className="weekday-picker" role="group" aria-label="weekly day">
          {WEEKDAY_WORDS.map((w, i) => (
            <button key={w} type="button" aria-pressed={weekday === i + 1} onClick={() => setWeekday(i + 1)}>{w.slice(0, 3)}</button>
          ))}
        </div>
      </label>
      {!existing && (
        <label className="field"><span className="lbl">start date</span>
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} /></label>
      )}
      <label className="field"><span className="lbl">instruction (optional · shown to the patient)</span>
        <input type="text" maxLength={140} value={instruction} onChange={(e) => setInstruction(e.target.value)} placeholder="e.g. evening, thigh or abdomen ok" /></label>
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy || !valid} onClick={go}>{busy ? <Spinner /> : existing ? "save plan" : "assign plan"}</button>
      </div>
    </Sheet>
  );
}

interface ProtocolRow { id: string; title: string; version: number; org_id: string | null }

export function AssignProtocolSheet({ membership, patientId, current, onClose, onDone }: {
  membership: Membership; patientId: string; current: string | null; onClose: () => void; onDone: () => void;
}) {
  const [protocols, setProtocols] = useState<ProtocolRow[] | null>(null);
  const [pick, setPick] = useState<string | null>(current);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      const { data, error } = await supabase.from("protocols").select("id, title, version, org_id");
      if (error) { setErr(error.message); return; }
      const rows = (data ?? []) as ProtocolRow[];
      setProtocols(rows);
      if (!pick) setPick(rows.find((r) => r.org_id === membership.org_id)?.id ?? rows.find((r) => r.org_id === null)?.id ?? null);
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const go = async () => {
    if (!pick) return;
    setErr(null); setBusy(true);
    try { await rpc("care_assign_protocol", { p_org: membership.org_id, p_patient: patientId, p_protocol_id: pick }); onDone(); }
    catch (e: any) { setErr(e.message); setBusy(false); }
  };

  return (
    <Sheet title="assign a protocol" sub="choose an approved plan. the patient's app composes her day from it — you're not editing safety numbers here." onClose={onClose}>
      {err && <Banner kind="err">{err}</Banner>}
      {protocols === null ? <Spinner /> : (
        <div style={{ marginBottom: 16 }}>
          {protocols.map((p) => (
            <label className="scope-toggle" key={p.id}>
              <input type="radio" name="protocol" checked={pick === p.id} onChange={() => setPick(p.id)} />
              <div>
                <div className="st-name">{p.title} <span className="num" style={{ color: "var(--ink-3)", fontWeight: 400 }}>· v{p.version}</span></div>
                <div className="st-desc">{p.org_id === null ? "the standard jenifit plan" : "your clinic's protocol"}</div>
              </div>
            </label>
          ))}
        </div>
      )}
      <div className="actions" style={{ justifyContent: "flex-end" }}>
        <button className="btn ghost" onClick={onClose}>cancel</button>
        <button className="btn" disabled={busy || !pick} onClick={go}>{busy ? <Spinner /> : "assign protocol"}</button>
      </div>
    </Sheet>
  );
}
