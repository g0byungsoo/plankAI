import { test, expect } from "@playwright/test";

// Live E2E against a real Supabase environment (default: the dev
// project). Builds its own fixture through the same API the apps use
// (publishable key only), then drives the real dashboard. No mocks:
// this proves the clinician surface + RLS + RPCs together.

const BASE = process.env.CARE_SUPABASE_URL ?? "https://mtecqvykyeueumdynatd.supabase.co";
const ANON = process.env.CARE_SUPABASE_ANON_KEY ?? "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu";

async function api(method: string, path: string, token: string | null, body?: unknown) {
  const headers: Record<string, string> = { apikey: ANON, "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}
const rpc = (t: string | null, fn: string, p: unknown) => api("POST", `/rest/v1/rpc/${fn}`, t, p);
const rand = () => Math.random().toString(36).slice(2, 8);

test("clinician signs in, sees a consenting patient's record, assigns care", async ({ page }) => {
  // --- fixture ---
  const clinEmail = `s4pw-${rand()}@example.com`;
  const clinPw = "Aa1" + rand() + rand();
  const su = await api("POST", "/auth/v1/signup", null, { email: clinEmail, password: clinPw });
  expect(su.status).toBe(200);
  const clin = su.body.access_token as string;
  const anon = await api("POST", "/auth/v1/signup", null, {});
  const pat = anon.body.access_token as string;
  const patId = anon.body.user.id as string;

  const org = await rpc(clin, "care_create_org", { p_name: "Playwright Clinic", p_owner_is_clinician: true });
  const orgId = org.body.org_id as string;
  const inv = await rpc(clin, "care_create_invitation", { p_org: orgId, p_label: "PW Patient" });
  const code = inv.body.code as string;

  const acc = await rpc(pat, "care_accept_invitation", {
    p_code: code, p_lookback_days: 28,
    p_scopes: ["visit_packet_view", "observation_view", "care_assignment"],
  });
  expect(acc.body.ok).toBe(true);

  await api("POST", "/rest/v1/visit_packets", pat, {
    id: `${patId}-${orgId}`, user_id: patId, org_id: orgId,
    payload: { window: { label: "test window" }, weight: { entryCount: 4, firstKg: 80, latestKg: 78, directionWord: "easing" }, questions: [], gaps: [] },
    window_start: "2026-07-02", window_end: "2026-07-29", app_version: "pw",
  });

  // --- drive the dashboard ---
  await page.goto("/");
  await page.getByLabel("email").fill(clinEmail);
  await page.getByLabel("password").fill(clinPw);
  await page.getByRole("button", { name: "sign in" }).click();

  await expect(page.locator(".masthead")).toBeVisible();
  await expect(page.getByText("PW Patient")).toBeVisible();

  await page.locator("button.row").first().click();
  await expect(page.getByRole("heading", { name: "PW Patient" })).toBeVisible();
  await expect(page.getByText("easing")).toBeVisible();

  // assign a regimen through the real RPC via the sheet
  await page.getByRole("button", { name: /assign medication plan/i }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByLabel("medication name (the patient sees this)").fill("semaglutide");
  await page.getByLabel("dose per injection — mg").fill("0.5");
  await page.getByRole("group", { name: "weekly day" }).getByRole("button", { name: "wed" }).click();
  await page.getByRole("button", { name: "assign plan" }).click();

  await expect(page.getByText("semaglutide")).toBeVisible();
  await expect(page.getByText("weekly · wednesdays")).toBeVisible();

  // verify server-side: the patient now has a care_team regimen
  const check = await api("GET", `/rest/v1/regimen_plans?select=display_name,authority&authority=eq.care_team`, pat);
  expect(check.body.length).toBe(1);
  expect(check.body[0].display_name).toBe("semaglutide");
});
