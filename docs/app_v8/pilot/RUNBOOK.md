# Jeni Care — pilot operations runbook (2026-07-29)

Everything a competent operator needs to run routine pilot
administration **without reading the source**. Each procedure is a
short recipe. Where an action is manual by design for the first
pilot, that is stated — automating it would add risk or surface area
without reducing founder burden at this scale.

Conventions:
- "operator" = the founder or a designated admin with the pilot
  project's service-role key **in their secrets manager / shell only**.
- "dashboard" = the deployed Jeni Care clinic dashboard.
- Env vars for CLI steps: `CARE_SUPABASE_URL`, `CARE_SUPABASE_ANON_KEY`,
  `CARE_SERVICE_KEY` (see care_env_provision.md).

---

## A. Provisioning & access

**Stand up the environment** → `scripts/care_env_provision.md`.

**Add a clinic (restricted mode):** mint a code, hand it over.
```sql
select public.care_ops_mint_provisioning_code('<clinic name> — pilot');
```

**Add a clinic user:** the clinic *owner* does this in the dashboard
(clinic → add member), choosing role (and, for an owner, whether they
are a clinician). Operators do not add members to a clinic they don't
own; that is the clinic's responsibility.

**Remove / disable a clinic user:** owner → clinic → manage → "remove
access now". Immediate; reversible ("restore access"). The last active
owner cannot remove or demote themselves (server-guarded).

**Change a role or clinical authority:** owner → clinic → manage →
role select (+ the clinician checkbox for owners) → save.

**Lost access / password reset:** the user clicks "forgot your
password?" on sign-in; a reset link arrives at their email and returns
them to a set-new-password screen. If the email is wrong, the owner
removes the stale member and re-adds the correct email.

**Session revocation (compromise):** disable the member (above) to cut
their clinic access instantly. To force global sign-out of an account,
the operator revokes its sessions in the Supabase Auth dashboard.

**Suspend an entire organization** (e.g. pilot paused, dispute):
```sql
update public.organizations set status = 'suspended' where id = '<org>';
```
Every member RPC and read denies immediately; patient rights are
untouched. Restore with `status = 'active'`.

**Cancel a pending patient invitation:** any clinic member → clinic →
invitations → cancel. Accepted invitations are inert (single-use).

---

## B. Patient relationship & consent

**A patient revokes access:** she does this herself in the Jeni app
("your care team" → turn off access, per scope or entirely). Prospective
+ access-only: her records, provenance, audit, and any assigned plan's
clinical status survive; the published packet copy is removed.

**A clinic ends a relationship** (patient left the practice, pilot over
for that patient): clinician/owner → patient → "end this connection".
Same semantics as revocation, clinic-initiated: access off, grants
revoked, packet copy removed, everything else retained. Re-connection
later needs a fresh invitation.

**Correction requests:** the clinician resolves them in the dashboard
(accept-and-update, or dismiss-with-reason). They never mutate a plan
on their own and are not urgent — the app tells the patient so.

---

## C. Audit & security review

**Review disclosures for a patient / org:** the audit trail is
readable in the dashboard patient detail ("recent activity") and, in
full, via SQL (operator):
```sql
select occurred_at, actor_role, action, target_kind
from public.care_audit_events
where org_id = '<org>' order by occurred_at desc limit 200;
```
Rows carry ids/counts only — never names, doses, weights, or notes.

**Accounting of disclosures for a patient** (a 45 CFR 164.528
obligation the clinic may need to satisfy): filter the same table by
`patient_id` and export.

**Weekly security review (recommended cadence):**
1. Scan `care_audit_events` for the week — any denied/unexpected actions?
2. Scan `ops_events` for failure spikes (auth, RPC, load, hydration):
   ```sql
   select kind, count(*) from public.ops_events
   where occurred_at > now() - interval '7 days' group by kind order by 2 desc;
   ```
3. Confirm member roster matches authorized personnel (dashboard clinic).
4. Confirm no `org_creation_mode = open` on the pilot project.
5. Record the review (date + initials) in a running log.

