// Shapes returned by the care_* RPCs (10_S4_CLINIC_LOOP §3).

export interface PatientRow {
  patient_id: string;
  label: string;
  status: "active" | "revoked" | "ended";
  established_at: string;
  ended_at: string | null;
  follow_up_on: string | null;
  reviewed_at: string | null;
  packet_generated_at: string | null;
  open_corrections: number;
  scopes: string[];
  needs_attention: boolean;
}

export interface CareTeamRegimen {
  id: string;
  display_name: string;
  strength_value: number | null;
  strength_unit: string | null;
  anchor_weekday: number | null;
  schedule_rule: string;
  instruction: string | null;
  started_at: string | null;
  ended_at: string | null;
  updated_at: string | null;
}

export interface Correction {
  id: string;
  regimen_plan_id: string;
  category: string;
  note: string | null;
  status: "open" | "accepted" | "dismissed";
  resolution_note: string | null;
  created_at: string;
  resolved_at: string | null;
}

export interface Chart {
  relationship: {
    id: string;
    status: string;
    label: string;
    established_at: string;
    ended_at: string | null;
    follow_up_on: string | null;
    reviewed_at: string | null;
  };
  scopes: string[];
  lookback_start: string | null;
  assignment: {
    id: string;
    protocol_id: string;
    status: string;
    assigned_at: string;
    protocol_title: string;
    protocol_version: number;
  } | null;
  care_team_regimens: CareTeamRegimen[];
  self_regimen: { exists: boolean; anchor_weekday: number | null; started_at: string | null } | null;
  corrections: Correction[];
  packet_meta: { generated_at: string; window_start: string | null; window_end: string | null } | null;
}

export interface VisitPacketPayload {
  window?: { label?: string };
  regimen?: {
    displayLine: string;
    authorityLabel: string;
    anchorWeekdayWord: string | null;
    scheduledCount: number;
    takenCount: number;
    skippedCount: number;
    unrecordedCount: number;
  } | null;
  weight?: { entryCount: number; firstKg: number | null; latestKg: number | null; directionWord: string | null } | null;
  symptoms?: { word: string; count: number; timingNote: string | null }[];
  nutrition?: { loggedDays: number; proteinDaysMet: number; targetG: number } | null;
  movement?: { movedDays: number; stepsWeekAvg: number | null } | null;
  questions?: { id: string; text: string; origin: string }[];
  gaps?: string[];
  displayUnit?: string;
}

export const WEEKDAY_WORDS = [
  "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
];

export function weekdayWord(iso: number | null | undefined): string {
  if (!iso || iso < 1 || iso > 7) return "—";
  return WEEKDAY_WORDS[iso - 1];
}

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }).toLowerCase();
}

export function fmtDateShort(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" }).toLowerCase();
}
