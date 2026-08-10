import { useCallback, useEffect, useState } from "react";
import { rpc, reportOps, type Membership } from "../supabase";
import type { PatientRow } from "../types";
import { fmtDateShort } from "../types";
import { build, type Attention } from "../attention";
import { Banner, Empty, Spinner, Token } from "../kit";

// THE CLINIC HOME.
//
// One short list, not a feed. The screen exists to answer four
// questions — who needs a read, why, how long it has waited, what has
// already been handled — and a patient who raises none of them does
// not appear in the list at all. That restraint is the product: a
// roster that shows everyone shows nothing.

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
  const [showQuiet, setShowQuiet] = useState(false);

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

  const q = rows ? build(rows) : null;
  const today = new Date().toLocaleDateString(undefined, {
    weekday: "long", month: "long", day: "numeric",
  }).toLowerCase();

  return (
    <div className="page">
      <span className="eyebrow">{membership.org_name}</span>
      <h1 className="title">{today}</h1>
      <p className="sub">
        {q === null ? "reading your clinic…"
          : q.needsRead.length === 0
            ? "nothing is waiting on you. every connected record is current."
            : `${q.needsRead.length} ${q.needsRead.length === 1 ? "record" : "records"} to read before you see them.`}
      </p>

      {err && (
        <div style={{ marginTop: 16 }}>
          <Banner kind="err">
            {err}{" "}
            <button className="btn quiet small" onClick={() => void load()}>try again</button>
          </Banner>
        </div>
      )}
      {rows === null && !err && <div style={{ marginTop: 30 }}><Spinner /> loading…</div>}

      {q && q.needsRead.length === 0 && q.quiet.length === 0
        && q.handled.length === 0 && q.ended.length === 0 && (
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

      {q && q.needsRead.length > 0 && (
        <>
          <div className="section-label">needs a read · {q.needsRead.length}</div>
          <div className="queue">
            {q.needsRead.map((a) => <QueueCard key={a.row.patient_id} a={a} onOpen={onOpen} />)}
          </div>
        </>
      )}

      {q && q.handled.length > 0 && (
        <>
          <div className="section-label">already handled · {q.handled.length}</div>
          <div className="panel rows">
            {q.handled.map((a) => (
              <QuietRow key={a.row.patient_id} a={a} onOpen={onOpen}
                meta={`read ${fmtDateShort(a.row.reviewed_at)}`} />
            ))}
          </div>
        </>
      )}

      {q && q.quiet.length > 0 && (
        <>
          <div className="section-label">
            quiet · {q.quiet.length}
            <button
              className="btn quiet small"
              style={{ float: "right", marginTop: -6 }}
              aria-expanded={showQuiet}
              onClick={() => setShowQuiet((v) => !v)}
            >
              {showQuiet ? "hide" : "show"}
            </button>
          </div>
          {showQuiet ? (
            <div className="panel rows">
              {q.quiet.map((a) => (
                <QuietRow key={a.row.patient_id} a={a} onOpen={onOpen}
                  meta={a.row.packet_generated_at
                    ? `record current · ${fmtDateShort(a.row.packet_generated_at)}`
                    : "no record shared yet"} />
              ))}
            </div>
          ) : (
            <p className="disclaimer" style={{ marginTop: -2 }}>
              {q.quiet.map((a) => a.row.label).join(" · ")} — nothing in their records
              is asking for you.
            </p>
          )}
        </>
      )}

      {q && q.ended.length > 0 && (
        <>
          <div className="section-label">access ended · {q.ended.length}</div>
          <div className="panel rows">
            {q.ended.map((a) => (
              <QuietRow key={a.row.patient_id} a={a} onOpen={onOpen}
                meta={`ended ${fmtDateShort(a.row.ended_at)}`} ended />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

/// A record that is asking for something. The row states the reason
/// before it states the name of the person, because the reason is
/// what the clinician is scanning for.
function QueueCard({ a, onOpen }: {
  a: Attention;
  onOpen: (id: string, label: string) => void;
}) {
  return (
    <button
      className={`qcard ${a.urgency}`}
      onClick={() => onOpen(a.row.patient_id, a.row.label)}
    >
      <div className="qhead">
        <span className="qname">{a.row.label}</span>
        {a.row.open_corrections > 0 && <Token kind="review">reported a problem</Token>}
        <span className="spacer" />
        <span className="qwait num">{a.waiting}</span>
      </div>
      {a.headline && <p className="qwhy">{a.headline.line}</p>}
      {a.support.length > 0 && (
        <ul className="qsupport">
          {a.support.map((r) => <li key={r.from}>{r.line}</li>)}
        </ul>
      )}
      <span className="qopen">open the record ›</span>
    </button>
  );
}

function QuietRow({ a, onOpen, meta, ended }: {
  a: Attention;
  onOpen: (id: string, label: string) => void;
  meta: string;
  ended?: boolean;
}) {
  return (
    <button className="row" onClick={() => onOpen(a.row.patient_id, a.row.label)}>
      <div className="grow">
        <div className="name">{a.row.label}</div>
        <div className="meta num">{meta}</div>
      </div>
      {ended ? <Token kind="off">access off</Token> : <Token kind="active">connected</Token>}
      <span className="chev" aria-hidden="true">›</span>
    </button>
  );
}
