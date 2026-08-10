// THE ATTENTION MODEL
//
// The clinic home answers four questions and refuses to answer any
// others: who needs a read, why, how long it has been waiting, and
// what has already been handled. Everything else on this screen is
// noise wearing a clinical typeface.
//
// The reasons are composed HERE, in the product layer, from the
// packet the patient published — never in SQL, and never invented.
// Each line traces to a count she recorded. Timing is stated; cause
// never is. The vocabulary is the packet's own (09_S3_PACKET §4):
// plain counts, "unrecorded is not skipped", no scores, no severity
// ranks, no risk language.

import type { PatientRow, VisitPacketPayload } from "./types";
import { fmtDateShort } from "./types";

export type Urgency = "waiting" | "review" | "quiet";

export interface Reason {
  /** The sentence a clinician reads. */
  line: string;
  /** Where it came from, so nothing is unattributable. */
  from: "symptoms" | "doses" | "protein" | "weight" | "correction" | "follow-up";
}

export interface Attention {
  row: PatientRow;
  urgency: Urgency;
  /** The one sentence that earns the row its place. */
  headline: Reason | null;
  /** At most two more facts, so the row is a read and not a chart. */
  support: Reason[];
  /** How long this has gone unread, in the clinic's own terms. */
  waiting: string;
  /** Sort key — larger is more overdue. Days. */
  waitingDays: number;
  /** True once someone has read the record since it last changed. */
  handled: boolean;
}

const DAY = 86_400_000;

function daysSince(iso: string | null | undefined): number | null {
  if (!iso) return null;
  return Math.floor((Date.now() - new Date(iso).getTime()) / DAY);
}

function plural(n: number, one: string, many = one + "s"): string {
  return `${n} ${n === 1 ? one : many}`;
}

/** "3 days" / "a day" / "today" — durations a person would say. */
function span(days: number): string {
  if (days <= 0) return "today";
  if (days === 1) return "a day";
  return `${days} days`;
}

// ---------------------------------------------------------------- reasons

function symptomReasons(p: VisitPacketPayload): Reason[] {
  const symptoms = p.symptoms ?? [];
  if (!symptoms.length) return [];
  const timed = symptoms.filter((s) => s.timingNote);
  const named = (list: typeof symptoms) =>
    list.map((s) => `${s.word} ${s.count}×`).join(", ");

  // The strongest honest statement: these landed near dose days.
  if (timed.length) {
    return [{
      from: "symptoms",
      line: `${named(timed)} — ${timed[0].timingNote}.`,
    }];
  }
  const notable = symptoms.filter((s) => s.count >= 3);
  if (notable.length) {
    return [{ from: "symptoms", line: `${named(notable)} this period.` }];
  }
  return [];
}

function doseReason(p: VisitPacketPayload): Reason | null {
  const r = p.regimen;
  if (!r || r.scheduledCount === 0) return null;
  const missing = r.skippedCount + r.unrecordedCount;
  if (missing < 2) return null;
  const parts: string[] = [];
  if (r.takenCount) parts.push(`${r.takenCount} of ${r.scheduledCount} doses marked taken`);
  if (r.skippedCount) parts.push(`${r.skippedCount} skipped`);
  if (r.unrecordedCount) parts.push(`${r.unrecordedCount} unrecorded`);
  return { from: "doses", line: `${parts.join(", ")}. unrecorded is not skipped.` };
}

function proteinReason(p: VisitPacketPayload): Reason | null {
  const n = p.nutrition;
  if (!n || n.loggedDays < 5) return null;
  // Only worth saying when it is mostly not being met.
  if (n.proteinDaysMet * 2 >= n.loggedDays) return null;
  return {
    from: "protein",
    line: `protein floor met on ${n.proteinDaysMet} of ${n.loggedDays} logged days (${n.targetG} g).`,
  };
}

function weightReason(p: VisitPacketPayload): Reason | null {
  const w = p.weight;
  if (!w || !w.directionWord || w.firstKg == null || w.latestKg == null) return null;
  const deltaKg = w.latestKg - w.firstKg;
  const lb = Math.abs(deltaKg * 2.2046);
  if (lb < 1) return null;
  const word = deltaKg < 0 ? "down" : "up";
  return {
    from: "weight",
    line: `weight ${word} ${lb.toFixed(1)} lb across ${plural(w.entryCount, "weigh-in")}.`,
  };
}

// ---------------------------------------------------------------- read

