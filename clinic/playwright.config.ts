import { defineConfig } from "@playwright/test";

// Drives the dashboard against the LIVE dev Supabase project. A
// fixture is created per run via the API (see e2e/loop.spec.ts).
export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  fullyParallel: false,
  workers: 1,
  use: { baseURL: "http://localhost:5273", trace: "retain-on-failure" },
  webServer: {
    command: "npm run dev",
    url: "http://localhost:5273",
    reuseExistingServer: true,
    timeout: 30_000,
  },
});
