import { useState } from "react";
import { supabase } from "../supabase";
import { Banner, Spinner } from "../kit";

export function SignIn() {
  const [mode, setMode] = useState<"in" | "up">("in");
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
      } else {
        const { data, error } = await supabase.auth.signUp({ email, password: pw });
        if (error) throw error;
        if (!data.session) setNotice("check your email to confirm, then sign in.");
      }
    } catch (e: any) {
      setErr(e.message ?? "something went wrong.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="signin">
      <span className="wordmark"><b>jenifit</b> <span style={{ fontWeight: 400 }}>care</span><span className="dot">.</span></span>
      <p className="lede">the care surface for your clinic. sign in to see the patients who connected to you.</p>
      {err && <Banner kind="err">{err}</Banner>}
      {notice && <Banner kind="info">{notice}</Banner>}
      <form onSubmit={submit}>
        <label className="field">
          <span className="lbl">email</span>
          <input type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label className="field">
          <span className="lbl">password</span>
          <input type="password" autoComplete={mode === "in" ? "current-password" : "new-password"} required value={pw} onChange={(e) => setPw(e.target.value)} />
        </label>
        <button className="btn" style={{ width: "100%" }} disabled={busy} type="submit">
          {busy ? <Spinner /> : mode === "in" ? "sign in" : "create account"}
        </button>
      </form>
      <p style={{ marginTop: 18 }}>
        <button className="btn quiet small" onClick={() => { setMode(mode === "in" ? "up" : "in"); setErr(null); }}>
          {mode === "in" ? "new here? create a clinic account" : "have an account? sign in"}
        </button>
      </p>
      <p className="disclaimer" style={{ marginTop: 28 }}>
        development alpha — internal and test data only. jenifit is not a HIPAA covered entity and no BAA is in place, so this surface may not be used for real patient care yet.
      </p>
    </div>
  );
}
