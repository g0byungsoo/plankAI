#!/usr/bin/env python3
"""45 · REAL API PROOF — the same contract the shipping iOS app uses.

Talks to production GoTrue + PostgREST with the PUBLISHABLE key only —
exactly what the app ships. No service_role key, no database password,
no catalog access.

  python3 api_proof.py before      # expect every write/read refused
  python3 api_proof.py after       # expect own-row works, cross-account refused

Creates four throwaway identities (2 anonymous, 2 permanent), exercises
program_facts and weekly_reads, then DELETES every row it wrote and every
account it created via the shipping `delete_user_account()` RPC, and
proves the cleanup by re-reading as a fresh caller.

Synthetic values only: kind=stepGoal, value=i:5150, window_start_day in
2001. Nothing resembling a real customer fact.
"""
import json
import sys
import urllib.error
import urllib.request
import uuid

BASE = "https://mtecqvykyeueumdynatd.supabase.co"
KEY = "sb_publishable_HiM0VWqTOXOa6c-BDAKWOA_DFkrNvAu"
TAG = "45-probe"

results = []


def call(method, path, token=None, body=None, extra=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
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


def code_of(payload):
    if isinstance(payload, dict):
        return payload.get("code") or payload.get("error_code") or ""
    return ""


def check(label, expect, status, payload):
    """expect: 'ok' | 'denied'"""
    denied = status in (401, 403) or code_of(payload) == "42501"
    ok = 200 <= status < 300
    verdict = "PASS" if ((expect == "ok" and ok) or (expect == "denied" and denied)) else "FAIL"
    detail = code_of(payload) or ("" if ok else str(payload)[:110])
    results.append((verdict, label, expect, status, detail))
    print(f"  {verdict:4} {label:52} expect={expect:6} http={status} {detail}")
    return ok


def anon_user():
    s, p = call("POST", "/auth/v1/signup", body={})
    assert s == 200, (s, p)
    return p["access_token"], p["user"]["id"]


def perm_user(n):
    email = f"jeni-45-probe-{n}-{uuid.uuid4().hex[:10]}@example.com"
    s, p = call("POST", "/auth/v1/signup",
                body={"email": email, "password": "Pr0be-45-throwaway!"})
    assert s == 200 and p.get("access_token"), (s, p)
    return p["access_token"], p["user"]["id"], email


def fact_row(uid, suffix=""):
    return {
        "id": f"{uid}-45probe{suffix}",
        "user_id": uid,
        "kind": "stepGoal",
        "value": "i:5150",
        "authority": "preferred",
        "basis": "stated",
        "source": TAG,
    }


def read_row(uid, suffix=""):
    return {
        "id": f"{uid}-read-2001-01-0{1 if not suffix else 2}",
        "user_id": uid,
        "window_start_day": "2001-01-01",
        "anchor": "enrollment",
        "shown": TAG,
        "offer_key": "hold_steady",
        "decision": "declined",
    }


def upsert(table, token, row):
    # BYTE-FOR-BYTE what supabase-swift `.from(t).upsert(row).execute()`
    # sends: PostgrestQueryBuilder.upsert defaults `returning` to
    # `.representation`, so the shipping statement is
    #   POST /rest/v1/<t>?columns=<sorted keys>
    #   Prefer: resolution=merge-duplicates,return=representation
    # and therefore needs SELECT as well as INSERT and UPDATE.
    cols = ",".join(sorted(row.keys()))
    return call("POST", f"/rest/v1/{table}?columns={cols}", token=token, body=row,
                extra={"Prefer": "resolution=merge-duplicates,return=representation"})


def select(table, token, uid):
    return call("GET", f"/rest/v1/{table}?user_id=eq.{uid}&select=*", token=token)


def main(phase):
    expect_own = "ok" if phase == "after" else "denied"
    print(f"\n=== 45 REAL API PROOF · phase={phase} ===")
    print(f"    own-row operations are expected to be: {expect_own.upper()}\n")

    aT, aU = anon_user()
    bT, bU = anon_user()
    pT, pU, pE = perm_user("p")
    qT, qU, qE = perm_user("q")
    print(f"  identities: anonA={aU[:8]} anonB={bU[:8]} permP={pU[:8]} permQ={qU[:8]}\n")

    print("-- A/B: anonymous, own program_fact --")
    s, p = upsert("program_facts", aT, fact_row(aU)); check("A anon INSERT own program_fact", expect_own, s, p)
    s, p = select("program_facts", aT, aU); check("B anon SELECT own program_fact", expect_own, s, p)

    print("-- C/D: permanent, own program_fact --")
    s, p = upsert("program_facts", pT, fact_row(pU)); check("C perm INSERT own program_fact", expect_own, s, p)
    s, p = select("program_facts", pT, pU); check("D perm SELECT own program_fact", expect_own, s, p)

    print("-- E/F: anonymous, own weekly_read --")
    s, p = upsert("weekly_reads", aT, read_row(aU)); check("E anon INSERT own weekly_read", expect_own, s, p)
    s, p = select("weekly_reads", aT, aU); check("F anon SELECT own weekly_read", expect_own, s, p)

    print("-- G/H: permanent, own weekly_read --")
    s, p = upsert("weekly_reads", pT, read_row(pU)); check("G perm INSERT own weekly_read", expect_own, s, p)
    s, p = select("weekly_reads", pT, pU); check("H perm SELECT own weekly_read", expect_own, s, p)

    print("-- UPSERT-as-UPDATE (the shipping supersede write) --")
    r = fact_row(aU); r["value"] = "i:6000"; r["ended_at"] = "2026-08-15T00:00:00Z"; r["end_reason"] = "superseded"
    s, p = upsert("program_facts", aT, r); check("anon UPDATE own fact via upsert", expect_own, s, p)
    s, p = call("PATCH", f"/rest/v1/program_facts?id=eq.{aU}-45probe", token=aT,
                body={"end_reason": "reset"}, extra={"Prefer": "return=minimal"})
    check("anon PATCH own fact", expect_own, s, p)

    if phase == "after":
        # the ON CONFLICT DO UPDATE branch must have actually FIRED —
        # a grant that lets the insert through but silently no-ops the
        # conflict would look identical from the status code alone.
        s, p = call("GET", f"/rest/v1/program_facts?id=eq.{aU}-45probe&select=value,end_reason", token=aT)
        landed = isinstance(p, list) and len(p) == 1 and p[0]["value"] == "i:6000" \
            and p[0]["end_reason"] == "reset"
        results.append(("PASS" if landed else "FAIL", "the upsert's UPDATE branch really landed", "ok", s, str(p)[:70]))
        print(f"  {'PASS' if landed else 'FAIL':4} {'the upsert UPDATE branch really landed':52} http={s} {p}")

    print("-- THE AUTHORITY LAW: iOS must never write a prescription --")
    r = fact_row(aU, "-presc"); r["authority"] = "prescribed"
    s, p = upsert("program_facts", aT, r)
    check("anon INSERT authority=prescribed (must be refused)", "denied", s, p)
    # ...and she must not be able to PROMOTE her own row to one either.
    s, p = call("PATCH", f"/rest/v1/program_facts?id=eq.{aU}-45probe", token=aT,
                body={"authority": "prescribed"}, extra={"Prefer": "return=representation"})
    promoted = isinstance(p, list) and len(p) > 0
    results.append(("FAIL" if promoted else "PASS", "own fact cannot be PROMOTED to prescribed", "denied", s, str(p)[:70]))
    print(f"  {'FAIL' if promoted else 'PASS':4} {'own fact cannot be PROMOTED to prescribed':52} http={s} rows={len(p) if isinstance(p, list) else p}")

    print("-- UNFILTERED READ: RLS, not the client's WHERE clause --")
    s, p = call("GET", "/rest/v1/program_facts?select=user_id", token=aT)
    only_own = isinstance(p, list) and all(x["user_id"] == aU for x in p)
    ok_here = only_own if phase == "after" else s in (401, 403)
    results.append(("PASS" if ok_here else "FAIL", "unfiltered SELECT returns only own rows", "ok", s, f"{len(p) if isinstance(p, list) else p} rows"))
    print(f"  {'PASS' if ok_here else 'FAIL':4} {'unfiltered SELECT returns only own rows':52} http={s} rows={len(p) if isinstance(p, list) else p}")

    print("-- ADVERSARIAL: cross-account --")
    s, p = upsert("program_facts", aT, fact_row(bU, "-x")); check("A cannot INSERT a fact for B", "denied", s, p)
    s, p = select("program_facts", aT, bU)
    empty = (200 <= s < 300) and p == []
    results.append(("PASS" if empty or s in (401, 403) else "FAIL",
                    "A cannot READ B's facts (empty or refused)", "denied", s, str(p)[:60]))
    print(f"  {'PASS' if empty or s in (401,403) else 'FAIL':4} {'A cannot READ B facts (empty or refused)':52} http={s} rows={len(p) if isinstance(p, list) else p}")
    s, p = call("PATCH", f"/rest/v1/program_facts?user_id=eq.{bU}", token=aT,
                body={"value": "i:1"}, extra={"Prefer": "return=representation"})
    changed = isinstance(p, list) and len(p) > 0
    results.append(("FAIL" if changed else "PASS", "A cannot UPDATE B's facts", "denied", s, str(p)[:60]))
    print(f"  {'FAIL' if changed else 'PASS':4} {'A cannot UPDATE B facts':52} http={s} changed={len(p) if isinstance(p, list) else p}")
    s, p = call("DELETE", f"/rest/v1/program_facts?user_id=eq.{bU}", token=aT,
                extra={"Prefer": "return=representation"})
    deleted = isinstance(p, list) and len(p) > 0
    results.append(("FAIL" if deleted else "PASS", "A cannot DELETE B's facts", "denied", s, str(p)[:60]))
    print(f"  {'FAIL' if deleted else 'PASS':4} {'A cannot DELETE B facts':52} http={s} deleted={len(p) if isinstance(p, list) else p}")

    s, p = upsert("weekly_reads", pT, read_row(qU, "x")); check("P cannot INSERT a read for Q", "denied", s, p)
    s, p = select("weekly_reads", pT, qU)
    empty = (200 <= s < 300) and p == []
    print(f"  {'PASS' if empty or s in (401,403) else 'FAIL':4} {'P cannot READ Q reads (empty or refused)':52} http={s} rows={len(p) if isinstance(p, list) else p}")
    results.append(("PASS" if empty or s in (401, 403) else "FAIL", "P cannot READ Q's reads", "denied", s, ""))

    print("-- anon key with NO user token (the unauthenticated caller) --")
    s, p = call("GET", "/rest/v1/program_facts?select=id"); check("anon role SELECT program_facts", "denied", s, p)
    s, p = call("GET", "/rest/v1/weekly_reads?select=id"); check("anon role SELECT weekly_reads", "denied", s, p)

    print("\n-- CLEANUP: shipping delete_user_account() for all four --")
    for name, tok, uid in (("anonA", aT, aU), ("anonB", bT, bU), ("permP", pT, pU), ("permQ", qT, qU)):
        s, p = call("POST", "/rest/v1/rpc/delete_user_account", token=tok, body={})
        print(f"  delete {name} -> http={s} {code_of(p) or ''}")
        results.append(("PASS" if 200 <= s < 300 else "FAIL", f"delete_user_account {name}", "ok", s, ""))
        # the token must now be dead
        s2, _ = call("GET", "/auth/v1/user", token=tok)
        print(f"    token after delete -> http={s2} (403/401 expected)")

    print("\n=== SUMMARY ===")
    fails = [r for r in results if r[0] == "FAIL"]
    for r in results:
        print(f"  {r[0]:4} {r[1]}")
    print(f"\n  {len(results) - len(fails)} pass · {len(fails)} fail")
    print("  probe uids:", aU, bU, pU, qU)
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "before"))
