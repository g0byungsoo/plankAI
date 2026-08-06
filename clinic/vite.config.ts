import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

// The development project's ref. A build declared for any OTHER
// environment must never point here — that is exactly the silent
// misconfiguration S5 exists to make impossible.
const DEV_REF = "mtecqvykyeueumdynatd";

function buildStamp(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}.${p(d.getHours())}${p(d.getMinutes())}`;
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "VITE_");
  const careEnv = env.VITE_CARE_ENV || "development";
  const url = env.VITE_SUPABASE_URL || "";

  if (careEnv !== "development") {
    if (!env.VITE_SUPABASE_URL || !env.VITE_SUPABASE_ANON_KEY) {
      throw new Error(
        `[jeni care] a '${careEnv}' build needs VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY (see .env.pilot.example).`
      );
    }
    if (url.includes(DEV_REF)) {
      throw new Error(
        `[jeni care] a '${careEnv}' build may not point at the development project (${DEV_REF}).`
      );
    }
    if (!env.VITE_CARE_SUPPORT_EMAIL) {
      throw new Error(
        `[jeni care] a '${careEnv}' build needs VITE_CARE_SUPPORT_EMAIL — the pilot must ship a real support pathway.`
      );
    }
  }

  // The CSP must name exactly the environment's Supabase host.
  const supabaseOrigin = (url || `https://${DEV_REF}.supabase.co`).replace(/\/$/, "");
  const supabaseWs = supabaseOrigin.replace(/^http/, "ws");

  return {
    plugins: [
      react(),
      {
        name: "care-html-env",
        transformIndexHtml(html: string) {
          return html
            .replaceAll("%CARE_SUPABASE_ORIGIN%", supabaseOrigin)
            .replaceAll("%CARE_SUPABASE_WS%", supabaseWs);
        },
      },
    ],
    define: { __CARE_BUILD__: JSON.stringify(buildStamp()) },
    server: { port: 5273 },
    preview: { port: 5273 },
  };
});
