#!/usr/bin/env python3
"""JeniMethod CBT v2 illustration set (Grok Imagine -> Vision cutout).

Pulls the canonical 23-asset prompt list from /tmp/jeni_redesign/synthesis_v2.json
(the round-2 expert review's grok_illustration_prompts field), generates each
via Grok Imagine, then runs Vision cutout for transparent-bg PNGs. Idempotent
per file. Faces stay obscured per the Direction A guardrail.

Outputs raw JPGs to generated_illustrations/jenimethod_v2/raw and cutouts to
generated_illustrations/jenimethod_v2/cut. The lesson_illustrations_to_assets.sh
helper then promotes them into Assets.xcassets.

Run: python3 scripts/generate_jenimethod_illustrations.py [--limit N]
"""
import argparse
import base64
import concurrent.futures as futures
import json
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "generated_illustrations", "jenimethod_v2", "raw")
CUT = os.path.join(ROOT, "generated_illustrations", "jenimethod_v2", "cut")
os.makedirs(RAW, exist_ok=True)
os.makedirs(CUT, exist_ok=True)

SYNTH = "/tmp/jeni_redesign/synthesis_objects.json"


def env_key(name):
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"missing {name}")


GROK_KEY = env_key("GROK_IMAGINE_API_KEY")


def gen(slug, prompt, retries=3):
    raw = os.path.join(RAW, f"{slug}.jpg")
    cut = os.path.join(CUT, f"{slug}.png")
    if os.path.exists(cut):
        return f"skip {slug} (cached)"
    if not os.path.exists(raw):
        body = {
            "model": "grok-imagine-image-quality",
            "prompt": prompt,
            "response_format": "b64_json",
        }
        for attempt in range(retries):
            try:
                req = urllib.request.Request(
                    "https://api.x.ai/v1/images/generations",
                    json.dumps(body).encode(),
                    {"Content-Type": "application/json",
                     "Authorization": f"Bearer {GROK_KEY}"},
                )
                with urllib.request.urlopen(req, timeout=240) as r:
                    d = json.load(r)
                img = d.get("data", [{}])[0].get("b64_json")
                if not img:
                    return f"{slug}: NO IMAGE {json.dumps(d)[:200]}"
                open(raw, "wb").write(base64.b64decode(img))
                break
            except Exception as e:
                if attempt == retries - 1:
                    return f"{slug}: {e}"
    r = subprocess.run(["/tmp/cutout", raw, cut], capture_output=True, text=True)
    if r.returncode != 0:
        return f"{slug}: cutout failed {(r.stdout + r.stderr)[:200]}"
    return f"done {slug}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0,
                        help="generate only the first N assets (priority order)")
    parser.add_argument("--only", type=str, default="",
                        help="comma-separated asset slugs to generate; overrides --limit")
    args = parser.parse_args()

    if not os.path.exists("/tmp/cutout"):
        # Compile cutout.swift once.
        sw = os.path.join(ROOT, "scripts", "cutout.swift")
        r = subprocess.run(["swiftc", "-O", sw, "-o", "/tmp/cutout"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print("cutout compile failed:", r.stderr, file=sys.stderr)
            sys.exit(1)

    with open(SYNTH) as f:
        synth = json.load(f)
    assets = synth.get("grok_illustration_prompts", [])

    # Priority order: hero photos for early lessons + collage for D1 first
    # (those are what the simulator screenshots will showcase).
    def priority(a):
        slug = a.get("asset_slug", "")
        if "d1_welcome" in slug: return 0
        if a.get("aesthetic_register") == "collage-element": return 1
        if a.get("aesthetic_register") == "hero-photo-bleed":
            # earlier lesson days first
            days = a.get("used_by_lesson_days") or [99]
            return 2 + (min(days) / 100.0)
        if a.get("aesthetic_register") == "single-artifact":
            days = a.get("used_by_lesson_days") or [99]
            return 50 + (min(days) / 100.0)
        return 100
    assets.sort(key=priority)

    if args.only:
        wanted = set(args.only.split(","))
        assets = [a for a in assets if a.get("asset_slug") in wanted]
    elif args.limit > 0:
        assets = assets[:args.limit]

    pairs = [(a["asset_slug"], a["grok_prompt"]) for a in assets]
    print(f"Generating {len(pairs)} assets...")
    with futures.ThreadPoolExecutor(max_workers=3) as ex:
        for result in ex.map(lambda kv: gen(*kv), pairs):
            print(result)
    print("all done")


if __name__ == "__main__":
    main()
