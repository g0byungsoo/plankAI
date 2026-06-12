#!/usr/bin/env python3
"""it-girl round 3: cohort marquee profiles + 286 sneakers regen + tree.

9 new shoulders-up profiles (12 total with juice/fruit/pearl) for the
rotating cohort marquee, a true-cutout replacement for the old
canvas-background sneakers on case 286, and a potted olive tree filler.

Run: python3 scripts/generate_itgirl_round3.py
"""
import base64
import concurrent.futures as futures
import json
import os
import subprocess
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "generated_illustrations", "itgirl_set", "raw")
CUT = os.path.join(ROOT, "generated_illustrations", "itgirl_set", "cut")


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

PROFILE = "A young woman from the shoulders up, "

PROMPTS = {
    "profile_latte":   PROFILE + "tortoiseshell claw clip, sipping an iced latte through a straw, eyes down.",
    "profile_cap":     PROFILE + "cream baseball cap and low ponytail, seen from three-quarter behind, gold hoop visible.",
    "profile_scarf":   PROFILE + "silk headscarf tied under the chin and narrow black sunglasses, vintage riviera mood.",
    "profile_bun":     PROFILE + "glossy slicked bun, thin gold necklace, face turned fully away in profile silhouette.",
    "profile_phone":   PROFILE + "holding a phone in front of her face taking a mirror photo, gold rings, face hidden by the phone.",
    "profile_smoothie":PROFILE + "drinking a deep pink berry smoothie from a glass, oversized sunglasses pushed into her hair, face angled down.",
    "profile_towel":   PROFILE + "white towel draped around her neck, flushed post-pilates glow, eyes closed, hair claw-clipped up.",
    "profile_braid":   PROFILE + "long neat braid over one shoulder, seen from behind at three-quarter angle, small pearl earring.",
    "profile_book":    PROFILE + "holding an open paperback book partially covering her face, oversized cream knit sweater.",
    # 286 replacement — flush-bottom bleed composition
    "sneakers_v2": (
        "A woman's two legs kicked straight up into the air wearing chunky "
        "white platform sneakers and soft beige crew socks, beige bike "
        "shorts, the thighs exiting the BOTTOM edge of the frame, legs and "
        "sneakers fully visible."
    ),
    # filler variety per founder (tree option)
    "filler_olivetree": (
        "A small potted olive tree in a cream ceramic pot, sculptural "
        "branches, a few fallen leaves at the base."
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
                    json.dumps(body).encode(),
                    {"Content-Type": "application/json", "Authorization": f"Bearer {GROK_KEY}"},
                )
                with urllib.request.urlopen(req, timeout=240) as r:
                    d = json.load(r)
                img = d.get("data", [{}])[0].get("b64_json")
                if not img:
                    return f"{name}: NO IMAGE {json.dumps(d)[:160]}"
                open(raw, "wb").write(base64.b64decode(img))
                break
            except Exception as e:
                if attempt == retries - 1:
                    return f"{name}: {e}"
    r = subprocess.run(["/tmp/cutout", raw, cut], capture_output=True, text=True)
    if r.returncode != 0:
        return f"{name}: cutout failed {r.stdout}{r.stderr}".strip()
    return f"done {name}"


# ensure the eroded-mask tool exists
if not os.path.exists("/tmp/cutout"):
    subprocess.run(
        ["swiftc", "-O", os.path.join(ROOT, "scripts", "cutout.swift"), "-o", "/tmp/cutout"],
        check=True,
    )

with futures.ThreadPoolExecutor(max_workers=4) as ex:
    for result in ex.map(lambda kv: gen(*kv), PROMPTS.items()):
        print(result)
print("all done")