export function read(row: PatientRow): Attention {
  const packet = (row.packet ?? null) as VisitPacketPayload | null;
  const reasons: Reason[] = [];

  // A filed correction outranks everything the record can say: a
  // patient is telling the clinic its own record is wrong.
  const correctionDays = daysSince(row.oldest_open_correction_at);
  if (row.open_corrections > 0) {
    reasons.push({
      from: "correction",
      line: row.open_corrections === 1
        ? "she reported something wrong with the plan on file."
        : `${row.open_corrections} reports about the plan on file.`,
    });
  }

  // A review the clinic set for itself.
  const followDays = row.follow_up_on
    ? Math.floor((Date.now() - new Date(row.follow_up_on + "T00:00:00").getTime()) / DAY)
    : null;
  if (followDays !== null && followDays >= 0) {
    reasons.push({
      from: "follow-up",
      line: `follow-up was set for ${fmtDateShort(row.follow_up_on)}.`,
    });
  }

  // TRIGGERS vs CONTEXT — the distinction the whole screen rests on.
  //
  // A trigger is something unresolved: a report, a date the clinic
  // set, symptoms clustering, doses going unrecorded, a protein floor
  // that stopped being met. Context is everything else the record can
  // say — most of all the weight trend, which is usually GOOD news and
  // must never by itself put a patient on this list. Treating every
  // fact as a reason is how a queue becomes a feed: the first version
  // of this screen listed six of seven patients, and five of them were
  // there because they had lost weight.
  const triggers = reasons.length;
  if (packet) {
    reasons.push(...symptomReasons(packet));
    const dose = doseReason(packet);
    if (dose) reasons.push(dose);
    const protein = proteinReason(packet);
    if (protein) reasons.push(protein);
  }
  const hasTrigger = reasons.length > triggers || triggers > 0;

  // Context rides along only once something already earned the row.
  if (packet && hasTrigger) {
    const weight = weightReason(packet);
    if (weight) reasons.push(weight);
  }

  // Handled: someone read this record after it last changed.
  const handled =
    !!row.reviewed_at &&
    (!row.packet_generated_at ||
      new Date(row.reviewed_at) >= new Date(row.packet_generated_at));

  // How long it has waited. A correction and a follow-up date carry
  // their own clocks; otherwise it is how long since anyone read her.
  let waitingDays = 0;
  let waiting = "";
  if (correctionDays !== null && row.open_corrections > 0) {
    waitingDays = correctionDays;
    waiting = correctionDays <= 0 ? "filed today" : `filed ${span(correctionDays)} ago`;
  } else if (followDays !== null && followDays >= 0) {
    waitingDays = followDays;
    waiting = followDays === 0 ? "due today" : `${span(followDays)} past`;
  } else {
    const readDays = daysSince(row.reviewed_at);
    const knownDays = daysSince(row.established_at) ?? 0;
    waitingDays = readDays ?? knownDays;
    waiting = readDays === null
      ? "never read"
      : `not read for ${span(readDays)}`;
  }

  // Urgency. A correction or a date the clinic set is WAITING — a
  // person or a promise is on the other end of it. A record that grew
  // a signal on its own is REVIEW. Everything else is quiet, and quiet
  // is the honest majority.
  const urgency: Urgency =
    handled ? "quiet"
      : row.open_corrections > 0 || (followDays !== null && followDays >= 0) ? "waiting"
      : hasTrigger ? "review"
      : "quiet";

  return {
    row,
    urgency,
    headline: reasons[0] ?? null,
    support: reasons.slice(1, 3),
    waiting,
    waitingDays,
    handled,
  };
}

export interface Queue {
  needsRead: Attention[];
  handled: Attention[];
  quiet: Attention[];
  ended: Attention[];
}

export function build(rows: PatientRow[]): Queue {
  const all = rows.map(read);
  const active = all.filter((a) => a.row.status === "active");
  const rank = (a: Attention) => (a.urgency === "waiting" ? 0 : 1);
  return {
    needsRead: active
      .filter((a) => a.urgency !== "quiet")
      .sort((a, b) => rank(a) - rank(b) || b.waitingDays - a.waitingDays),
    handled: active
      .filter((a) => a.urgency === "quiet" && a.handled)
      .sort((a, b) => a.waitingDays - b.waitingDays),
    quiet: active
      .filter((a) => a.urgency === "quiet" && !a.handled)
      .sort((a, b) => a.row.label.localeCompare(b.row.label)),
    ended: all.filter((a) => a.row.status !== "active"),
  };
}
