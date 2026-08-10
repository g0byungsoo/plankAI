import type { Chart, PatientSeries, VisitPacketPayload } from "../types";
import { fmtDateShort, weekdayWord } from "../types";

// THE PRE-VISIT READ + THE INTERVAL
//
// A clinician opening a record before a visit is answering one
// question: what happened since I last saw this person, and does any
// of it change what I do today. The ledger below this can answer
// anything; this has to answer that, in under a minute.
//
// Five lines, in the order a visit actually goes:
//   what you intended · what happened · what changed ·
//   still open · may deserve discussion
//
// Every line is composed from records she entered. Jeni organizes the
// evidence; the clinician judges it. Nothing here is a
// recommendation, a score, or a cause — the timeline states WHEN
// things landed and lets a clinician draw the line, which is the one
// inference software has no business making.

const KG_TO_LB = 2.2046;

function lb(kg: number): number {
  return kg * KG_TO_LB;
}

export function IntervalRead({ chart, packet, series }: {
  chart: Chart;
  packet: VisitPacketPayload | null;
  series: PatientSeries | null;
}) {
  if (!packet) return null;

  const regimen = chart.care_team_regimens.find((r) => !r.ended_at);
  const p = packet;

  // ---- what you intended
  const intended: string[] = [];
  if (regimen) {
    const dose = regimen.strength_value
      ? `${regimen.strength_value} ${regimen.strength_unit ?? "mg"}`
      : null;
    intended.push(
      [regimen.display_name, dose, `weekly · ${weekdayWord(regimen.anchor_weekday)}s`]
        .filter(Boolean).join(" · ")
    );
    if (regimen.started_at) intended.push(`recorded ${fmtDateShort(regimen.started_at)}`);
  } else if (chart.self_regimen?.exists) {
    intended.push("no plan assigned by this clinic — she is tracking her own.");
  } else {
    intended.push("no medication plan on file.");
  }
  if (chart.assignment) {
    intended.push(`${chart.assignment.protocol_title} · v${chart.assignment.protocol_version}`);
  }

  // ---- what happened
  const happened: string[] = [];
  if (p.regimen && p.regimen.scheduledCount > 0) {
    const r = p.regimen;
    happened.push(
      `marked taken on ${r.takenCount} of ${r.scheduledCount} scheduled days`
        + (r.skippedCount ? `, ${r.skippedCount} skipped` : "")
    );
  }
  if (p.weight?.entryCount) {
    happened.push(`weighed in ${p.weight.entryCount}×`);
  }
  if (p.nutrition) happened.push(`logged food on ${p.nutrition.loggedDays} days`);
  if (p.movement?.movedDays) happened.push(`moved on ${p.movement.movedDays} days`);

  // ---- what changed
  const changed: string[] = [];
  if (p.weight?.directionWord && p.weight.firstKg != null && p.weight.latestKg != null) {
    const d = lb(p.weight.latestKg) - lb(p.weight.firstKg);
    changed.push(
      `weight ${d < 0 ? "down" : "up"} ${Math.abs(d).toFixed(1)} lb `
      + `(${lb(p.weight.firstKg).toFixed(1)} → ${lb(p.weight.latestKg).toFixed(1)} lb), ${p.weight.directionWord}`
    );
  }
  for (const s of p.symptoms ?? []) {
    changed.push(`${s.word} ${s.count}×${s.timingNote ? ` — ${s.timingNote}` : ""}`);
  }
  if (p.nutrition && p.nutrition.proteinDaysMet * 2 < p.nutrition.loggedDays) {
    changed.push(
      `protein floor reached on ${p.nutrition.proteinDaysMet} of ${p.nutrition.loggedDays} logged days `
      + `(target ${p.nutrition.targetG} g)`
    );
  }

  // ---- still open
  const open: string[] = [...(p.gaps ?? [])];
  for (const c of chart.corrections.filter((c) => c.status === "open")) {
    open.push(`she reported the ${c.category} on her plan looks wrong — filed ${fmtDateShort(c.created_at)}.`);
  }

  // ---- may deserve discussion
  const hers = (p.questions ?? []).filter((q) => q.origin === "her");
  const surfaced = (p.questions ?? []).filter((q) => q.origin !== "her");

  return (
    <section className="read" aria-label="pre-visit read">
      <div className="read-head">
        <span className="eyebrow">the interval</span>
        <span className="read-window num">{p.window?.label ?? "last 4 weeks"}</span>
      </div>

      <ReadLine label="what you intended" items={intended} />
      <ReadLine label="what happened" items={happened} />
      <ReadLine label="what changed" items={changed} lead />
      <ReadLine label="still open" items={open} />
      <ReadLine
        label="may deserve discussion"
        items={[
          ...hers.map((q) => `${q.text} — her words`),
          ...surfaced.map((q) => q.text),
        ]}
      />

      {series && (
        <IntervalTimeline
          series={series}
          window={p.window?.label ?? ""}
          anchorWeekday={regimen?.anchor_weekday ?? null}
          startedAt={regimen?.started_at ?? null}
        />
      )}

      <p className="disclaimer read-foot">
        composed from records she entered, over the window her consent
        allows. jeni organizes the evidence; the reading is yours.
      </p>
    </section>
  );
}

