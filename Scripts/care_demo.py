#!/usr/bin/env python3
"""
Jeni Care demo tenant — seed / reset / status.
docs/app_v8/11_S5_PILOT_READY.md §10 is the law.

A safe, repeatable founder-demo fixture: one FICTIONAL clinic
("Sage Metabolic Health — Demo"), one fictional clinician account,
one fictional patient with a plausible (fictional) visit packet.
Everything a demo needs, nothing a demo can leak.

Design rules:
  * Data flows use the REAL product mechanics under the publishable
    key (invitation → accept → consent → publish), signed in as the
    demo accounts — the demo exercises the same server law as
    production, so it can never demonstrate something that isn't
    true.
  * The service key is used ONLY to: create/find the stable demo
    accounts (admin API), mark the org is_demo, mint a provisioning
    code when org creation is restricted, and clear a DEMO org's
    protocol assignments on reset.
  * Every mutating step re-verifies the org carries is_demo=true and
    the demo name prefix; the script refuses anything else, so it
    cannot touch a pilot or consumer tenant.
  * No public endpoint exists: this is an operator-local CLI. The
    service key is never written to disk by this script.

Environment (all required; no baked-in defaults for safety):
  CARE_SUPABASE_URL        e.g. https://<ref>.supabase.co (or local)
  CARE_SUPABASE_ANON_KEY   the environment's publishable key
  CARE_SERVICE_KEY         the environment's service-role key
  CARE_DEMO_PASSWORD       stable password for the two demo accounts

Usage:
  python3 scripts/care_demo.py status
  python3 scripts/care_demo.py seed
  python3 scripts/care_demo.py reset
"""

import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request

DEMO_ORG_NAME = "Sage Metabolic Health — Demo"
DEMO_CLINICIAN_EMAIL = "demo.clinician@jenihealth.invalid"
DEMO_PATIENT_EMAIL = "demo.patient@jenihealth.invalid"
DEMO_PATIENT_LABEL = "Jordan D. (demo)"

BASE = os.environ.get("CARE_SUPABASE_URL", "").rstrip("/")
ANON = os.environ.get("CARE_SUPABASE_ANON_KEY", "")
SERVICE = os.environ.get("CARE_SERVICE_KEY", "")
PASSWORD = os.environ.get("CARE_DEMO_PASSWORD", "")


def die(msg):
    print(f"refusing: {msg}")
    sys.exit(1)


