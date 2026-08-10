#!/usr/bin/env python3
"""
Seed the Jeni Care demo clinic — deterministic, fictional, local-only.

WHAT THIS IS
  One fictional metabolic clinic (Sage Metabolic Health), one
  clinician, a small roster, and one exceptional patient story. Every
  privileged act runs through the REAL product RPCs as the real
  principal (clinician signs in, patients sign in, invitations are
  previewed and accepted) so the demo can never show something the
  server law does not actually permit.

  The service key is used only for FIXTURE work a demo needs and a
  clinic would never do: minting the stable invitation code, marking
  the org as a demo tenant, and writing the supporting patients'
  synthetic history + packets. The ONE patient who carries the film
  (Maya C.) is deliberately left empty here — she is created by the
  real iOS app, connecting with the real code.

SAFETY
  Refuses to run against anything but 127.0.0.1/localhost. The demo
  stack is a disposable local Supabase; production is never reachable
  from this script.

USAGE
  source scripts/demo/env.sh
  python3 scripts/demo/seed.py            # seed
  python3 scripts/demo/seed.py --status   # report
"""

import datetime as dt
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("CARE_SUPABASE_URL", "http://127.0.0.1:54321").rstrip("/")
ANON = os.environ.get("CARE_SUPABASE_ANON_KEY", "")
SERVICE = os.environ.get("CARE_SERVICE_KEY", "")
DB = os.environ.get("CARE_DB_CONTAINER", "supabase_db_jeni-demo")

CLINIC_NAME = os.environ.get("DEMO_CLINIC_NAME", "Sage Metabolic Health")
CLINIC_CODE = os.environ.get("DEMO_CLINIC_CODE", "JENI-DEMO")
CLINICIAN_EMAIL = os.environ.get("DEMO_CLINICIAN_EMAIL", "a.osei@sagemetabolic.example")
PASSWORD = os.environ.get("DEMO_PASSWORD", "demo-sage-2026")

TODAY = dt.date.today()


# ---------------------------------------------------------------- io

def die(msg):
    print(f"refusing: {msg}", file=sys.stderr)
    sys.exit(1)


def guard():
    if not ("127.0.0.1" in BASE or "localhost" in BASE):
        die(f"CARE_SUPABASE_URL is {BASE!r} — the demo seeder is local-only.")
    if not ANON or not SERVICE:
        die("source scripts/demo/env.sh first (missing keys).")


def req(method, path, token=None, body=None, key=None, prefer=None):
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


def rpc(name, token, body=None, key=None):
    status, out = req("POST", f"/rest/v1/rpc/{name}", token, body or {}, key=key)
    if status >= 300:
        die(f"{name} failed [{status}]: {out}")
    return out


def sql(statement):
    """Fixture-only SQL on the demo database."""
    p = subprocess.run(
        ["docker", "exec", "-i", DB, "psql", "-U", "postgres", "-d", "postgres",
         "-v", "ON_ERROR_STOP=1", "-tAc", statement],
        capture_output=True, text=True,
    )
    if p.returncode != 0:
        die(f"sql failed: {p.stderr.strip()}\n  {statement[:200]}")
    return p.stdout.strip()


def q(text):
    """Quote a python value as a SQL literal."""
    if text is None:
        return "null"
    if isinstance(text, bool):
        return "true" if text else "false"
    if isinstance(text, (int, float)):
        return str(text)
    return "'" + str(text).replace("'", "''") + "'"


# ------------------------------------------------------------ people

def ensure_user(email):
    """Create (or find) a confirmed email account. Returns the uid."""
    status, out = req(
        "POST", "/auth/v1/admin/users", SERVICE,
        {"email": email, "password": PASSWORD, "email_confirm": True},
        key=SERVICE,
    )
    if status < 300 and isinstance(out, dict) and out.get("id"):
        return out["id"]
    existing = sql(f"select id from auth.users where email = {q(email)} limit 1;")
    if existing:
        return existing
    die(f"could not create or find {email}: {out}")


def sign_in(email):
    status, out = req(
        "POST", "/auth/v1/token?grant_type=password", None,
        {"email": email, "password": PASSWORD},
    )
    if status >= 300:
        die(f"sign-in failed for {email} [{status}]: {out}")
    return out["access_token"]


