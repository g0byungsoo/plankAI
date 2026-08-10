// THE WEB CAPTURE SYSTEM.
//
//   node scripts/demo/capture.mjs [outdir]
//
// Deterministic frames of the clinician product, taken from the REAL
// dashboard against the demo clinic. Every shot is a state the demo
// can be driven to by hand; nothing here is a mock.
//
// Two disciplines carried over from the S5 capture spec:
//   · the pointer is parked off-canvas before every shot, so no row
//     wears a hover state it did not earn;
//   · a leak check runs over the rendered text — a uuid, an email, a
//     localhost URL or a dev artifact in a marketing frame is a bug,
//     not a detail.
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, "../../clinic/package.json"));
const { chromium } = require("playwright");

const BASE = process.env.CARE_DASHBOARD_URL || "http://localhost:5273";
const EMAIL = process.env.DEMO_CLINICIAN_EMAIL || "a.osei@sagemetabolic.example";
const PASSWORD = process.env.DEMO_PASSWORD || "demo-sage-2026";
const OUT = process.argv[2] || path.join(here, "../../docs/demo/shots/web");

fs.mkdirSync(OUT, { recursive: true });

const LEAKS = [
  [/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i, "a uuid"],
  [/localhost:\d+|127\.0\.0\.1/, "a local URL"],
  [/@(?!sagemetabolic|demo\.invalid)[\w.-]+\.\w+/, "an email address"],
];

const problems = [];

async function shot(page, name, opts = {}) {
  await page.mouse.move(4, 4);          // park the pointer, kill hover
  await page.waitForTimeout(320);
  const target = opts.selector ? page.locator(opts.selector).first() : page;
  await target.screenshot({
    path: path.join(OUT, `${name}.png`),
    ...(opts.selector ? {} : { fullPage: !!opts.fullPage }),
  });
  const text = await page.locator("body").innerText();
  for (const [re, what] of LEAKS) {
    const m = text.match(re);
    if (m) problems.push(`${name}: ${what} on screen — ${m[0]}`);
  }
  console.log(`  ${name}.png`);
}

/** Hide the internal-environment chrome a real clinic would not see. */
async function hideDevChrome(page) {
  await page.addStyleTag({
    content: `
      /* The "development" environment token is an internal artifact.
         The "demo clinic" token STAYS — it is true, and hiding it
         would be the dishonest choice. */
      .masthead .token.off { display: none !important; }
    `,
  });
}

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 1440, height: 940 },
  deviceScaleFactor: 2,
  colorScheme: "light",
  reducedMotion: "reduce",
});
const page = await ctx.newPage();
const consoleErrors = [];
page.on("console", (m) => m.type() === "error" && consoleErrors.push(m.text()));
page.on("pageerror", (e) => consoleErrors.push(String(e)));

console.log(`capturing → ${OUT}`);

// ---- sign in -----------------------------------------------------
await page.goto(BASE, { waitUntil: "networkidle" });
await hideDevChrome(page);
if (await page.locator('input[type="email"]').count()) {
  await shot(page, "00-sign-in");
  await page.fill('input[type="email"]', EMAIL);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForTimeout(2600);
}
await hideDevChrome(page);
await page.waitForTimeout(600);

// ---- 1. the attention queue --------------------------------------
await shot(page, "01-attention-queue");
await shot(page, "01b-attention-queue-full", { fullPage: true });

// ---- 2. the patient story ----------------------------------------
await page.getByText("Maya C.").first().click();
await page.waitForTimeout(2800);
await hideDevChrome(page);
await shot(page, "02-patient-top");
await shot(page, "03-pre-visit-read", { selector: ".read" });
await shot(page, "02b-patient-full", { fullPage: true });

// ---- 3. the program this clinic sets -----------------------------
const facts = page.locator(".facts").first();
if (await facts.count()) {
  await facts.scrollIntoViewIfNeeded();
  await page.waitForTimeout(400);
  await shot(page, "04-program-configuration", { selector: ".facts" });
}

// ---- 4. the assigned-care ledger ---------------------------------
const assigned = page.locator(".panel").first();
if (await assigned.count()) {
  await assigned.scrollIntoViewIfNeeded();
  await page.waitForTimeout(400);
}

// ---- 5. assigning a medication plan (the sheet) ------------------
const update = page.getByRole("button", { name: /update medication plan/i });
if (await update.count()) {
  await update.first().click();
  await page.waitForTimeout(700);
  await shot(page, "05-assign-regimen", { selector: ".sheet" });
  await page.keyboard.press("Escape");
  await page.waitForTimeout(400);
}

// ---- 6. a quiet patient (the contrast shot) ----------------------
await page.getByRole("button", { name: /patients/i }).first().click();
await page.waitForTimeout(1600);
await hideDevChrome(page);
const showQuiet = page.getByRole("button", { name: /^show$/ });
if (await showQuiet.count()) {
  await showQuiet.first().click();
  await page.waitForTimeout(500);
  await shot(page, "06-queue-expanded", { fullPage: true });
}

// ---- 7. dark paper ------------------------------------------------
await page.emulateMedia({ colorScheme: "dark" });
await page.waitForTimeout(500);
await shot(page, "07-attention-queue-dark");
await page.emulateMedia({ colorScheme: "light" });

await browser.close();

if (consoleErrors.length) {
  console.log("\nconsole errors:");
  for (const e of consoleErrors.slice(0, 8)) console.log("  " + e);
}
if (problems.length) {
  console.log("\nLEAK CHECK FAILED:");
  for (const p of problems) console.log("  " + p);
  process.exit(1);
}
console.log("\nleak check clean.");