function ReadLine({ label, items, lead }: { label: string; items: string[]; lead?: boolean }) {
  return (
    <div className={`read-line${lead ? " lead" : ""}`}>
      <div className="read-label">{label}</div>
      <div className="read-body">
        {items.length === 0
          ? <span className="read-none">nothing recorded</span>
          : items.map((t, i) => <p key={i}>{t}</p>)}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- timeline

/// Four weeks on one axis: the weight line, the days a dose was
/// marked, and the days a symptom was recorded. Reading the
/// relationship is the clinician's job — the drawing only has to put
/// the facts on the same horizontal.
function IntervalTimeline({ series, window, anchorWeekday, startedAt }: {
  series: PatientSeries;
  window: string;
  anchorWeekday: number | null;
  startedAt: string | null;
}) {
  const DAYS = 28;
  const W = 720, H = 150, PAD_L = 44, PAD_R = 44, TOP = 12, LINE_H = 54;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const dayIndex = (iso: string): number => {
    const d = new Date(iso.length <= 10 ? iso + "T00:00:00" : iso);
    d.setHours(0, 0, 0, 0);
    return DAYS - 1 - Math.round((today.getTime() - d.getTime()) / 86_400_000);
  };
  const dateAt = (i: number): Date => {
    const d = new Date(today);
    d.setDate(d.getDate() - (DAYS - 1 - i));
    return d;
  };
  const x = (i: number) => PAD_L + (i / (DAYS - 1)) * (W - PAD_L - PAD_R);

  const weights = series.weights
    .map((w) => ({ i: dayIndex(w.logged_at), kg: w.weight_kg }))
    .filter((w) => w.i >= 0 && w.i < DAYS)
    .sort((a, b) => a.i - b.i);

  // SCHEDULED days come from the plan's own rhythm, not from the
  // marks — otherwise a day she never answered simply vanishes, and
  // "scheduled, not marked" becomes a legend entry that can never
  // appear. The unanswered day is the one worth seeing.
  const marks = new Map<number, string>();
  for (const o of series.observations) {
    if (o.kind === "doseTaken") marks.set(dayIndex(o.day_key), o.value_text ?? "");
  }
  const started = startedAt ? new Date(startedAt) : null;
  if (started) started.setHours(0, 0, 0, 0);
  const doses: { i: number; state: "taken" | "skipped" | "open" }[] = [];
  if (anchorWeekday) {
    for (let i = 0; i < DAYS; i++) {
      const d = dateAt(i);
      const iso = d.getDay() === 0 ? 7 : d.getDay();
      if (iso !== anchorWeekday) continue;
      if (started && d < started) continue;
      const mark = marks.get(i);
      doses.push({
        i,
        state: mark === "yes" ? "taken"
          : mark === "no" || mark === "skipped" ? "skipped" : "open",
      });
    }
  } else {
    for (const [i, v] of marks) {
      doses.push({ i, state: v === "yes" ? "taken" : "skipped" });
    }
  }

  const symptomDays = [
    ...new Set(
      series.observations
        .filter((o) => o.kind === "symptom" || (o.kind === "sitCheck" && o.value_text === "heavy"))
        .map((o) => dayIndex(o.day_key))
        .filter((i) => i >= 0 && i < DAYS)
    ),
  ];

  const kgs = weights.map((w) => w.kg);
  const lo = Math.min(...kgs), hi = Math.max(...kgs);
  const span = hi - lo || 1;
  const y = (kg: number) => TOP + (1 - (kg - lo) / span) * LINE_H;
  const path = weights.length > 1
    ? weights.map((w, i) => `${i === 0 ? "M" : "L"}${x(w.i).toFixed(1)},${y(w.kg).toFixed(1)}`).join(" ")
    : "";

  const ROW_DOSE = TOP + LINE_H + 30;
  const ROW_SYMPTOM = ROW_DOSE + 24;
  const first = weights[0], last = weights[weights.length - 1];

  return (
    <figure className="timeline">
      <figcaption className="eyebrow">four weeks, one axis · {window}</figcaption>
      <svg viewBox={`0 0 ${W} ${H}`} role="img"
        aria-label={
          `weight across ${weights.length} weigh-ins; ${doses.length} scheduled dose days; `
          + `${symptomDays.length} days with a symptom recorded`
        }>
        {/* the weight line, anchored by its own two numbers */}
        {path && <path d={path} className="tl-weight" />}
        {weights.map((w, i) => (
          <circle key={i} cx={x(w.i)} cy={y(w.kg)} r="2.2" className="tl-weight-dot" />
        ))}
        {first && (
          <text x={x(first.i) - 7} y={y(first.kg) + 3.5} className="tl-num" textAnchor="end">
            {lb(first.kg).toFixed(0)}
          </text>
        )}
        {last && (
          <text x={x(last.i) + 7} y={y(last.kg) + 3.5} className="tl-num">
            {lb(last.kg).toFixed(0)} lb
          </text>
        )}

        {/* dose days — filled when marked taken, hollow when not */}
        <line x1={PAD_L} y1={ROW_DOSE} x2={W - PAD_R} y2={ROW_DOSE} className="tl-rule" />
        {doses.map((d) => (
          <circle key={d.i} cx={x(d.i)} cy={ROW_DOSE} r="4.5"
            className={`tl-dose ${d.state}`} />
        ))}

        {/* symptom days */}
        {symptomDays.map((i) => (
          <rect key={i} x={x(i) - 1.5} y={ROW_SYMPTOM - 5} width="3" height="10"
            rx="1.5" className="tl-symptom" />
        ))}
      </svg>
      <div className="tl-key">
        <span><i className="k-weight" /> weight</span>
        <span><i className="k-dose" /> dose marked taken</span>
        <span><i className="k-dose-open" /> scheduled, not marked</span>
        <span><i className="k-symptom" /> symptom recorded</span>
      </div>
    </figure>
  );
}
