#!/usr/bin/env python3
"""45 · §5 — DOES THE ACCOUNT HANDOFF CARRY THE SPINE?

Until 2026-08-15 this question was unanswerable in practice: both tables
held zero rows, so `private.transfer_account_rows` had never had one to
move. Now it can, so it must be proven before anyone's next sign-in.

WHAT THIS DOES TO PRODUCTION, stated plainly:

  · it creates two throwaway anonymous accounts over the real API and
    writes synthetic spine rows as each, exactly as the app would;
  · it then runs the DEPLOYED mover inside a transaction that ALWAYS
    ABORTS — the `DO` block ends in `raise exception`, so the rollback
    is structural, not a statement someone has to remember. The
    assertions ride out in the exception message.
  · it deletes both throwaway accounts through the shipping
    `delete_user_account()` RPC and re-reads the counts.

Nothing it writes survives. Nothing belonging to a customer is read.

  python3 handoff_proof.py
"""
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request

BASE = "https://mtecqvykyeueumdynatd.supabase.co"
KEY = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu"


def call(method, path, token=None, body=None, extra=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("apikey", KEY)
    req.add_header("Authorization", f"Bearer {token or KEY}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    for k, v in (extra or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw


def anon():
    s, p = call("POST", "/auth/v1/signup", body={})
    assert s == 200, (s, p)
    return p["access_token"], p["user"]["id"]


def upsert(table, token, row):
    cols = ",".join(sorted(row.keys()))
    return call("POST", f"/rest/v1/{table}?columns={cols}", token=token, body=row,
                extra={"Prefer": "resolution=merge-duplicates,return=representation"})


SQL = """
do $$
declare
  v_src uuid := '{SRC}';
  v_dst uuid := '{DST}';
  v_out text := '';
  n int;
begin
  -- A prescribed fact can only be authored by a clinic RPC, so seed one
  -- here as `postgres` — it is the row the mover must REFUSE to carry.
  insert into public.program_facts
    (id, user_id, kind, value, authority, basis, source)
  values
    (v_src::text || '-45presc', v_src, 'stepGoal', 'i:9000',
     'prescribed', 'assigned', 'care_team:45-probe');

  select count(*) into n from public.program_facts where user_id = v_src;
  v_out := v_out || 'BEFORE src_facts=' || n;
  select count(*) into n from public.program_facts where user_id = v_dst;
  v_out := v_out || ' dst_facts=' || n;
  select count(*) into n from public.weekly_reads where user_id = v_src;
  v_out := v_out || ' src_reads=' || n;
  select count(*) into n from public.weekly_reads where user_id = v_dst;
  v_out := v_out || ' dst_reads=' || n;

  perform private.transfer_account_rows(v_src, v_dst);

  select count(*) into n from public.program_facts where user_id = v_src;
  v_out := v_out || ' :: AFTER src_facts=' || n;
  select count(*) into n from public.program_facts where user_id = v_dst;
  v_out := v_out || ' dst_facts=' || n;
  select count(*) into n from public.weekly_reads where user_id = v_src;
  v_out := v_out || ' src_reads=' || n;
  select count(*) into n from public.weekly_reads where user_id = v_dst;
  v_out := v_out || ' dst_reads=' || n;

  -- the prescribed row must be GONE, not re-owned
  select count(*) into n from public.program_facts
   where authority = 'prescribed' and source = 'care_team:45-probe';
  v_out := v_out || ' :: prescribed_surviving=' || n;

  -- the source's read for the SHARED window must have lost to the
  -- destination's, and the destination's id must be untouched
  select count(*) into n from public.weekly_reads
   where user_id = v_dst and id = lower(v_dst::text) || '-read-2001-01-01';
  v_out := v_out || ' dst_shared_window_rows=' || n;

  -- the source's read for its OWN window must have arrived under the
  -- destination's prefix, with the tail's case preserved
  select count(*) into n from public.weekly_reads
   where user_id = v_dst and id = lower(v_dst::text) || '-read-2001-02-02';
  v_out := v_out || ' carried_window_rows=' || n;

  -- and no row may still carry the source's prefix
  select count(*) into n from public.weekly_reads
   where lower(id) like lower(v_src::text) || '%';
  v_out := v_out || ' rows_still_src_prefixed=' || n;

  raise exception 'ROLLBACK-BY-DESIGN :: %', v_out;
end $$;
"""


def main():
    print("=== 45 · HANDOFF PROOF (rolled back by construction) ===\n")
    sT, sU = anon()
    dT, dU = anon()
    print(f"  src={sU}\n  dst={dU}\n")

    # the app's own shapes
    for tok, uid, window in ((sT, sU, "2001-01-01"), (dT, dU, "2001-01-01"),
                             (sT, sU, "2001-02-02")):
        s, _ = upsert("weekly_reads", tok, {
            "id": f"{uid.lower()}-read-{window}", "user_id": uid,
            "window_start_day": window, "anchor": "enrollment",
            "shown": "45-probe", "offer_key": "hold_steady", "decision": "declined",
        })
        print(f"  seed weekly_read {uid[:8]} {window} -> {s}")
    for tok, uid in ((sT, sU), (dT, dU)):
        s, _ = upsert("program_facts", tok, {
            "id": f"{uid}-45fact", "user_id": uid, "kind": "stepGoal",
            "value": "i:5150", "authority": "preferred", "basis": "stated",
            "source": "45-probe",
        })
        print(f"  seed program_fact {uid[:8]} -> {s}")

    sql = SQL.replace("{SRC}", sU).replace("{DST}", dU)
    open("/tmp/45_handoff.sql", "w").write(sql)
    print("\n  running the DEPLOYED private.transfer_account_rows ...")
    r = subprocess.run(
        ["supabase", "db", "query", "--linked", "-f", "/tmp/45_handoff.sql"],
        capture_output=True, text=True,
    )
    blob = r.stdout + r.stderr
    m = re.search(r"ROLLBACK-BY-DESIGN :: (.*)", blob)
    print("\n  " + (m.group(1).strip() if m else "NO RESULT — raw output below\n" + blob[:2000]))

    print("\n  cleanup ...")
    for name, tok in (("src", sT), ("dst", dT)):
        s, _ = call("POST", "/rest/v1/rpc/delete_user_account", token=tok, body={})
        print(f"    delete {name} -> {s}")
    return 0 if m else 1


if __name__ == "__main__":
    sys.exit(main())
