#!/usr/bin/env python3
"""
S4 clinic-loop security probe — docs/app_v8/10_S4_CLINIC_LOOP.md §12.

Runs the §20 security matrix against the LIVE dev Supabase project as
real principals (publishable key only — the same surface the apps
use). Creates throwaway probe accounts/orgs each run; asserts
denials and grants; prints a PASS/FAIL matrix; exits non-zero on any
failure. Repeatable evidence, not a one-off.

Usage:  python3 scripts/s4_security_probe.py [--skip-expiry]
        (--skip-expiry skips the ~5-minute invitation-expiry wait)
"""

import json
import secrets
import sys
import time
import urllib.request
import urllib.error

BASE = "https://mtecqvykyeueumdynatd.supabase.co"
ANON_KEY = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu"

RESULTS = []


def check(name, ok, detail=""):
    RESULTS.append((name, ok, detail))
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  — {detail}" if detail and not ok else ""))


def req(method, path, token=None, body=None, prefer=None):
    url = BASE + path
    headers = {"apikey": ANON_KEY, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw}


def rpc(token, fn, params):
    return req("POST", f"/rest/v1/rpc/{fn}", token, params)


def signup_anon():
    status, body = req("POST", "/auth/v1/signup", body={})
    assert status == 200, f"anon signup failed: {body}"
    return body["user"]["id"], body["access_token"]


def signup_email(tag):
    email = f"s4probe-{tag}-{secrets.token_hex(4)}@example.com"
    pw = "Aa1" + secrets.token_hex(12)  # meets the project's character-class policy
    status, body = req("POST", "/auth/v1/signup", body={"email": email, "password": pw})
    assert status == 200, f"email signup failed: {body}"
    return email, body["user"]["id"], body["access_token"]


def err_msg(body):
    return (body or {}).get("message", "")


