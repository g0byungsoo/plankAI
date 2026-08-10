#!/usr/bin/env python3
"""
Act as the clinician: assign Maya's care from the demo clinic.

This is what Dr. Osei does in the dashboard — the script exists so a
film or a capture run can perform it deterministically at the exact
moment the story needs it, through the same RPCs the dashboard calls.

  python3 scripts/demo/assign.py regimen     the medication plan
  python3 scripts/demo/assign.py steps       a prescribed step goal
  python3 scripts/demo/assign.py protocol    the clinic's protocol
  python3 scripts/demo/assign.py all         all three
  python3 scripts/demo/assign.py review      mark the record read
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from seed import (  # noqa: E402
    CLINIC_NAME, CLINICIAN_EMAIL, guard, q, rpc, sign_in, sql, day,
)

# What the clinic decides for Maya. Her own record already shows 1 mg
# weekly; the clinic records the same plan under its own authority,
# which is exactly what reconciliation is for.
REGIMEN = {
    "name": "Wegovy",
    "strength_mg": 1.0,
    "instruction": "evening. thigh or abdomen is fine. take it with water.",
}
STEP_GOAL = "6500"


def context():
    guard()
    org = sql(f"select id from public.organizations where name = {q(CLINIC_NAME)} limit 1;")
    if not org:
        sys.exit("no demo clinic — run scripts/demo/stack.sh reset")
    patient = sql("select patient_id from public.care_relationships "
                  f"where org_id = {q(org)}::uuid and patient_label = 'Maya C.' limit 1;")
    if not patient:
        sys.exit("Maya has not connected yet — launch the app with "
                 "--demo-backend --demo-patient and enter JENI-DEMO")
    return org, patient, sign_in(CLINICIAN_EMAIL)


def assign_regimen(org, patient, token):
    existing = sql("select id from public.regimen_plans where "
                   f"user_id = {q(patient)}::uuid and authority = 'care_team' "
                   "and ended_at is null limit 1;")
    if existing:
        print("  regimen already assigned")
        return
    # Her own record anchors on the weekday one week back; the clinic
    # records the same rhythm rather than moving her onto a new day.
    anchor = sql("select extract(isodow from started_at)::int "
                 f"from public.regimen_plans where user_id = {q(patient)}::uuid "
                 "and authority = 'self' order by started_at desc limit 1;")
    rid = rpc("care_assign_regimen", token, {
        "p_org": org, "p_patient": patient,
        "p_name": REGIMEN["name"], "p_strength_mg": REGIMEN["strength_mg"],
        "p_anchor_weekday": int(anchor or 4),
        "p_started_on": day(-21).isoformat(),
        "p_instruction": REGIMEN["instruction"],
    })
    print(f"  regimen assigned · {REGIMEN['name']} {REGIMEN['strength_mg']} mg → {rid}")


def assign_steps(org, patient, token):
    rpc("care_set_program_fact", token, {
        "p_org": org, "p_patient": patient,
        "p_kind": "stepGoal", "p_value": STEP_GOAL,
    })
    print(f"  step goal prescribed · {STEP_GOAL}/day")


def assign_protocol(org, patient, token):
    protocol_id = sql(f"select id from public.protocols where org_id = {q(org)}::uuid limit 1;")
    rpc("care_assign_protocol", token,
        {"p_org": org, "p_patient": patient, "p_protocol_id": protocol_id})
    print(f"  protocol assigned · {protocol_id}")


def mark_reviewed(org, patient, token):
    rpc("care_set_patient_review", token, {
        "p_org": org, "p_patient": patient, "p_mark_reviewed": True,
    })
    print("  record marked read")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    o, p, t = context()
    print(f"clinician acting on Maya C. ({p[:8]}…)")
    if what in ("regimen", "all"):
        assign_regimen(o, p, t)
    if what in ("protocol", "all"):
        assign_protocol(o, p, t)
    if what in ("steps", "all"):
        assign_steps(o, p, t)
    if what == "review":
        mark_reviewed(o, p, t)
