import { useCallback, useEffect, useState } from "react";
import { rpc, reportOps, type Membership } from "../supabase";
import { Token } from "../kit";

// PROGRAM CONFIGURATION — the authority model, made operable.
//
// Jeni's program already resolves every knob through a chain:
//
//   PRESCRIBED  › PREFERRED  › RECOMMENDED › DEFAULTED
//   the clinic    her own      jeni offered   the standard
//                 choice       and she said   plan
//                              yes
//
// A clinic sets PRESCRIBED. That outranks her preference for as long
// as it stands, and releasing it hands the knob back to whatever she
// had chosen — it does not erase her choice, and it does not silently
// become the clinic's forever. That is the whole reason the chain has
// four levels instead of a boolean.
//
// Three facts, chosen because the patient app already consumes all
// three today. This is deliberately not a form builder: a control
// here that Jeni cannot act on would be a lie told in a clinical
// typeface.

type Kind = "stepGoal" | "weighCadence" | "walkTiming";

interface Fact { kind: Kind; value: string; created_at: string }

const FIELDS: {
  kind: Kind;
  label: string;
  help: string;
  /** What the patient sees change. */
  effect: string;
  options?: { value: string; label: string }[];
  unit?: string;
}[] = [
  {
    kind: "stepGoal",
    label: "daily step goal",
    help: "500 – 50,000",
    effect: "becomes her walking action on Today",
    unit: "steps",
  },
  {
    kind: "weighCadence",
    label: "weigh-in rhythm",
    help: "",
    effect: "how often Jeni asks her to weigh in",
    options: [
      { value: "standard", label: "standard" },
      { value: "softened", label: "softened" },
    ],
  },
  {
    kind: "walkTiming",
    label: "when to walk",
    help: "",
    effect: "when the walk is offered",
    options: [
      { value: "afterMeals", label: "after meals" },
      { value: "anytime", label: "anytime" },
      { value: "off", label: "not offered" },
    ],
  },
];

function decode(value: string): string {
  // ProgramFacts.swift encodes "i:<int>" and "w:<word>".
  if (value.startsWith("i:")) return Number(value.slice(2)).toLocaleString();
  if (value.startsWith("w:")) {
    const w = value.slice(2);
    return FIELDS.flatMap((f) => f.options ?? []).find((o) => o.value === w)?.label ?? w;
  }
  return value;
}

export function ProgramFactsPanel({ membership, patientId, canAssign, onChanged }: {
  membership: Membership;
  patientId: string;
  canAssign: boolean;
  onChanged?: () => void;
}) {
  const [facts, setFacts] = useState<Fact[] | null>(null);
  const [editing, setEditing] = useState<Kind | null>(null);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [unavailable, setUnavailable] = useState(false);

  const load = useCallback(async () => {
    try {
      const rows = await rpc<Fact[]>("care_get_program_facts", {
        p_org: membership.org_id, p_patient: patientId,
      });
      setFacts(rows ?? []);
    } catch {
      // A server without the migration simply has nothing to say here.
      setUnavailable(true);
      setFacts([]);
    }
  }, [membership.org_id, patientId]);

  useEffect(() => { void load(); }, [load]);

  if (unavailable) return null;

  const current = (kind: Kind) => facts?.find((f) => f.kind === kind) ?? null;

  const save = async (kind: Kind, value: string) => {
    setBusy(true); setErr(null);
    try {
      await rpc("care_set_program_fact", {
        p_org: membership.org_id, p_patient: patientId,
        p_kind: kind, p_value: value,
      });
      setEditing(null);
      await load();
      onChanged?.();
    } catch (e: any) {
      reportOps("assign.protocol_failed", { rpc: "care_set_program_fact" });
      setErr(e.message);
    } finally { setBusy(false); }
  };

  const release = async (kind: Kind) => {
    setBusy(true); setErr(null);
    try {
      await rpc("care_end_program_fact", {
        p_org: membership.org_id, p_patient: patientId, p_kind: kind,
      });
      await load();
      onChanged?.();
    } catch (e: any) {
      setErr(e.message);
    } finally { setBusy(false); }
  };

  return (
    <div className="panel facts">
      {FIELDS.map((f) => {
        const held = current(f.kind);
        const isEditing = editing === f.kind;
        return (
          <div className="fact" key={f.kind}>
            <div className="fact-main">
              <div className="fact-label">{f.label}</div>
              <div className="fact-effect">{f.effect}</div>
            </div>

            {isEditing ? (
              <div className="fact-edit">
                {f.options ? (
                  <div className="actions">
                    {f.options.map((o) => (
                      <button key={o.value} className="btn ghost small" disabled={busy}
                        onClick={() => void save(f.kind, o.value)}>{o.label}</button>
                    ))}
                    <button className="btn quiet small" onClick={() => setEditing(null)}>cancel</button>
                  </div>
                ) : (
                  <div className="actions">
                    <input type="number" value={draft} inputMode="numeric"
                      aria-label={f.label} style={{ width: 120 }}
                      onChange={(e) => setDraft(e.target.value)} />
                    <span className="fact-help">{f.help}</span>
                    <button className="btn small" disabled={busy || !draft}
                      onClick={() => void save(f.kind, draft)}>set</button>
                    <button className="btn quiet small" onClick={() => setEditing(null)}>cancel</button>
                  </div>
                )}
              </div>
            ) : (
              <div className="fact-value">
                {held ? (
                  <>
                    <span className="num fact-num">
                      {decode(held.value)}{f.unit ? ` ${f.unit}` : ""}
                    </span>
                    <Token kind="review">prescribed</Token>
                  </>
                ) : (
                  <span className="fact-none">her own setting</span>
                )}
                {canAssign && (
                  <span className="fact-acts">
                    <button className="btn quiet small" onClick={() => {
                      setDraft(held?.value.startsWith("i:") ? held.value.slice(2) : "");
                      setEditing(f.kind);
                    }}>{held ? "change" : "set"}</button>
                    {held && (
                      <button className="btn quiet small" disabled={busy}
                        onClick={() => void release(f.kind)}>release</button>
                    )}
                  </span>
                )}
              </div>
            )}
          </div>
        );
      })}

      {err && <p className="fact-err">{err}</p>}
      <p className="disclaimer fact-foot">
        a prescribed setting outranks the patient's own while it stands.
        releasing it returns the setting to whatever she had chosen — her
        history is never rewritten.
      </p>
    </div>
  );
}
