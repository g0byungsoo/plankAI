import { Sheet } from "../kit";
import { ENV, SUPPORT_CONTACT, type CareEnv } from "../env";
import type { Membership } from "../supabase";

// One quiet door for orientation, boundaries, and support. Not a
// manual — the product should explain itself; this is the place the
// boundary and the contact live.
export function HelpSheet({ membership, serverEnv, onClose }: {
  membership: Membership; serverEnv: CareEnv | null; onClose: () => void;
}) {
  return (
    <Sheet title="about jeni care" sub={`${membership.org_name} · signed in as ${membership.role}`} onClose={onClose}>
      <div className="help-block">
        <div className="help-h">the loop</div>
        <p>invite a patient with a one-time code → they choose what to share → read their record before a visit → assign the protocol and medication plan → their app carries it into daily care. corrections they raise land back here for your decision.</p>
      </div>
      <div className="help-block">
        <div className="help-h">what jeni care does not do</div>
        <p>it is not an EHR and not e-prescribing — the prescription lives in your EHR and pharmacy. it does not monitor patients in real time, does not alert on their entries, and does not replace clinical judgment. records here are reviewed when you open them, at visits.</p>
      </div>
      <div className="help-block">
        <div className="help-h">urgent concerns</div>
        <p>patient-side urgent concerns go through your clinic's usual channels or emergency services — never through this dashboard or the patient app.</p>
      </div>
      <div className="help-block">
        <div className="help-h">who can do what</div>
        <p>owners manage the team. clinicians review records and assign care. staff invite patients and read records, and never author medication plans. patients decide what is shared and can end access at any time.</p>
      </div>
      <div className="help-block">
        <div className="help-h">support &amp; security</div>
        <p>{SUPPORT_CONTACT} for anything — access, questions, or to report a security or privacy concern. we'd rather hear it twice than not at all.</p>
      </div>
      <p className="disclaimer" style={{ marginTop: 14 }}>
        jeni care · by jeni health · build {ENV.build}
        {serverEnv && serverEnv !== "production" ? ` · ${serverEnv}` : ""}
      </p>
    </Sheet>
  );
}