**Failed-authorization spike:** repeated denials or throttle hits for
one caller → check `private.invitation_attempts` and the audit rows for
that actor; suspend the org or disable the member if warranted.

---

## D. Observability

`ops_events` (server-only; no API role reads it) captures client
failure classes with **single-token fields only** — the schema cannot
carry health values. Read it in the Supabase SQL editor:
```sql
select occurred_at, surface, kind, code, rpc, status, build
from public.ops_events order by occurred_at desc limit 100;
```
Server-side RPC errors surface in Supabase's Postgres logs; filter for
`care_` in the log explorer. No third-party error tool is wired (adding
one is a founder/BAA gate — VENDORS.md).

---

## E. Backups & restore

- Supabase provides automated backups; a real-data pilot enables PITR
  (Point-in-Time Recovery) as part of the High Compliance config.
- **Test the restore once before go-live** (contingency-plan
  requirement): restore to a scratch project, confirm the schema +
  a sample tenant come back intact, then discard the scratch project.
- The demo tenant is reproducible from `scripts/care_demo.py seed`, so
  it needs no backup.

---

## F. Secret rotation

- Publishable (anon) keys are safe in clients; rotate only if a policy
  change requires it (RLS is the boundary, not the key).
- The **service-role key** is the sensitive secret. Rotate it in the
  Supabase dashboard if it may have been exposed; it lives only in the
  operator's secrets manager and shell — never in the repo, CI, or any
  client bundle. `git` history has been checked to contain no
  service-role key.
- The invitation-code **pepper** lives only in `private.config`
  (generated in-DB, never in the repo); rotating it invalidates
  outstanding invitation codes (acceptable — reissue).

---

## G. Data-subject requests

**Export a patient's data** (patient or clinic request): the patient's
own rows are hers under RLS; an operator can assemble an export via SQL
scoped to her `user_id` across `observations`, `weight_logs`,
`regimen_plans`, `visit_packets`, `correction_requests`, and her
`care_audit_events`. RETENTION.md defines what is returned vs retained.

**Delete an account:** account deletion cascades user-owned rows via FK
`on delete cascade`; audit rows deliberately survive as pseudonymous
(a bare uuid after deletion) for the disclosure record. RETENTION.md is
the policy; deletion of medically-relevant history that a clinic may
be obligated to keep is a founder/counsel decision, not a one-click op.

---

## H. Incident & breach intake

1. **Intake:** anyone (clinic, patient, staff) reports a concern to the
   support/security address (dashboard help sheet + site). Log it with
   a timestamp.
2. **Assess:** what data, whose, which environment, still exposed? Use
   the audit trail. Contain first (suspend org / disable member /
   rotate service key as needed).
3. **Notify:** if patient data was involved, notify the affected
   clinic without unreasonable delay and within the contractual window
   (≤ 60 calendar days from discovery is the 45 CFR 164.410 floor; the
   agreement may set a shorter clock — target faster).
4. **Record:** what happened, when discovered, what data, remediation.
5. **Counsel:** a real breach of real PHI triggers counsel and the
   HIPAA breach-notification process. This runbook is intake +
   containment, not a substitute for that process.

Note: for the **consumer side today**, the FTC Health Breach
Notification Rule already applies — the same "no health data to
ads/analytics" covenant and this intake path cover it.

---

## I. Demo tenant

Reset before every founder demo:
```
python3 scripts/care_demo.py reset      # returns the fictional tenant to a known state
python3 scripts/care_demo.py status     # confirm
```
The demo tooling refuses any org not flagged `is_demo` — it cannot
touch a pilot or consumer tenant.

---

## J. Product evidence (screenshots for the site / decks)

Regenerate from real interfaces + fictional data, leak-checked:
```
# 1. disposable local stack with the full schema (see below)
# 2. dashboard dev server against it
# 3. capture:
CAPTURE=1 CARE_SUPABASE_URL=<local> CARE_SUPABASE_ANON_KEY=<local anon> \
  npx playwright test capture     # writes site/assets/shots/*.png, leak-checked
```
Never capture against a pilot/production environment.