def main():
    skip_expiry = "--skip-expiry" in sys.argv
    t0 = time.time()

    print("== fixtures ==")
    owner_email, owner_id, owner = signup_email("owner")
    clin_email, clin_id, clin = signup_email("clin")
    staff_email, staff_id, staff = signup_email("staff")
    rival_email, rival_id, rival = signup_email("rival")
    patient_id, patient = signup_anon()
    stranger_id, stranger = signup_anon()
    throttle_id, throttle = signup_anon()
    print(f"  owner={owner_id[:8]} clinician={clin_id[:8]} staff={staff_id[:8]}")
    print(f"  rival={rival_id[:8]} patient={patient_id[:8]} stranger={stranger_id[:8]}")

    # ---- org creation ----
    print("== org + membership ==")
    s, b = rpc(patient, "care_create_org", {"p_name": "anon probe org"})
    check("anonymous user cannot create an org", s != 200 and "email" in err_msg(b))

    s, b = rpc(owner, "care_create_org", {"p_name": "probe weight care"})
    check("email account creates org", s == 200 and b.get("org_id"), str(b))
    org = b["org_id"]

    s, b = rpc(rival, "care_create_org", {"p_name": "rival clinic"})
    check("second org created", s == 200, str(b))
    org2 = b["org_id"]

    s, b = rpc(owner, "care_add_member",
               {"p_org": org, "p_email": clin_email, "p_role": "clinician",
                "p_display_name": "Probe Clinician", "p_credential": "NP"})
    check("owner adds clinician", s == 204 or s == 200, str(b))
    s, b = rpc(owner, "care_add_member",
               {"p_org": org, "p_email": staff_email, "p_role": "staff",
                "p_display_name": "Probe Staff"})
    check("owner adds staff", s == 204 or s == 200, str(b))
    s, b = rpc(clin, "care_add_member",
               {"p_org": org, "p_email": rival_email, "p_role": "clinician"})
    check("non-owner cannot add members", s != 200 and "owner" in err_msg(b))

    s, b = req("GET", "/rest/v1/organizations?select=id,name", stranger)
    check("stranger sees no orgs", s == 200 and b == [], str(b))

    # ---- invitations ----
    print("== invitation lifecycle ==")
    exp_code = None
    if not skip_expiry:
        s, b = rpc(staff, "care_create_invitation",
                   {"p_org": org, "p_label": "expiry probe", "p_expires_minutes": 5})
        check("staff can create invitation (clerical)", s == 200 and b.get("code"), str(b))
        exp_code = b["code"]
        exp_created = time.time()

    s, b = rpc(staff, "care_create_invitation", {"p_org": org, "p_label": "K. Probe"})
    check("invitation created with label", s == 200 and b.get("code"), str(b))
    code = b["code"]

    s, b = rpc(rival, "care_create_invitation", {"p_org": org, "p_label": "x"})
    check("non-member cannot invite for org", s != 200)

    s, b = rpc(patient, "care_preview_invitation", {"p_code": code})
    check("preview shows clinic identity pre-grant",
          s == 200 and b.get("ok") and b.get("org_name") == "probe weight care", str(b))

    s, b = rpc(patient, "care_accept_invitation",
               {"p_code": code, "p_lookback_days": 28, "p_scopes": ["everything"]})
    check("unknown scope rejected", s != 200)
    s, b = rpc(patient, "care_accept_invitation",
               {"p_code": code, "p_lookback_days": 7,
                "p_scopes": ["visit_packet_view"]})
    check("invalid lookback rejected", s != 200)

    s, b = rpc(patient, "care_accept_invitation",
               {"p_code": code, "p_lookback_days": 28,
                "p_scopes": ["visit_packet_view", "observation_view", "care_assignment"]})
    check("accept succeeds with 3 scopes + 28d lookback",
          s == 200 and b.get("ok") and b.get("org_id") == org, str(b))

    s, b = rpc(stranger, "care_accept_invitation",
               {"p_code": code, "p_lookback_days": 28,
                "p_scopes": ["visit_packet_view"]})
    check("replayed code fails for another user (soft, generic)",
          s == 200 and b.get("ok") is False and b.get("reason") == "invalid", str(b))

    s, b = rpc(staff, "care_create_invitation", {"p_org": org, "p_label": "cancel probe"})
    cancel_code, cancel_id = b["code"], b["id"]
    rpc(staff, "care_cancel_invitation", {"p_id": cancel_id})
    s, b = rpc(stranger, "care_preview_invitation", {"p_code": cancel_code})
    check("cancelled code fails (soft, generic)",
          s == 200 and b.get("ok") is False, str(b))

    for i in range(5):
        rpc(throttle, "care_preview_invitation", {"p_code": f"XXXX-{i:04d}"})
    s, b = rpc(throttle, "care_preview_invitation", {"p_code": code})
    check("attempt throttle after 5 failures (even with a valid code)",
          s != 200 and "too many" in err_msg(b), f"status={s} {err_msg(b)}")

    # ---- relationship + isolation ----
    print("== isolation ==")
    s, b = req("GET", "/rest/v1/care_relationships?select=org_id,status", patient)
    check("patient sees her relationship", s == 200 and len(b) == 1 and b[0]["status"] == "active")
    s, b = req("GET", "/rest/v1/care_relationships?select=*", stranger)
    check("stranger sees no relationships", s == 200 and b == [])
    s, b = rpc(rival, "care_list_patients", {"p_org": org})
    check("wrong-org clinician cannot list roster", s != 200 and "member" in err_msg(b))
    s, b = rpc(rival, "care_open_patient_chart", {"p_org": org, "p_patient": patient_id})
    check("wrong-org clinician cannot open chart", s != 200)
    s, b = rpc(rival, "care_open_patient_chart", {"p_org": org2, "p_patient": patient_id})
    check("guessed patient id in own org fails (no relationship)",
          s != 200 and "relationship" in err_msg(b))
    s, b = rpc(clin, "care_open_patient_chart",
               {"p_org": org, "p_patient": "00000000-0000-0000-0000-000000000001"})
    check("nonexistent patient id fails", s != 200)

    # ---- F1 masking ----
    print("== F1: self medication name never leaks ==")
    self_plan_id = f"probe-self-{secrets.token_hex(4)}"
    s, b = req("POST", "/rest/v1/regimen_plans", patient,
               body={"id": self_plan_id, "user_id": patient_id, "kind": "medication",
                     "display_name": "ZepSecretName", "schedule_rule": "weeklyAnchor",
                     "anchor_weekday": 3, "authority": "self", "started_at": "2026-07-01T00:00:00Z"},
               prefer="return=representation")
    check("patient records self regimen", s == 201, str(b))
    s, b = rpc(clin, "care_open_patient_chart", {"p_org": org, "p_patient": patient_id})
    chart = json.dumps(b) if s == 200 else ""
    check("chart opens for correct clinician", s == 200, str(b))
    check("self med name absent from chart", "ZepSecretName" not in chart)
    check("self schedule fact present (masked projection)",
          s == 200 and (b.get("self_regimen") or {}).get("anchor_weekday") == 3, str(b.get("self_regimen")))

    # ---- forgeries ----
    print("== forgeries ==")
    s, b = req("POST", "/rest/v1/regimen_plans", patient,
               body={"id": f"forge-{secrets.token_hex(4)}", "user_id": patient_id,
                     "kind": "medication", "display_name": "forged", "schedule_rule": "weeklyAnchor",
                     "authority": "care_team", "org_id": org})
    check("patient cannot forge care_team regimen", s in (401, 403), str(b))
    s, b = req("POST", "/rest/v1/consent_grants", patient,
               body={"id": f"forge-consent-{secrets.token_hex(4)}", "user_id": patient_id,
                     "scope": "care_assignment", "purpose": "forged", "org_id": org2})
    check("patient cannot direct-insert org-scoped consent", s in (401, 403), str(b))
    s, b = req("POST", "/rest/v1/care_audit_events", clin,
               body={"org_id": org, "actor_id": clin_id, "actor_role": "clinician",
                     "action": "forged", "outcome": "success"})
    check("audit table rejects API writes", s in (401, 403, 404, 405), str(b))
    s, b = req("PATCH", f"/rest/v1/care_audit_events?org_id=eq.{org}", clin,
               body={"outcome": "tampered"})
    check("audit table rejects API updates", s in (401, 403, 404, 405), str(b))

    # ---- scopes: packet / series / assignment ----
    print("== scope enforcement ==")
    s, b = rpc(clin, "care_get_visit_packet", {"p_org": org, "p_patient": patient_id})
    check("packet read with scope succeeds (empty ok)", s == 200, str(b))
    s, b = rpc(staff, "care_get_visit_packet", {"p_org": org, "p_patient": patient_id})
    check("staff may read packet (delegable)", s == 200, str(b))
    s, b = rpc(clin, "care_get_patient_series", {"p_org": org, "p_patient": patient_id})
    check("series read with scope succeeds", s == 200 and "observations" in (b or {}), str(b))

    s, b = rpc(staff, "care_assign_regimen",
               {"p_org": org, "p_patient": patient_id, "p_name": "probe med",
                "p_strength_mg": 2.5, "p_anchor_weekday": 3, "p_started_on": "2026-07-29"})
    check("staff cannot assign regimen", s != 200 and "clinician" in err_msg(b))

    s, b = rpc(clin, "care_assign_regimen",
               {"p_org": org, "p_patient": patient_id, "p_name": "probe med",
                "p_strength_mg": 500, "p_anchor_weekday": 3, "p_started_on": "2026-07-29"})
    check("mg bound enforced (500mg rejected)", s != 200 and "mg" in err_msg(b))

    s, b = rpc(clin, "care_assign_regimen",
               {"p_org": org, "p_patient": patient_id, "p_name": "probe med",
                "p_strength_mg": 2.5, "p_anchor_weekday": 5, "p_started_on": "2026-07-29",
                "p_instruction": "evening, thigh or abdomen ok"})
    check("clinician assigns care-team regimen", s == 200 and b, str(b))
    ct_plan_id = b if isinstance(b, str) else None

    s, b = req("GET", f"/rest/v1/regimen_plans?select=id,authority,display_name&authority=eq.care_team", patient)
    check("patient reads her assigned care-team plan",
          s == 200 and len(b) == 1 and b[0]["display_name"] == "probe med", str(b))

    s, b = req("PATCH", f"/rest/v1/regimen_plans?id=eq.{ct_plan_id}", patient,
               body={"display_name": "tampered"}, prefer="return=representation")
    tampered = s == 200 and b and b[0].get("display_name") == "tampered"
    s2, b2 = req("GET", f"/rest/v1/regimen_plans?select=display_name&id=eq.{ct_plan_id}", patient)
    check("patient cannot mutate care-team plan (server-side)",
          not tampered and s2 == 200 and b2[0]["display_name"] == "probe med", f"{b} / {b2}")

    # protocol tenancy
    s, b = rpc(clin, "care_create_org_protocol",
               {"p_org": org, "p_title": "probe protocol",
                "p_supports": [{"kind": "fiber", "note": "gradual fiber for regularity"}]})
    check("clinician authors bounded org protocol", s == 200, str(b))
    org_proto = b if isinstance(b, str) else None
    s, b = req("GET", f"/rest/v1/protocols?select=id&id=eq.{org_proto}", stranger)
    check("stranger cannot see org protocol", s == 200 and b == [], str(b))
    s, b = rpc(rival, "care_assign_protocol",
               {"p_org": org2, "p_patient": patient_id, "p_protocol_id": org_proto})
    check("rival org cannot assign another org's protocol", s != 200)
    s, b = rpc(clin, "care_assign_protocol",
               {"p_org": org, "p_patient": patient_id, "p_protocol_id": org_proto})
    check("clinician assigns org protocol", s in (200, 204), str(b))
    s, b = req("GET", f"/rest/v1/protocols?select=id&id=eq.{org_proto}", patient)
    check("assigned patient can now read the org protocol row",
          s == 200 and len(b) == 1, str(b))

    # ---- corrections ----
    print("== corrections ==")
    s, b = rpc(patient, "care_submit_correction",
               {"p_org": org, "p_regimen_plan_id": ct_plan_id,
                "p_category": "strength", "p_note": "I take 5 mg, not 2.5"})
    check("patient submits correction", s == 200 and b, str(b))
    corr_id = b
    s, b = rpc(stranger, "care_submit_correction",
               {"p_org": org, "p_regimen_plan_id": ct_plan_id,
                "p_category": "strength"})
    check("stranger cannot submit correction", s != 200)
    s, b = rpc(staff, "care_resolve_correction",
               {"p_org": org, "p_correction_id": corr_id, "p_note": "checked"})
    check("staff cannot resolve corrections", s != 200 and "clinician" in err_msg(b))
    s, b = rpc(clin, "care_update_regimen",
               {"p_org": org, "p_regimen_id": ct_plan_id, "p_strength_mg": 5,
                "p_correction_id": corr_id})
    check("clinician accepts correction via regimen update", s in (200, 204), str(b))
    s, b = req("GET", f"/rest/v1/correction_requests?select=status&id=eq.{corr_id}", patient)
    check("patient sees correction accepted", s == 200 and b[0]["status"] == "accepted", str(b))

    # ---- disabled member ----
    print("== disabled member ==")
    s, b = rpc(owner, "care_set_member_status",
               {"p_org": org, "p_user": clin_id, "p_status": "disabled"})
    check("owner disables clinician", s in (200, 204), str(b))
    s, b = rpc(clin, "care_list_patients", {"p_org": org})
    check("disabled clinician denied immediately", s != 200 and "member" in err_msg(b))
    rpc(owner, "care_set_member_status", {"p_org": org, "p_user": clin_id, "p_status": "active"})

    # ---- packet publish + revocation ----
    print("== revocation ==")
    s, b = req("POST", "/rest/v1/visit_packets", patient,
               body={"id": f"{patient_id}-{org}", "user_id": patient_id, "org_id": org,
                     "payload": {"probe": True, "questions": []},
                     "window_start": "2026-07-02", "window_end": "2026-07-29"},
               prefer="resolution=merge-duplicates")
    check("patient publishes packet under scope", s in (200, 201, 204), str(b))
    s, b = req("POST", "/rest/v1/visit_packets", stranger,
               body={"id": f"{stranger_id}-{org}", "user_id": stranger_id, "org_id": org,
                     "payload": {"forged": True}})
    check("unrelated patient cannot publish to org", s in (401, 403), str(b))

    s, b = rpc(patient, "care_revoke_consent", {"p_org": org})
    check("patient revokes all scopes", s in (200, 204), str(b))
    s, b = rpc(clin, "care_get_visit_packet", {"p_org": org, "p_patient": patient_id})
    check("packet denied after revocation", s != 200 and "access" in err_msg(b), err_msg(b))
    s, b = rpc(clin, "care_get_patient_series", {"p_org": org, "p_patient": patient_id})
    check("series denied after revocation", s != 200)
    s, b = rpc(clin, "care_update_regimen",
               {"p_org": org, "p_regimen_id": ct_plan_id, "p_strength_mg": 7.5})
    check("assignment writes denied after revocation", s != 200)
    s, b = req("GET", "/rest/v1/visit_packets?select=id", patient)
    check("published packet removed on revocation", s == 200 and b == [], str(b))
    s, b = req("GET", f"/rest/v1/regimen_plans?select=display_name,authority&id=eq.{ct_plan_id}", patient)
    check("care-team plan survives revocation (access ≠ treatment)",
          s == 200 and len(b) == 1 and b[0]["authority"] == "care_team", str(b))

    # ---- audit ----
    print("== audit ==")
    s, b = req("GET", "/rest/v1/care_audit_events?select=action&order=id.asc", patient)
    actions = [row["action"] for row in (b or [])]
    need = ["invitation.accepted", "relationship.activated", "consent.granted",
            "chart.opened", "regimen.assigned", "correction.requested",
            "correction.resolved", "consent.revoked"]
    missing = [a for a in need if a not in actions]
    check("audit chain complete for the loop", s == 200 and not missing,
          f"missing: {missing}")
    s, b = req("GET", "/rest/v1/care_audit_events?select=meta", patient)
    meta_blob = json.dumps(b)
    check("audit meta carries no names/values",
          "probe med" not in meta_blob and "ZepSecretName" not in meta_blob
          and "5 mg" not in meta_blob)
    # Rival legitimately sees its OWN org's events (e.g. org.created
    # for org2). The invariant is that NONE of them concern this
    # patient / org1.
    s, b = req("GET", f"/rest/v1/care_audit_events?select=action,patient_id&or=(patient_id.eq.{patient_id},org_id.eq.{org})", rival)
    check("rival sees no audit about this patient or org1", s == 200 and b == [], str(b))

    # ---- expiry (needs ≥5 min elapsed) ----
    if not skip_expiry and exp_code:
        elapsed = time.time() - exp_created
        wait = max(0, 5 * 60 - elapsed) + 5
        if wait > 0:
            print(f"== waiting {int(wait)}s for invitation expiry ==")
            time.sleep(wait)
        s, b = rpc(stranger, "care_preview_invitation", {"p_code": exp_code})
        check("expired code fails (generic)", s != 200 and "didn't work" in err_msg(b), err_msg(b))

    # ---- summary ----
    failed = [r for r in RESULTS if not r[1]]
    print(f"\n== {len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed"
          f" in {int(time.time() - t0)}s ==")
    if failed:
        for name, _, detail in failed:
            print(f"  FAILED: {name} — {detail}")
        sys.exit(1)


if __name__ == "__main__":
    main()
