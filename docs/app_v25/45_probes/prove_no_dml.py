#!/usr/bin/env python3
"""Mechanically separate CUSTOMER-ROW DML from SCHEMA/PRIVILEGE change.

A GRANT/REVOKE is a security change, not a customer-row mutation. This
asserts a migration contains NOTHING but privilege statements, and prints
exactly what it does contain.

The naive "does the word `select` appear" test is wrong here: SELECT,
INSERT and UPDATE are the *privilege names* inside a GRANT. So the test
is structural instead —

  1. strip comments and single-quoted literals;
  2. every semicolon-separated statement must match, in full, the strict
     shape  GRANT|REVOKE <privilege list> ON <object> TO|FROM <roles>;
  3. the object and role halves are then re-scanned for any row-touching
     or object-reshaping keyword, so a payload cannot hide there.

Usage: python3 prove_no_dml.py <file.sql> [...]
Exit 0 only when every file is privilege-only.
"""
import re
import sys

SHAPE = re.compile(
    r"^(?P<verb>grant|revoke)\s+"
    r"(?P<privs>[a-z][a-z, ]*?)\s+"
    r"on\s+(?P<obj>[a-z_][a-z0-9_. ]*?)\s+"
    r"(?P<dir>to|from)\s+"
    r"(?P<roles>[a-z_][a-z0-9_, ]*)$",
    re.I,
)

LEGAL_PRIVS = {"select", "insert", "update", "delete", "truncate",
               "references", "trigger", "maintain", "usage", "execute", "all"}

DANGER = ["insert", "update", "delete", "truncate", "merge", "copy", "select",
          "drop", "alter", "create", "call", "do", "refresh", "vacuum",
          "analyze", "lock", "notify", "nextval", "setval", "pg_sleep",
          "dblink", "reassign", "definer", "policy", "function", "public.users",
          "auth."]


def strip(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\n]*", " ", sql)
    sql = re.sub(r"'(?:[^']|'')*'", " '' ", sql)
    return sql


def main(paths):
    ok = True
    for path in paths:
        body = strip(open(path).read())
        stmts = [" ".join(s.split()) for s in body.split(";") if s.strip()]
        print(f"{path}")
        clean = bool(stmts)
        for s in stmts:
            m = SHAPE.match(s)
            if not m:
                print(f"    NOT A PRIVILEGE STATEMENT: {s}")
                clean = False
                continue
            privs = {p.strip().lower() for p in m.group("privs").split(",")}
            illegal = privs - LEGAL_PRIVS
            tail = m.group("obj") + " " + m.group("roles")
            hidden = [w for w in DANGER
                      if re.search(r"(?<![A-Za-z0-9_])" + re.escape(w) + r"(?![A-Za-z0-9_])",
                                   tail, re.I)]
            status = "OK" if not illegal and not hidden else "SUSPECT"
            print(f"    {status:7} {m.group('verb').upper():6} privs={sorted(privs)} "
                  f"object={m.group('obj')} {m.group('dir')}={m.group('roles')}")
            if illegal:
                print(f"            unknown privilege token(s): {sorted(illegal)}")
            if hidden:
                print(f"            danger keyword in object/role half: {hidden}")
            clean = clean and not illegal and not hidden
        print(f"  statements: {len(stmts)}")
        print(f"  CUSTOMER DATA DML: {'NONE' if clean else 'PRESENT — INSPECT'}")
        print(f"  PRIVILEGE-ONLY: {'YES' if clean else 'NO'}")
        ok = ok and clean
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