def day(offset_days):
    return TODAY + dt.timedelta(days=offset_days)


def key(offset_days):
    return day(offset_days).isoformat()


# --------------------------------------------------------- the story
#
# One clinic, seven patients. Six are fixtures that make the clinic
# feel like a real Tuesday morning; one (Maya C.) is left for the iOS
# app to fill by connecting with the code. Most of the roster is
# deliberately QUIET — the queue earns its shortness.

SUPPORTING = [
    # label, email, weeks connected, packet, extras
    {
        "label": "Rosa D.",
        "email": "rosa.d@demo.invalid",
        "connected_weeks": 14,
        "med": ("Wegovy", 1.7, 2, 84, "evening. thigh or abdomen is fine."),
        "weights": (94.2, 88.6, 12),
        "packet": {
            "regimen": {"displayLine": "Wegovy 1.7 mg", "authorityLabel": "assigned by your care team",
                        "anchorWeekdayWord": "tuesday", "scheduledCount": 4, "takenCount": 4,
                        "skippedCount": 0, "unrecordedCount": 0},
            "weight": {"entryCount": 9, "firstKg": 89.8, "latestKg": 88.6, "directionWord": "easing"},
            "symptoms": [],
            "nutrition": {"loggedDays": 24, "proteinDaysMet": 19, "targetG": 105},
            "movement": {"movedDays": 22, "stepsWeekAvg": 8100},
            "questions": [],
            "gaps": ["no sit-check answers this period."],
        },
    },
    {
        "label": "Tom W.",
        "email": "tom.w@demo.invalid",
        "connected_weeks": 9,
        "med": ("Mounjaro", 5.0, 4, 56, "evening, with or without food."),
        "weights": (108.4, 101.9, 9),
        "packet": {
            "regimen": {"displayLine": "Mounjaro 5 mg", "authorityLabel": "assigned by your care team",
                        "anchorWeekdayWord": "thursday", "scheduledCount": 4, "takenCount": 4,
                        "skippedCount": 0, "unrecordedCount": 0},
            "weight": {"entryCount": 12, "firstKg": 103.5, "latestKg": 101.9, "directionWord": "easing"},
            "symptoms": [{"word": "heavy", "count": 1, "timingNote": None}],
            "nutrition": {"loggedDays": 21, "proteinDaysMet": 17, "targetG": 120},
            "movement": {"movedDays": 19, "stepsWeekAvg": 9400},
            "questions": [],
            "gaps": [],
        },
    },
    {
        "label": "Priya S.",
        "email": "priya.s@demo.invalid",
        "connected_weeks": 6,
        "med": ("Wegovy", 1.0, 1, 35, "evening. thigh or abdomen is fine."),
        "weights": (86.1, 83.4, 8),
        # files a correction: the strength on her plan does not match
        # what her pharmacy dispensed. The clinic wants to know.
        "correction": ("strength", None),
        "packet": {
            "regimen": {"displayLine": "Wegovy 1 mg", "authorityLabel": "assigned by your care team",
                        "anchorWeekdayWord": "monday", "scheduledCount": 4, "takenCount": 3,
                        "skippedCount": 0, "unrecordedCount": 1},
            "weight": {"entryCount": 7, "firstKg": 84.2, "latestKg": 83.4, "directionWord": "easing"},
            "symptoms": [],
            "nutrition": {"loggedDays": 16, "proteinDaysMet": 11, "targetG": 100},
            "movement": {"movedDays": 15, "stepsWeekAvg": 6600},
            "questions": [],
            "gaps": ["1 scheduled dose day went unrecorded. unrecorded is not skipped."],
        },
    },
    {
        "label": "Dana K.",
        "email": "dana.k@demo.invalid",
        "connected_weeks": 11,
        "med": ("Zepbound", 7.5, 6, 70, "evening, any site."),
        "weights": (99.0, 92.8, 10),
        "follow_up_offset": -2,       # review date was two days ago
        "packet": {
            "regimen": {"displayLine": "Zepbound 7.5 mg", "authorityLabel": "assigned by your care team",
                        "anchorWeekdayWord": "saturday", "scheduledCount": 4, "takenCount": 4,
                        "skippedCount": 0, "unrecordedCount": 0},
            "weight": {"entryCount": 11, "firstKg": 94.1, "latestKg": 92.8, "directionWord": "easing"},
            "symptoms": [{"word": "backed up", "count": 2, "timingNote": None}],
            "nutrition": {"loggedDays": 20, "proteinDaysMet": 16, "targetG": 110},
            "movement": {"movedDays": 18, "stepsWeekAvg": 7300},
            "questions": [],
            "gaps": [],
        },
    },
    {
        "label": "Nadia F.",
        "email": "nadia.f@demo.invalid",
        "connected_weeks": 8,
        "med": ("Wegovy", 0.5, 3, 49, "evening. thigh or abdomen is fine."),
        "weights": (91.5, 88.2, 8),
        "reviewed_hours_ago": 3,      # read AFTER her record last changed
        "packet": {
            "regimen": {"displayLine": "Wegovy 0.5 mg", "authorityLabel": "assigned by your care team",
                        "anchorWeekdayWord": "wednesday", "scheduledCount": 4, "takenCount": 2,
                        "skippedCount": 1, "unrecordedCount": 1},
            "weight": {"entryCount": 6, "firstKg": 89.0, "latestKg": 88.2, "directionWord": "easing"},
            "symptoms": [{"word": "queasy", "count": 2, "timingNote": None}],
            "nutrition": {"loggedDays": 14, "proteinDaysMet": 8, "targetG": 100},
            "movement": {"movedDays": 12, "stepsWeekAvg": 5900},
            "questions": [
                {"id": "nadia-visitq-rhythm", "origin": "generated",
                 "text": "you may want to mention how the weekly rhythm is fitting."},
            ],
            "gaps": ["1 scheduled dose day went unrecorded. unrecorded is not skipped."],
        },
    },
    {
        "label": "Ellis B.",
        "email": "ellis.b@demo.invalid",
        "connected_weeks": 1,
        "med": None,                  # just connected; nothing assigned yet
        "weights": None,
        "packet": None,               # nothing published yet — honestly empty
    },
]

