import { useState } from "react";
import { supabase, reportOps } from "../supabase";
import type { CareEnv } from "../env";
import { Banner, Spinner, Token } from "../kit";

function boundaryLine(env: CareEnv | null): string {
  if (env === "pilot" || env === "production") {
    return "for clinics in the Jeni Care pilot. this records care plans and patient-shared records — it is not an emergency monitoring service, and daily records are reviewed at visits, not in real time.";
  }
  return "development environment — internal and test data only. no real patient care may run here.";
}

export function SignIn({ badge, serverEnv }: { badge: string | null; serverEnv: CareEnv | null }) {
  const [mode, setMode] = useState<"in" | "up" | "reset">("in");
  const [email, setEmail] = useState("");
  const [pw, setPw] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(null); setNotice(null); setBusy(true);
    try {
      if (mode === "in") {
        const { error } = await supabase.auth.signInWithPassword({ email, password: pw });
        if (error) throw error;
      } else if (mode === "up") {
        const { data, error } = await supabase.auth.signUp({ email, password: pw });
        if (error) throw error;
        if (!data.session) setNotice("check your email to confirm, then sign in.");
      } else {
        const { error } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo: window.location.origin,
        });
        if (error) {
          reportOps("auth.reset_failed", { code: error.name });
          throw error;
        }
        setNotice("if that account exists, a reset link is on its way.");
      }
    } catch (e: any) {
      if (mode === "in") reportOps("auth.failed", { code: "sign_in" });
      setErr(e.message ?? "something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="signin">
      <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
        <span className="wordmark"><b>jeni</b> <span style={{ fontWeight: 400 }}>care</span><span className="dot">.</span></span>
        {badge && <Token kind="off">{badge}</Token>}
      </div>
      <p className="lede">
        {mode === "reset"
          ? "enter your email and we'll send a reset link."
          : "the care surface for your clinic. sign in to see the patients who connected to you."}
      </p>
      {err && <Banner kind="err">{err}</Banner>}
      {notice && <Banner kind="info">{notice}</Banner>}
      <form onSubmit={submit}>
        <label className="field">
          <span className="lbl">email</span>
          <input type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        {mode !== "reset" && (
          <label className="field">
            <span className="lbl">password</span>
            <input type="password" autoComplete={mode === "in" ? "current-password" : "new-password"} required minLength={8} value={pw} onChange={(e) => setPw(e.target.value)} />
          </label>
        )}
        <button className="btn" style={{ width: "100%" }} disabled={busy} type="submit">
          {busy ? <Spinner /> : mode === "in" ? "sign in" : mode === "up" ? "create account" : "send reset link"}
        </button>
      </form>
      <p style={{ marginTop: 18, display: "flex", gap: 6, flexWrap: "wrap" }}>
        <button className="btn quiet small" onClick={() => { setMode(mode === "in" ? "up" : "in"); setErr(null); setNotice(null); }}>
          {mode === "in" ? "new here? create your account" : "have an account? sign in"}
        </button>
        {mode === "in" && (
          <button className="btn quiet small" onClick={() => { setMode("reset"); setErr(null); setNotice(null); }}>
            forgot your password?
          </button>
        )}
        {mode === "reset" && (
          <button className="btn quiet small" onClick={() => { setMode("in"); setErr(null); setNotice(null); }}>
            back to sign in
          </button>
        )}
      </p>
      {mode === "up" && (
        <p className="disclaimer">
          an account alone sees nothing — your clinic's owner adds you to the team, and patients choose what to share.
        </p>
      )}
      <p className="disclaimer" style={{ marginTop: 28 }}>
        {boundaryLine(serverEnv)}
      </p>
      <p className="disclaimer" style={{ marginTop: 10, color: "var(--ink-3)" }}>
        jeni care · by jeni health
      </p>
    </div>
  );
}

// Rendered when the user arrives on a password-recovery link.
export function NewPassword({ onDone }: { onDone: () => void }) {
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(null);
    if (pw !== pw2) { setErr("the two passwords don't match."); return; }
    setBusy(true);
    try {
      const { error } = await supabase.auth.updateUser({ password: pw });
      if (error) throw error;
      onDone();
    } catch (e: any) {
      reportOps("auth.reset_failed", { code: "update_password" });
      setErr(e.message ?? "could not set the new password.");
      setBusy(false);
    }
  };

  return (
    <div className="signin">
      <span className="wordmark"><b>jeni</b> <span style={{ fontWeight: 400 }}>care</span><span className="dot">.</span></span>
      <p className="lede">choose a new password.</p>
      {err && <Banner kind="err">{err}</Banner>}
      <form onSubmit={submit}>
        <label className="field">
          <span className="lbl">new password</span>
          <input type="password" autoComplete="new-password" required minLength={8} value={pw} onChange={(e) => setPw(e.target.value)} />
        </label>
        <label className="field">
          <span className="lbl">new password, again</span>
          <input type="password" autoComplete="new-password" required minLength={8} value={pw2} onChange={(e) => setPw2(e.target.value)} />
        </label>
        <button className="btn" style={{ width: "100%" }} disabled={busy} type="submit">
          {busy ? <Spinner /> : "set password"}
        </button>
      </form>
    </div>
  );
}
