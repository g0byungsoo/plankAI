import { test, expect, type Page } from "@playwright/test";
import * as fs from "fs";

// The repeatable product-evidence pathway (11_S5 §12): seeds a
// FICTIONAL clinic on a disposable local stack, drives the REAL
// dashboard, leak-checks the DOM, and captures the website's
// screenshots. Never run against a real environment — it refuses
// non-local targets. Enable with CAPTURE=1:
//   CAPTURE=1 CARE_SUPABASE_URL=http://127.0.0.1:54321 \
//   CARE_SUPABASE_ANON_KEY=... npx playwright test capture
// The dashboard dev server must be running with the SAME local env.

const BASE = process.env.CARE_SUPABASE_URL ?? "";
const ANON = process.env.CARE_SUPABASE_ANON_KEY ?? "";
const OUT = "../site/assets/shots";

test.skip(!process.env.CAPTURE, "capture runs only with CAPTURE=1");

async function api(method: string, path: string, token: string | null, body?: unknown, prefer?: string) {
  const headers: Record<string, string> = { apikey: ANON, "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (prefer) headers.Prefer = prefer;
  const res = await fetch(BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}
const rpc = (t: string | null, fn: string, p: unknown) => api("POST", `/rest/v1/rpc/${fn}`, t, p);
const rand = () => Math.random().toString(36).slice(2, 8);

// Internal-only chrome (the environment badge, the multi-org
// selector) is real product behavior but not marketing evidence —
// in a pilot deploy the badge is already absent. Hide it so captures
// present the pilot surface, then leak-check the VISIBLE text.
async function hideInternalChrome(page: Page) {
  await page.addStyleTag({ content: `.token, select[aria-label="organization"], .masthead .who { display: none !important; }` });
}

// The VISIBLE text must be clean before any pixel is captured. We
// check innerText (not attributes) so element ids/values don't
// false-positive, while any leaked name/email/host still trips.
async function leakCheck(page: Page, name: string) {
  let text = await page.evaluate(() => document.body.innerText);
  // The legitimate marketing support address is content, not a leak.
  text = text.replace(/hello@jenicare\.example/gi, "");
  const leaks: string[] = [];
  if (/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i.test(text)) leaks.push("uuid");
  if (/@[a-z0-9.-]+\.(com|invalid|example|co|health)/i.test(text)) leaks.push("email");
  if (/localhost|127\.0\.0\.1/.test(text)) leaks.push("localhost");
  if (/\bdevelopment\b|\bdebug\b/i.test(text)) leaks.push("dev-artifact");
  expect(leaks, `${name}: visible leaks ${leaks.join(",")}`).toEqual([]);
}

async function shot(page: Page, name: string, opts?: { clip?: { x: number; y: number; width: number; height: number } }) {
  await hideInternalChrome(page);
  await leakCheck(page, name);
  await page.screenshot({ path: `${OUT}/${name}.png`, ...opts });
}

test("capture website product evidence from a fictional clinic", async ({ page }) => {
  test.setTimeout(180_000);
  if (!/127\.0\.0\.1|localhost/.test(BASE)) throw new Error("capture only runs against a local stack");
  fs.mkdirSync(OUT, { recursive: true });

  // ---- fictional fixture (its own org; NOT the demo tenant) ----
  const clinEmail = `capture-${rand()}@example.com`;
  const clinPw = "Aa1" + rand() + rand();
  const su = await api("POST", "/auth/v1/signup", null, { email: clinEmail, password: clinPw });
  const clin = su.body.access_token as string;
  const org = (await rpc(clin, "care_create_org", { p_name: "Sage Metabolic Health", p_owner_is_clinician: true })).body.org_id as string;
  await rpc(clin, "care_add_member", { p_org: org, p_email: clinEmail, p_role: "owner", p_display_name: "Dr. Amara Osei", p_credential: "MD", p_clinical: true });

  // Four patients in distinct, plausible states.
  const mk = async (label: string, scopes: string[], lookback: number) => {
    const inv = await rpc(clin, "care_create_invitation", { p_org: org, p_label: label });
    const anon = await api("POST", "/auth/v1/signup", null, {});
    const tok = anon.body.access_token as string;
    const uid = anon.body.user.id as string;
    await rpc(tok, "care_accept_invitation", { p_code: inv.body.code, p_lookback_days: lookback, p_scopes: scopes });
    return { tok, uid };
  };

  const today = new Date();
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  const daysAgo = (n: number) => new Date(today.getTime() - n * 86400000);
  const windowLabel = `${daysAgo(27).toLocaleDateString("en-US", { month: "short", day: "numeric" })} – ${today.toLocaleDateString("en-US", { month: "short", day: "numeric" })}`.toLowerCase();

  const jordan = await mk("Jordan D.", ["visit_packet_view", "observation_view", "care_assignment"], 28);
  await api("POST", "/rest/v1/visit_packets", jordan.tok, {
    id: `${jordan.uid}-${org}`, user_id: jordan.uid, org_id: org,
    payload: {
      window: { label: windowLabel },
      regimen: { displayLine: "your weekly medication", authorityLabel: "self-reported", anchorWeekdayWord: "wednesday", scheduledCount: 4, takenCount: 3, skippedCount: 0, unrecordedCount: 1 },
      weight: { entryCount: 5, firstKg: 96.4, latestKg: 94.8, directionWord: "easing" },
      symptoms: [{ word: "queasy", count: 2, timingNote: "both within 2 days of a marked dose" }, { word: "fine", count: 9, timingNote: null }],
      nutrition: { loggedDays: 16, proteinDaysMet: 9, targetG: 90 },
      movement: { movedDays: 11, stepsWeekAvg: 6214 },
      questions: [
        { id: "q1", text: "you may want to mention how the weekly rhythm is fitting.", origin: "generated" },
        { id: "q2", text: "does the queasy day after my shot ever settle down?", origin: "her" },
      ],
      gaps: ["sleep wasn't recorded this period."],
      displayUnit: "lb",
    },
    window_start: iso(daysAgo(27)), window_end: iso(today), app_version: "capture",
  }, "resolution=merge-duplicates");

  const maya = await mk("Maya R.", ["visit_packet_view"], 28);
  await api("POST", "/rest/v1/visit_packets", maya.tok, {
    id: `${maya.uid}-${org}`, user_id: maya.uid, org_id: org,
    payload: {
      window: { label: windowLabel },
      weight: { entryCount: 3, firstKg: 82.1, latestKg: 81.6, directionWord: null },
      symptoms: [], questions: [], gaps: ["medication wasn't recorded this period."], displayUnit: "lb",
    },
    window_start: iso(daysAgo(27)), window_end: iso(today), app_version: "capture",
  }, "resolution=merge-duplicates");

  const priya = await mk("Priya S.", ["visit_packet_view", "care_assignment"], 0);
  const priyaRegimen = (await rpc(clin, "care_assign_regimen", {
    p_org: org, p_patient: priya.uid, p_name: "semaglutide", p_strength_mg: 1.0,
    p_anchor_weekday: 5, p_started_on: iso(daysAgo(21)), p_instruction: "evening, thigh or abdomen ok",
  })).body as string;
  await rpc(priya.tok, "care_submit_correction", {
    p_org: org, p_regimen_plan_id: priyaRegimen, p_category: "strength",
    p_note: "my last visit moved me to 1.7 mg, I think",
  });

  const dana = await mk("Dana K.", ["visit_packet_view"], 28);
  await rpc(dana.tok, "care_revoke_consent", { p_org: org, p_scope: null, p_disconnect: true });

  // ---- drive the dashboard ----
  await page.setViewportSize({ width: 1360, height: 900 });
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/");
  await page.getByLabel("email").fill(clinEmail);
  await page.getByLabel("password").fill(clinPw);
  await page.getByRole("button", { name: "sign in" }).click();
  await expect(page.locator(".masthead")).toBeVisible();
  await expect(page.getByText("Jordan D.")).toBeVisible();

  // Sign-in screen (fresh context would be cleaner; capture it last instead)

  // 1. roster
  await page.waitForTimeout(400);
  await shot(page, "roster");

  // 2. patient detail (Jordan: full packet)
  await page.getByRole("button", { name: /Jordan D\./ }).click();
  await expect(page.getByRole("heading", { name: "Jordan D." })).toBeVisible();
  await expect(page.getByText("easing")).toBeVisible();
  await page.waitForTimeout(400);
  await shot(page, "patient-detail");

  // 3. the packet, framed alone
  const packet = page.locator(".panel").filter({ hasText: "marked taken" });
  await leakCheck(page, "packet");
  await packet.screenshot({ path: `${OUT}/packet.png` });

  // 4. assign sheet, filled
  await page.getByRole("button", { name: /assign medication plan/i }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByLabel("medication name (the patient sees this)").fill("semaglutide");
  await page.getByLabel(/dose per injection/).fill("0.5");
  await page.getByRole("group", { name: "weekly day" }).getByRole("button", { name: "wed" }).click();
  await page.waitForTimeout(250);
  await shot(page, "assign-sheet");
  await page.keyboard.press("Escape");

  // 5. corrections queue (Priya)
  await page.getByRole("button", { name: "‹ patients" }).click();
  await page.getByRole("button", { name: /Priya S\./ }).click();
  await expect(page.getByText("needs your decision")).toBeVisible();
  await page.waitForTimeout(400);
  await shot(page, "correction");

  // 6. clinic screen (team + invitations)
  await page.getByRole("button", { name: "clinic", exact: true }).click();
  await expect(page.getByRole("heading", { name: "clinic" })).toBeVisible();
  await page.waitForTimeout(300);
  await shot(page, "clinic");

  // 7. invite sheet with a code revealed
  await page.getByRole("button", { name: "invite a patient" }).click();
  await page.getByLabel("patient label").fill("Alex T.");
  await page.getByRole("button", { name: "generate code" }).click();
  await expect(page.locator(".reveal-code")).toBeVisible();
  await page.waitForTimeout(250);
  await shot(page, "invite-code");
  await page.getByRole("button", { name: "done" }).click();

  console.log(`captures written to ${OUT}`);
});