# The clinician's written care instructions — the protocol the clinic
# actually authors. These cross the boundary into Jeni (the supports
# line on Today).
PROTOCOL_TITLE = "Sage GLP-1 titration — standard"
PROTOCOL_SUPPORTS = [
    {"kind": "protein",
     "note": "protein first at every meal, especially in the days after a dose."},
    {"kind": "hydration",
     "note": "keep fluids up through the titration weeks."},
    {"kind": "steps",
     "note": "a short walk after dinner — it settles the stomach and protects muscle."},
]


# ------------------------------------------------------------- seed

def seed():
    guard()
    print(f"seeding the demo clinic against {BASE}")

    # -- the clinic ------------------------------------------------
    clinician_id = ensure_user(CLINICIAN_EMAIL)
    token = sign_in(CLINICIAN_EMAIL)

    existing = sql(f"select id from public.organizations where name = {q(CLINIC_NAME)} limit 1;")
    if existing:
        org = existing
        print(f"  clinic exists · {CLINIC_NAME}")
    else:
        out = rpc("care_create_org", token,
                  {"p_name": CLINIC_NAME, "p_owner_is_clinician": True})
        org = out["org_id"]
        print(f"  clinic created · {CLINIC_NAME}")

    sql(f"update public.organizations set is_demo = true where id = {q(org)}::uuid;")
    sql("update public.org_members set display_name = 'Dr. Amara Osei', "
        f"credential_label = 'MD', clinical_authority = true where org_id = {q(org)}::uuid;")

    # -- the protocol the clinic authors ---------------------------
    protocol_id = sql(
        f"select id from public.protocols where org_id = {q(org)}::uuid limit 1;")
    if not protocol_id:
        protocol_id = rpc("care_create_org_protocol", token, {
            "p_org": org,
            "p_title": PROTOCOL_TITLE,
            "p_supports": PROTOCOL_SUPPORTS,
        })
    print(f"  protocol · {PROTOCOL_TITLE}")

    # -- the roster ------------------------------------------------
    for p in SUPPORTING:
        seed_patient(org, token, protocol_id, p)

    # -- the stable code for the patient who carries the film -------
    mint_fixed_invitation(org, clinician_id, "Maya C.", CLINIC_CODE)

    print()
    status()