def req(method, path, token, body=None, key=None, prefer=None):
    headers = {"apikey": key or ANON, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
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


def svc(method, path, body=None, prefer=None):
    return req(method, path, SERVICE, body, key=SERVICE, prefer=prefer)


def rpc(token, fn, params):
    return req("POST", f"/rest/v1/rpc/{fn}", token, params)


def sign_in(email):
    s, b = req("POST", "/auth/v1/token?grant_type=password", None,
               {"email": email, "password": PASSWORD})
    if s != 200:
        return None, None
    return b["user"]["id"], b["access_token"]


def ensure_account(email):
    """Find or create a stable demo account via the admin API."""
    uid, token = sign_in(email)
    if token:
        return uid, token
    s, b = svc("POST", "/auth/v1/admin/users",
               {"email": email, "password": PASSWORD, "email_confirm": True})
    if s not in (200, 201):
        die(f"could not create {email}: {b}")
    uid, token = sign_in(email)
    if not token:
        die(f"created {email} but cannot sign in — check CARE_DEMO_PASSWORD")
    return uid, token


def demo_org(clin_token):
    """The clinician's demo org, verified demo-flagged. None if absent."""
    s, b = req("GET", "/rest/v1/organizations?select=id,name,is_demo,status", clin_token)
    if s != 200:
        die(f"cannot list orgs: {b}")
    for row in b or []:
        if row["name"] == DEMO_ORG_NAME:
            if not row.get("is_demo"):
                die(f"org '{DEMO_ORG_NAME}' exists but is not flagged is_demo — will not touch it")
            return row
    return None


def guard_demo_org(org_id):
    """Re-verify by id before ANY service-role mutation."""
    s, b = svc("GET", f"/rest/v1/organizations?id=eq.{org_id}&select=id,name,is_demo")
    if s != 200 or not b or not b[0].get("is_demo") or "Demo" not in b[0]["name"]:
        die(f"org {org_id} is not a verified demo tenant")


def demo_packet_payload(today):
    """Deterministic, PLAUSIBLE, FICTIONAL 28-day packet."""
    start = today - dt.timedelta(days=27)
    label = f"{start.strftime('%b %-d')} – {today.strftime('%b %-d')}".lower()
    return {
        "window": {"label": label},
        "regimen": {
            "displayLine": "your weekly medication",
            "authorityLabel": "self-reported",
            "anchorWeekdayWord": "wednesday",
            "scheduledCount": 4, "takenCount": 3,
            "skippedCount": 0, "unrecordedCount": 1,
        },
        "weight": {"entryCount": 5, "firstKg": 96.4, "latestKg": 94.8,
                   "directionWord": "easing"},
        "symptoms": [
            {"word": "queasy", "count": 2,
             "timingNote": "both within 2 days of a marked dose"},
            {"word": "fine", "count": 9, "timingNote": None},
        ],
        "nutrition": {"loggedDays": 16, "proteinDaysMet": 9, "targetG": 90},
        "movement": {"movedDays": 11, "stepsWeekAvg": 6214},
        "questions": [
            {"id": "demo-q1", "text": "you may want to mention how the weekly rhythm is fitting.",
             "origin": "generated"},
            {"id": "demo-q2", "text": "does the queasy day after my shot ever settle down?",
             "origin": "her"},
        ],
        "gaps": ["sleep wasn't recorded this period."],
        "displayUnit": "lb",
    }


def publish_packet(pat_id, pat_token, org_id):
    today = dt.date.today()
    body = {
        "id": f"{pat_id}-{org_id}", "user_id": pat_id, "org_id": org_id,
        "payload": demo_packet_payload(today),
        "window_start": (today - dt.timedelta(days=27)).isoformat(),
        "window_end": today.isoformat(),
        "app_version": "demo-seed",
    }
    s, b = req("POST", "/rest/v1/visit_packets", pat_token, body,
               prefer="resolution=merge-duplicates")
    if s not in (200, 201, 204):
        die(f"packet publish failed: {b}")


def cmd_status():
    _, clin_token = sign_in(DEMO_CLINICIAN_EMAIL)
    if not clin_token:
        print("demo not seeded (no clinician account).")
        return
    org = demo_org(clin_token)
    if not org:
        print("demo clinician exists; demo org not created yet.")
        return
    s, b = rpc(clin_token, "care_list_patients", {"p_org": org["id"]})
    rows = b if isinstance(b, list) else []
    print(f"demo org: {org['name']} ({org['id']}) · status {org['status']}")
    for r in rows:
        print(f"  patient: {r['label']} · {r['status']} · scopes {','.join(r['scopes'])}"
              f" · open corrections {r['open_corrections']}"
              f" · packet {'yes' if r['packet_generated_at'] else 'no'}")
    if not rows:
        print("  no demo patient connected yet.")


def cmd_seed():
    print(f"target: {BASE}")
    clin_id, clin_token = ensure_account(DEMO_CLINICIAN_EMAIL)
    pat_id, pat_token = ensure_account(DEMO_PATIENT_EMAIL)

    org = demo_org(clin_token)
    if not org:
        # Provisioning code first if this environment is restricted.
        s, env = rpc(None, "care_environment", {})
        code = None
        s, b = rpc(clin_token, "care_create_org",
                   {"p_name": DEMO_ORG_NAME, "p_owner_is_clinician": True,
                    "p_provision_code": None})
        if s != 200 and "invite-only" in json.dumps(b):
            s2, minted = svc("POST", "/rest/v1/rpc/care_ops_mint_provisioning_code",
                             {"p_label": "demo tenant"})
            if s2 != 200:
                die(f"cannot mint provisioning code: {minted}")
            code = minted["code"]
            s, b = rpc(clin_token, "care_create_org",
                       {"p_name": DEMO_ORG_NAME, "p_owner_is_clinician": True,
                        "p_provision_code": code})
        if s != 200:
            die(f"org creation failed: {b}")
        org_id = b["org_id"]
        s, b = svc("PATCH", f"/rest/v1/organizations?id=eq.{org_id}",
                   {"is_demo": True}, prefer="return=representation")
        if s != 200:
            die(f"could not flag demo org: {b}")
        org = {"id": org_id, "name": DEMO_ORG_NAME, "status": "active"}
        print(f"created demo org {org_id}")
    else:
        print(f"demo org exists: {org['id']}")

    # Connect the demo patient through the REAL invitation flow.
    s, b = rpc(clin_token, "care_list_patients", {"p_org": org["id"]})
    connected = any(r["patient_id"] == pat_id and r["status"] == "active"
                    for r in (b if isinstance(b, list) else []))
    if not connected:
        s, b = rpc(clin_token, "care_create_invitation",
                   {"p_org": org["id"], "p_label": DEMO_PATIENT_LABEL})
        if s != 200:
            die(f"invitation failed: {b}")
        s, b = rpc(pat_token, "care_accept_invitation",
                   {"p_code": b["code"], "p_lookback_days": 28,
                    "p_scopes": ["visit_packet_view", "observation_view", "care_assignment"]})
        if s != 200 or not (b or {}).get("ok"):
            die(f"accept failed: {b}")
        print("demo patient connected (3 scopes, 4-week lookback)")

    publish_packet(pat_id, pat_token, org["id"])
    print("demo packet published")
    print("\nseeded. sign in to the dashboard as:")
    print(f"  {DEMO_CLINICIAN_EMAIL}  (password: CARE_DEMO_PASSWORD)")
    print("reset any time with: python3 scripts/care_demo.py reset")


def cmd_reset():
    print(f"target: {BASE}")
    clin_id, clin_token = sign_in(DEMO_CLINICIAN_EMAIL)
    pat_id, pat_token = sign_in(DEMO_PATIENT_EMAIL)
    if not clin_token or not pat_token:
        die("demo accounts missing — run seed first")
    org = demo_org(clin_token)
    if not org:
        die("no demo org — run seed first")
    guard_demo_org(org["id"])

    # End any active care-team regimen through the real mechanic.
    s, b = rpc(clin_token, "care_open_patient_chart",
               {"p_org": org["id"], "p_patient": pat_id})
    if s != 200:
        die(f"cannot open demo chart: {b}")
    for reg in b.get("care_team_regimens", []):
        if not reg.get("ended_at"):
            rpc(clin_token, "care_end_regimen",
                {"p_org": org["id"], "p_regimen_id": reg["id"]})
            print(f"ended demo care-team regimen {reg['id'][:8]}…")
    for corr in b.get("corrections", []):
        if corr["status"] == "open":
            rpc(clin_token, "care_resolve_correction",
                {"p_org": org["id"], "p_correction_id": corr["id"],
                 "p_note": "demo reset — cleared for the next walkthrough."})
            print(f"dismissed open demo correction {corr['id'][:8]}…")

    # Clear demo protocol assignments (service role; demo org verified).
    svc("DELETE", f"/rest/v1/protocol_assignments?org_id=eq.{org['id']}")

    publish_packet(pat_id, pat_token, org["id"])
    print("demo packet re-published fresh")
    print("reset complete — the demo tenant is walkthrough-ready.")


def main():
    if not BASE or not ANON or not SERVICE or not PASSWORD:
        die("set CARE_SUPABASE_URL, CARE_SUPABASE_ANON_KEY, CARE_SERVICE_KEY, CARE_DEMO_PASSWORD")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "seed":
        cmd_seed()
    elif cmd == "reset":
        cmd_reset()
    elif cmd == "status":
        cmd_status()
    else:
        die(f"unknown command '{cmd}' (seed | reset | status)")


if __name__ == "__main__":
    main()
