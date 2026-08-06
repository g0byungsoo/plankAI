import type { VisitPacketPayload } from "../types";
import { DL } from "../kit";

// Renders the canonical S3 VisitPacket the PATIENT published. The
// clinic never recomputes the projection — it reads her serialized
// output verbatim, so every line traces to a record and the
// "unrecorded is not skipped" honesty carries through unchanged.
export function PacketView({ packet }: { packet: VisitPacketPayload }) {
  const unit = packet.displayUnit ?? "lb";
  const kg = (v: number | null | undefined) =>
    v == null ? "—" : unit === "lb" ? `${(v * 2.20462).toFixed(1)} lb` : `${v.toFixed(1)} kg`;

  return (
    <div className="panel" style={{ padding: "6px 18px 16px" }}>
      {packet.regimen && (
        <Section title="medication">
          <DL items={[
            [packet.regimen.authorityLabel, packet.regimen.displayLine],
            ...(packet.regimen.anchorWeekdayWord ? [["schedule", `weekly · ${packet.regimen.anchorWeekdayWord}s`] as [string, string]] : []),
            ["marked taken", `${packet.regimen.takenCount} of ${packet.regimen.scheduledCount} scheduled`],
            ...(packet.regimen.skippedCount ? [["marked skipped", String(packet.regimen.skippedCount)] as [string, string]] : []),
            ...(packet.regimen.unrecordedCount ? [["unrecorded", String(packet.regimen.unrecordedCount)] as [string, string]] : []),
          ]} />
        </Section>
      )}

      {packet.weight && (
        <Section title="weight">
          <DL items={[
            ["weigh-ins", `${packet.weight.entryCount} this period`],
            ["first · latest", `${kg(packet.weight.firstKg)} · ${kg(packet.weight.latestKg)}`],
            ...(packet.weight.directionWord ? [["trend", packet.weight.directionWord] as [string, string]] : []),
          ]} />
        </Section>
      )}

      {packet.symptoms && packet.symptoms.length > 0 && (
        <Section title="how meals sat">
          <DL items={packet.symptoms.map((s) => [s.word, s.timingNote ? `${s.count}× · ${s.timingNote}` : `${s.count}×`] as [string, string])} />
        </Section>
      )}

      {packet.nutrition && (
        <Section title="protein">
          <DL items={[
            ["logged days", String(packet.nutrition.loggedDays)],
            ["reached the floor", `${packet.nutrition.proteinDaysMet} of ${packet.nutrition.loggedDays} · target ${packet.nutrition.targetG}g`],
          ]} />
        </Section>
      )}

      {packet.movement && (
        <Section title="movement">
          <DL items={[
            ["days moved", String(packet.movement.movedDays)],
            ...(packet.movement.stepsWeekAvg ? [["steps, past week", packet.movement.stepsWeekAvg.toLocaleString()] as [string, string]] : []),
          ]} />
        </Section>
      )}

      {packet.questions && packet.questions.length > 0 && (
        <Section title="questions she noted for the visit">
          <ul style={{ margin: 0, paddingLeft: 18 }}>
            {packet.questions.map((q) => <li key={q.id} style={{ padding: "3px 0", color: "var(--ink-2)" }}>{q.text}</li>)}
          </ul>
        </Section>
      )}

      {packet.gaps && packet.gaps.length > 0 && (
        <Section title="not recorded">
          <ul style={{ margin: 0, paddingLeft: 18 }}>
            {packet.gaps.map((g, i) => <li key={i} className="disclaimer" style={{ padding: "2px 0" }}>{g}</li>)}
          </ul>
        </Section>
      )}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ paddingTop: 12 }}>
      <div style={{ textTransform: "uppercase", letterSpacing: "0.09em", fontSize: 11, color: "var(--ink-3)", fontWeight: 600, marginBottom: 2, marginTop: 6 }}>{title}</div>
      {children}
    </div>
  );
}
