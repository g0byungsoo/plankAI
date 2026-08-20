#!/usr/bin/env python3
"""Mechanically prove a .sql file is READ ONLY before it touches production.

Strips `--` comments, /* */ comments and single-quoted literals, then
matches 28 write keywords as WHOLE WORDS. Also reports the statement
count and the first word of each statement.

Usage: python3 prove_read_only.py <file.sql> [...]
Exit 0 only when every file is clean.
"""
import re
import sys

WRITE_WORDS = [
    "insert", "update", "delete", "truncate", "drop", "alter", "create",
    "grant", "revoke", "copy", "call", "do", "merge", "refresh", "vacuum",
    "analyze", "comment", "set", "begin", "commit", "rollback", "lock",
    "notify", "execute", "nextval", "setval", "pg_sleep", "dblink",
]


def strip(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\n]*", " ", sql)
    sql = re.sub(r"'(?:[^']|'')*'", " '' ", sql)
    return sql


def main(paths):
    ok = True
    for path in paths:
        raw = open(path).read()
        body = strip(raw)
        hits = {}
        for w in WRITE_WORDS:
            n = len(re.findall(r"(?<![A-Za-z0-9_])" + re.escape(w) + r"(?![A-Za-z0-9_])",
                               body, flags=re.I))
            if n:
                hits[w] = n
        stmts = [s.strip() for s in body.split(";") if s.strip()]
        firsts = [s.split()[0].lower() for s in stmts if s.split()]
        print(f"{path}")
        print(f"  statements: {len(stmts)}  first words: {sorted(set(firsts))}")
        print(f"  write-keyword hits: {hits if hits else '0 (NONE)'}")
        clean = not hits and all(f in ("select", "with") for f in firsts)
        print(f"  READ ONLY: {'YES' if clean else 'NO'}")
        ok = ok and clean
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
