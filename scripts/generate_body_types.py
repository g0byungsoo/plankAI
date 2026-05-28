#!/usr/bin/env python3
"""Generate body-type illustrations for JeniFit onboarding via xAI Grok Imagine API.

Usage:
    scripts/generate_body_types.py test [--candidates N]
        Generate N candidates of the 'Athletic' body type for aesthetic review.
    scripts/generate_body_types.py all [--candidates N]
        Generate every body type + reshape goal image. Defaults to 1 each.
    scripts/generate_body_types.py <key> [--candidates N]
        Generate one slot by key (e.g. cut, lean, athletic, average, curvy, soft, reshape).

Outputs land under scripts/generated/ as PNG. Reads XAI_API_KEY from /Users/bko/plankAI/.env.
"""
import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

import urllib.request
import urllib.error


REPO_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = REPO_ROOT / ".env"
OUT_DIR = Path(__file__).resolve().parent / "generated"

ENDPOINT = "https://api.x.ai/v1/images/generations"
MODEL = "grok-imagine-image"
ASPECT = "3:4"
RESOLUTION = "2k"


def load_env() -> str:
    if "XAI_API_KEY" in os.environ:
        return os.environ["XAI_API_KEY"]
    if not ENV_FILE.exists():
        sys.exit(f"ERROR: {ENV_FILE} not found and XAI_API_KEY not in env")
    for raw in ENV_FILE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("XAI_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("ERROR: XAI_API_KEY not found in .env")


# --- Prompt building ---------------------------------------------------------

# Character anchor — kept identical across every body type so the same woman
# appears at different body compositions. Description matches the reference
# photo the user supplied (long blonde wavy hair, fair skin, athletic frame).
CHARACTER = (
    "A young woman in her early twenties with long flowing wavy blonde hair "
    "falling past her shoulders to mid-back, fair complexion, soft natural "
    "makeup, calm confident expression looking at the camera. She stands "
    "straight facing the camera with arms relaxed at her sides, full body "
    "visible from head to toe, feet shoulder-width apart. She wears a "
    "dusty rose pink sports bra (color hex C4677A) and matching high-waisted "
    "athletic leggings in the same dusty rose pink, with clean white sneakers."
)

STYLE = (
    "Stylized 3D-rendered fitness illustration in the BetterMe / Lasta / Fitia "
    "mobile app style: semi-realistic with smooth flattering proportions, "
    "soft warm studio lighting from the front-left, no harsh shadows. "
    "Plain soft cream background (color hex FDF6F4), nothing else in frame. "
    "Centered full-body composition with comfortable headroom and footroom. "
    "No text, no watermarks, no logos, no UI overlays, no annotations. "
    "Clean professional onboarding illustration aesthetic."
)


BODY_TYPES = {
    "cut": (
        "bodytype_0_cut",
        "She has a very slim and lean body with a hint of ab definition, "
        "slender arms and slim legs without prominent or bulky muscle, "
        "naturally low body fat in a runway-model or ballerina-style "
        "physique. Body fat around 14 to 17 percent. Slim and feminine, "
        "explicitly NOT muscular, NOT athletic, NOT bodybuilder-style — "
        "more like a delicate dancer's frame than a fitness competitor.",
    ),
    "lean": (
        "bodytype_1_lean",
        "She has a lean and toned athletic body with faint ab definition, "
        "subtle muscle tone in arms and legs, slim waist. Body fat around "
        "16 to 20 percent. Fitness-model lean.",
    ),
    "athletic": (
        "bodytype_2_athletic",
        "She has a fit and healthy body with a smooth toned silhouette, "
        "no visible abs but balanced gentle muscle, healthy proportions. "
        "Body fat around 21 to 25 percent. The everyday active woman.",
    ),
    "average": (
        "bodytype_3_average",
        "She has an average healthy body with soft natural curves, smooth "
        "midsection without definition, gentle softness at the waist. "
        "Body fat around 26 to 30 percent.",
    ),
    "curvy": (
        "bodytype_4_curvy",
        "She has softly curvy proportions with fuller hips and thighs, "
        "soft midsection, fuller bust. Body fat around 31 to 38 percent.",
    ),
    "soft": (
        "bodytype_5_soft",
        "She has a fuller softer body with comfortable rounder figure "
        "throughout — fuller arms, midsection, hips, and thighs. Body fat "
        "above 40 percent. Plus-size proportions, kept tasteful and "
        "respectful, never caricatured.",
    ),
    "reshape": (
        "bodytype_goal_reshape",
        "She has a fit toned body with subtle defined core, lifted "
        "energetic posture, healthy glowing skin, gently smiling with "
        "confidence. Body fat around 20 to 24 percent. The empowered "
        "goal-state version — strong, healthy, radiant. No before/after "
        "framing, just the radiant goal version.",
    ),
}


def build_prompt(body_desc: str) -> str:
    return f"{CHARACTER} {body_desc} {STYLE}"


# --- API call ----------------------------------------------------------------

def call_api(api_key: str, prompt: str, n: int) -> dict:
    payload = {
        "model": MODEL,
        "prompt": prompt,
        "n": n,
        "aspect_ratio": ASPECT,
        "resolution": RESOLUTION,
        "response_format": "b64_json",
    }
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=240) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        sys.exit(f"HTTP {e.code} from xAI: {body[:600]}")
    except urllib.error.URLError as e:
        sys.exit(f"Network error calling xAI: {e}")


def generate(api_key: str, key: str, n: int) -> list[Path]:
    if key not in BODY_TYPES:
        sys.exit(f"Unknown key '{key}'. Valid: {', '.join(BODY_TYPES)}")
    name, desc = BODY_TYPES[key]
    prompt = build_prompt(desc)
    print(f"→ {key}: requesting {n} candidate{'s' if n != 1 else ''} ({MODEL}, {ASPECT}, {RESOLUTION})")
    data = call_api(api_key, prompt, n)
    items = data.get("data", [])
    if not items:
        print(f"  ⚠ No images in response: {json.dumps(data)[:400]}")
        return []
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    for i, item in enumerate(items):
        b64 = item.get("b64_json")
        if not b64:
            url = item.get("url")
            if url:
                with urllib.request.urlopen(url, timeout=120) as r:
                    raw = r.read()
            else:
                print(f"  ⚠ candidate {i+1} had neither b64_json nor url; skipping")
                continue
        else:
            raw = base64.b64decode(b64)
        suffix = "" if n == 1 else f"_v{i+1}"
        out_path = OUT_DIR / f"{name}{suffix}.png"
        out_path.write_bytes(raw)
        size_kb = out_path.stat().st_size // 1024
        print(f"  ✓ {out_path.relative_to(REPO_ROOT)} ({size_kb} KB)")
        paths.append(out_path)
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="One of: test, all, or a body-type key")
    parser.add_argument("--candidates", "-n", type=int, default=1,
                        help="Candidates per slot (default 1)")
    args = parser.parse_args()

    api_key = load_env()

    if args.target == "test":
        generate(api_key, "athletic", args.candidates)
    elif args.target == "all":
        for key in BODY_TYPES:
            generate(api_key, key, args.candidates)
            time.sleep(1)
    else:
        generate(api_key, args.target, args.candidates)


if __name__ == "__main__":
    main()