def seed_patient(org, clinician_token, protocol_id, p):
    label = p["label"]
    uid = ensure_user(p["email"])
    established = day(-7 * p["connected_weeks"])

    already = sql("select id from public.care_relationships where "
                  f"org_id = {q(org)}::uuid and patient_id = {q(uid)}::uuid limit 1;")
    if not already:
        # Real mechanics: the clinic issues a code, the patient
        # previews it and accepts it with her own scopes.
        inv = rpc("care_create_invitation", clinician_token,
                  {"p_org": org, "p_label": label})
        ptoken = sign_in(p["email"])
        preview = rpc("care_preview_invitation", ptoken, {"p_code": inv["code"]})
        if not preview.get("ok"):
            die(f"{label}: invitation preview failed — {preview}")
        res = rpc("care_accept_invitation", ptoken, {
            "p_code": inv["code"], "p_lookback_days": 28,
            "p_scopes": ["visit_packet_view", "observation_view", "care_assignment"],
        })
        if not res.get("ok"):
            die(f"{label}: accept failed — {res}")
        # Backdate the relationship so the roster has real tenure.
        sql("update public.care_relationships set established_at = "
            f"{q(established.isoformat())}::timestamptz "
            f"where org_id = {q(org)}::uuid and patient_id = {q(uid)}::uuid;")
        sql("update public.consent_grants set granted_at = "
            f"{q(established.isoformat())}::timestamptz "
            f"where org_id = {q(org)}::uuid and user_id = {q(uid)}::uuid;")

    # protocol assignment — the clinic's own protocol
    if p.get("med"):
        rpc("care_assign_protocol", clinician_token,
            {"p_org": org, "p_patient": uid, "p_protocol_id": protocol_id})

    # the assigned regimen — through the real clinical RPC
    regimen_id = None
    if p.get("med"):
        name, mg, anchor, started_days_ago, instruction = p["med"]
        existing_plan = sql("select id from public.regimen_plans where "
                            f"user_id = {q(uid)}::uuid and authority = 'care_team' "
                            "and ended_at is null limit 1;")
        if existing_plan:
            regimen_id = existing_plan
        else:
            regimen_id = rpc("care_assign_regimen", clinician_token, {
                "p_org": org, "p_patient": uid, "p_name": name,
                "p_strength_mg": mg, "p_anchor_weekday": anchor,
                "p_started_on": day(-started_days_ago).isoformat(),
                "p_instruction": instruction,
            })

    # synthetic history (fixture: these patients have no phone in the room)
    if p.get("weights"):
        first, last, n = p["weights"]
        sql(f"delete from public.weight_logs where user_id = {q(uid)}::uuid;")
        rows = []
        for i in range(n):
            frac = i / max(1, n - 1)
            kg = round(first + (last - first) * frac, 1)
            at = day(-7 * (n - 1 - i))
            rows.append(f"('demo-w-{i}-{uid}', {q(uid)}::uuid, {kg}, "
                        f"{q(at.isoformat())}::timestamptz, 'demo')")
        sql("insert into public.weight_logs (id, user_id, weight_kg, logged_at, source) "
            "values " + ",".join(rows) + ";")

    if p.get("packet"):
        payload = dict(p["packet"])
        payload["window"] = {"label": f"{day(-27).strftime('%b %-d').lower()} – "
                                      f"{TODAY.strftime('%b %-d').lower()}"}
        payload["displayUnit"] = "lb"
        sql(f"delete from public.visit_packets where user_id = {q(uid)}::uuid "
            f"and org_id = {q(org)}::uuid;")
        sql("insert into public.visit_packets "
            "(id, user_id, org_id, payload, window_start, window_end, generated_at, app_version) "
            f"values ({q(uid + '-' + org)}, {q(uid)}::uuid, {q(org)}::uuid, "
            f"{q(json.dumps(payload))}::jsonb, {q(key(-27))}::date, {q(key(0))}::date, "
            f"{q((dt.datetime.now() - dt.timedelta(hours=14)).isoformat())}::timestamptz, 'ios-s4');")

    if p.get("correction") and regimen_id:
        category, note = p["correction"]
        ptoken = sign_in(p["email"])
        open_already = sql("select id from public.correction_requests where "
                           f"patient_id = {q(uid)}::uuid and status = 'open' limit 1;")
        if not open_already:
            rpc("care_submit_correction", ptoken, {
                "p_org": org, "p_regimen_plan_id": regimen_id,
                "p_category": category, "p_note": note,
            })
            sql("update public.correction_requests set created_at = "
                f"{q((dt.datetime.now() - dt.timedelta(days=2)).isoformat())}::timestamptz "
                f"where patient_id = {q(uid)}::uuid and status = 'open';")

    if "follow_up_offset" in p:
        sql("update public.care_relationships set follow_up_on = "
            f"{q(key(p['follow_up_offset']))}::date "
            f"where org_id = {q(org)}::uuid and patient_id = {q(uid)}::uuid;")

    if "reviewed_hours_ago" in p:
        # Handled means read since the record last changed — so this
        # must land AFTER the packet's generated_at, not merely in the
        # recent past.
        sql("update public.care_relationships set reviewed_at = "
            f"{q((dt.datetime.now() - dt.timedelta(hours=p['reviewed_hours_ago'])).isoformat())}::timestamptz "
            f"where org_id = {q(org)}::uuid and patient_id = {q(uid)}::uuid;")

    print(f"  patient · {label}")


