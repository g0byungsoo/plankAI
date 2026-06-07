#!/usr/bin/env python3
"""Generate the HomeFoodCard hero illustration via xAI Grok Imagine.

v1.0.7 round 16 (2026-06-07): swapping the avocado-toast wholefoods plate
for a strawberries + yogurt parfait (founder pick — matches JeniFit's
red-pink jeweledRose palette and reads as a more cohort-coded aesthetic
snack vs the more generic breakfast plate).

Usage:
    Scripts/generate_food_card_illustration.py [--candidates N]

Outputs to Scripts/generated/food_card_illustration_v{i}.png.
Reads XAI_API_KEY from /Users/bko/plankAI/.env.
"""
import argparse
import base64
import json
import os
import sys
from pathlib import Path

import urllib.request
import urllib.error


REPO_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = REPO_ROOT / ".env"
OUT_DIR = Path(__file__).resolve().parent / "generated"

ENDPOINT = "https://api.x.ai/v1/images/generations"
MODEL = "grok-imagine-image"
# 1:1 — the HomeFoodCard overlay is roughly square (110x100 in filled
# state, 220x200 in empty state); square art crops cleanly into both.
ASPECT = "1:1"
RESOLUTION = "2k"


PROMPT = (
    "A top-down photograph of a clear small glass parfait jar on a "
    "clean soft cream background (color hex FDF6F4). The parfait is "
    "layered from bottom to top: a base layer of golden honey-toasted "
    "granola; a thick layer of white greek yogurt; a vivid red layer "
    "of strawberry coulis sauce; another layer of white greek yogurt; "
    "and a top layer of fresh whole and halved ripe strawberries with "
    "a single small sprig of fresh green mint as garnish. The strawberries "
    "are bright crimson red, glossy and dewy, looking fresh and "
    "appetizing. The layers are clearly visible through the clear glass. "
    "Soft warm natural lighting from the upper-left, gentle shadows, "
    "no harsh highlights. Aesthetic Pinterest-coded breakfast photo "
    "in the style of food influencer creator content (TikTok / "
    "Instagram wholefoods aesthetic). The composition is centered with "
    "comfortable padding on all sides. Nothing else in frame — no "
    "utensils, no other dishes, no marble, no marble texture, no wood, "
    "no countertop visible. The background is a flat soft cream color. "
    "Color palette: vivid red strawberries, soft pink coulis, white "
    "yogurt, golden granola, fresh green mint, all against soft cream. "
    "Reads as fresh, indulgent, healthy, feminine. No text, no "
    "watermarks, no logos, no UI overlays, no annotations."
)


def load_env() -> str:
    # GROK_IMAGINE_API_KEY is the canonical name in this repo's .env.
    # Fall back to XAI_API_KEY for parity with the older body-types
    # script which used the upstream xAI naming.
    for candidate in ("GROK_IMAGINE_API_KEY", "XAI_API_KEY"):
        if candidate in os.environ:
            return os.environ[candidate]
    if not ENV_FILE.exists():
        sys.exit(f"ERROR: {ENV_FILE} not found and no GROK_IMAGINE_API_KEY / XAI_API_KEY in env")
    for raw in ENV_FILE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        for prefix in ("GROK_IMAGINE_API_KEY=", "XAI_API_KEY="):
            if line.startswith(prefix):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("ERROR: GROK_IMAGINE_API_KEY not found in .env")


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", "-n", type=int, default=3,
                        help="Candidates to generate (default 3)")
    args = parser.parse_args()

    api_key = load_env()

    print(f"→ requesting {args.candidates} candidate(s) ({MODEL}, {ASPECT}, {RESOLUTION})")
    data = call_api(api_key, PROMPT, args.candidates)
    items = data.get("data", [])
    if not items:
        print(f"  ⚠ No images in response: {json.dumps(data)[:400]}")
        sys.exit(1)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for i, item in enumerate(items):
        b64 = item.get("b64_json")
        if not b64:
            url = item.get("url")
            if not url:
                print(f"  ⚠ candidate {i+1} had neither b64_json nor url; skipping")
                continue
            with urllib.request.urlopen(url, timeout=120) as r:
                raw = r.read()
        else:
            raw = base64.b64decode(b64)
        out_path = OUT_DIR / f"food_card_illustration_v{i+1}.png"
        out_path.write_bytes(raw)
        size_kb = out_path.stat().st_size // 1024
        print(f"  ✓ {out_path.relative_to(REPO_ROOT)} ({size_kb} KB)")


if __name__ == "__main__":
    main()
