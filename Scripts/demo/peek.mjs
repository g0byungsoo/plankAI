// Quick look at the dashboard: sign in, walk to a screen, screenshot.
//   node scripts/demo/peek.mjs [path] [out.png]
// Used during development; the deliberate capture system is capture.mjs.
// playwright lives in clinic/node_modules; resolve it from there so
// this script can sit beside the rest of the demo tooling.
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";
const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, "../../clinic/package.json"));
const { chromium } = require("playwright");

const BASE = process.env.CARE_DASHBOARD_URL || "http://localhost:5273";
const EMAIL = process.env.DEMO_CLINICIAN_EMAIL || "a.osei@sagemetabolic.example";
const PASSWORD = process.env.DEMO_PASSWORD || "demo-sage-2026";
const OUT = process.argv[3] || "/tmp/claude-501/-Users-bko/f7bc7089-83f7-412a-8050-a022085e70d3/scratchpad/peek.png";

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 960 }, deviceScaleFactor: 2 });
const errors = [];
page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
page.on("pageerror", (e) => errors.push(String(e)));

await page.goto(BASE, { waitUntil: "networkidle" });

// sign in if the form is showing
if (await page.locator('input[type="email"]').count()) {
  await page.fill('input[type="email"]', EMAIL);
  await page.fill('input[type="password"]', PASSWORD);
  await page.click('button[type="submit"]');
  await page.waitForTimeout(2500);
}
await page.waitForTimeout(1200);

console.log("--- page text ---");
console.log((await page.locator("body").innerText()).slice(0, 3000));
if (errors.length) console.log("--- console errors ---\n" + errors.join("\n"));

await page.screenshot({ path: OUT, fullPage: true });
console.log("\nshot →", OUT);
await browser.close();