def mint_fixed_invitation(org, clinician_id, label, code):
    """The one stable code the founder types on camera.

    The code itself is a fixture; everything the patient then does
    with it — preview, consent, accept — is the real server law.
    `private.normalize_code` folds JENI-DEMO to the 8-character
    Crockford form JEN1DEM0, so this is a legitimate code, not a
    special case in the acceptance path.
    """
    sql(f"delete from public.patient_invitations where org_id = {q(org)}::uuid "
        f"and patient_label = {q(label)};")
    sql("insert into public.patient_invitations "
        "(org_id, created_by, code_hash, patient_label, expires_at) values ("
        f"{q(org)}::uuid, {q(clinician_id)}::uuid, private.hash_code({q(code)}), "
        f"{q(label)}, now() + interval '30 days');")
    print(f"  invitation · {code} → {label}")


# ----------------------------------------------------------- status

def status():
    guard()
    org = sql(f"select id from public.organizations where name = {q(CLINIC_NAME)} limit 1;")
    if not org:
        print("no demo clinic — run: scripts/demo/stack.sh reset")
        return
    env = sql("select value from private.config where key = 'environment';")
    rows = sql(
        "select r.patient_label || ' | ' || r.status || ' | ' || "
        "coalesce(to_char(r.follow_up_on,'YYYY-MM-DD'),'—') || ' | ' || "
        "case when vp.id is null then 'no packet' else 'packet' end || ' | ' || "
        "(select count(*) from public.correction_requests c "
        "  where c.patient_id = r.patient_id and c.status='open')::text "
        f"from public.care_relationships r "
        f"left join public.visit_packets vp on vp.user_id = r.patient_id and vp.org_id = r.org_id "
        f"where r.org_id = {q(org)}::uuid order by r.patient_label;")
    pending = sql("select patient_label from public.patient_invitations where "
                  f"org_id = {q(org)}::uuid and status = 'pending';")

    print(f"THE DEMO CLINIC   {CLINIC_NAME}")
    print(f"  environment     {env}   ({BASE})")
    print(f"  clinician       {CLINICIAN_EMAIL} / {PASSWORD}")
    print(f"  clinic code     {CLINIC_CODE}   → {pending or '(already used)'}")
    print(f"  roster          label | status | follow-up | packet | open corrections")
    for line in rows.splitlines():
        print(f"                  {line}")


if __name__ == "__main__":
    if "--status" in sys.argv:
        status()
    else:
        seed()
