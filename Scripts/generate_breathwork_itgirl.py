#!/usr/bin/env python3
"""Breathwork preview it-girl cutout candidates.

Run: python3 scripts/generate_breathwork_itgirl.py
"""
import base64
import concurrent.futures as futures
import json
import os
import subprocess
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "generated_illustrations", "breathwork_itgirl", "raw")
CUT = os.path.join(ROOT, "generated_illustrations", "breathwork_itgirl", "cut")
os.makedirs(RAW, exist_ok=True)
os.makedirs(CUT, exist_ok=True)


def env_key(name):
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"missing {name}")


GROK_KEY = env_key("GROK_IMAGINE_API_KEY")

STYLE = (
    " Editorial photograph for a luxury women's wellness magazine, pinterest "
    "it-girl aesthetic, shot on film, warm natural light, soft shadows, "
    "expensive minimal styling, quiet luxury. The ENTIRE subject fully "
    "inside the frame occupying about two thirds of the frame with generous "
    "empty cream margin around it, on a SOLID FLAT cream background, edge "
    "to edge, no other background elements, no surface line, no horizon, "
    "no text, no watermark."
)

PROMPTS = {
    "breathe_exhale": (
        "A young woman from the shoulders up, eyes closed, chin lifted "
        "slightly, serene mid-exhale expression, one hand resting flat on "
        "her chest, glossy slicked bun, thin gold necklace, cream ribbed "
        "tank top, deeply calm."
    ),
    "breathe_sweater": (
        "A young woman from the chest up, eyes closed and peaceful, head "
        "tilted gently to one side, wrapped in an oversized cream knit "
        "sweater with sleeves over her hands, tortoiseshell claw clip, "
        "soft relaxed shoulders."
    ),
    "breathe_profile": (
        "A young woman in side profile from the shoulders up, eyes closed, "
        "face tilted up toward soft light, calm slow-breathing expression, "
        "low loose bun with face-framing strands, small pearl earring, "
        "silk cream camisole."
    ),
    "breathe_floor": (
        "A young woman sitting cross-legged seen from the side, full body, "
        "eyes closed, hands resting loosely on her knees, oversized cream "
        "sweatshirt and soft beige shorts, white crew socks, relaxed "
        "posture, peaceful."
    ),
}


def gen(name, prompt, retries=3):
    raw = os.path.join(RAW, f"{name}.jpg")
    cut = os.path.join(CUT, f"{name}.png")
    if not os.path.exists(raw):
        body = {
            "model": "grok-imagine-image-quality",
            "prompt": prompt + STYLE,
            "response_format": "b64_json",
        }
        for attempt in range(retries):
            try:
                req = urllib.request.Request(
                    "https://api.x.ai/v1/images/generations",
                    data=json.dumps(body).encode(),
                    headers={
                        "Authorization": f"Bearer {GROK_KEY}",
                        "Content-Type": "application/json",
                    },
                )
                with urllib.request.urlopen(req, timeout=180) as resp:
                    data = json.load(resp)
                img = base64.b64decode(data["data"][0]["b64_json"])
                with open(raw, "wb") as f:
                    f.write(img)
                break
            except Exception as e:
                if attempt == retries - 1:
                    print(f"FAIL {name}: {e}")
                    return
    r = subprocess.run(["/tmp/cutout", raw, cut], capture_output=True, text=True)
    print(f"{name}: {'cut ok' if r.returncode == 0 else r.stdout + r.stderr}")


if __name__ == "__main__":
    if not os.path.exists("/tmp/cutout"):
        subprocess.run(
            ["swiftc", "-O", os.path.join(ROOT, "scripts", "cutout.swift"),
             "-o", "/tmp/cutout"],
            check=True,
        )
    with futures.ThreadPoolExecutor(max_workers=4) as ex:
        list(ex.map(lambda kv: gen(*kv), PROMPTS.items()))
