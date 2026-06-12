#!/usr/bin/env python3
"""v4.6 it-girl editorial cutout set (Grok Imagine -> Vision cutout).

Generates the her75-register Pinterest it-girl photo set for onboarding,
then runs scripts/cutout.swift (compiled at /tmp/cutout) for true-alpha
sticker PNGs. Faces stay obscured per the Direction A guardrail:
sunglasses, from behind, eyes down, or cropped. Idempotent per file.

Run: python3 scripts/generate_itgirl_set.py
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
    "visible and isolated on a SOLID FLAT cream background, edge to edge, "
    "no other background elements, no surface line, no horizon, no text, "
    "no watermark. Subject fills most of the frame like a die-cut sticker."
)

PROMPTS = {
    # psychometric yes/no accents (171 / 172 / 173)
    "psych_water": (
        "A stylish young woman in profile drinking from a clear glass water "
        "bottle, narrow black sunglasses, tortoiseshell claw clip in dark "
        "hair, ribbed neutral tank."
    ),
    "psych_hoodie": (
        "A young woman seen fully from behind wearing an oversized cream "
        "hoodie and bike shorts, messy high bun, small gold hoops, relaxed "
        "stance, weight on one hip."
    ),
    "psych_stretch": (
        "A young woman seen from behind sitting on the floor in a side "
        "stretch, matching oatmeal ribbed workout set, low bun, bare feet."
    ),
    # reshape screen replacement (AI character out)
    "reshape_set": (
        "A young woman standing relaxed, photographed fully FROM BEHIND, "
        "wearing a matching soft sage-green sports bra and high-waist "
        "leggings, sleek low ponytail, full body head to sneakers."
    ),
    # first-week screen accent
    "firstweek_sneaker": (
        "A young woman crouched down tying the laces of a white sneaker, "
        "seen from the side with her face hidden by falling hair, matching "
        "beige workout set, gold bracelet."
    ),
    # pre-eat teach (snap before you eat)
    "preeat_snap": (
        "Two elegant female hands with neutral manicure holding a phone "
        "horizontally, photographing a colorful grain bowl with salmon and "
        "avocado on a small plate below, shot from a three-quarter top angle."
    ),
    # identity grid (radiant reuses the bake-off headphones girl)
    "identity_powerful": (
        "A young woman mid-stride walking confidently, narrow black "
        "sunglasses, slicked-back bun, oversized blazer over a fitted "
        "bodysuit and leggings, holding a slim water bottle, full body."
    ),
    "identity_calm": (
        "A young woman in a cream waffle robe holding a ceramic matcha bowl "
        "with both hands near her face, eyes closed, hair in a loose towel "
        "wrap, serene, shoulders-up crop."
    ),
    "identity_light": (
        "A young woman walking with a canvas tote bag and an iced coffee, "
        "airy white linen shirt over a tank, loose low bun catching motion, "
        "face turned away from camera, full body."
    ),
    "identity_strong": (
        "Close crop of a woman's legs on a pilates reformer wearing sand "
        "colored ankle weights and grip socks, one leg extended, controlled "
        "form, warm skin tone."
    ),
    # cohort huddle refresh
    "cohort_juice": (
        "A young woman from the shoulders up holding a green juice in a "
        "glass bottle near her chin, narrow sunglasses pushed up in glossy "
        "dark hair, face angled down and away."
    ),
    "cohort_fruit": (
        "A young woman from the shoulders up about to bite a slice of "
        "cantaloupe melon, oversized black sunglasses covering her eyes, "
        "gold chain necklace, green bikini top."
    ),
    "cohort_pearl": (
        "A young woman photographed from behind, sleek low bun with a small "
        "pearl claw clip, single pearl earring, white ribbed tank, holding "
        "a phone loosely at her side."
    ),
    # welcome accent (device-frame demo screen garnish)
    "welcome_journal": (
        "A flat-lay style shot of an open habit tracker journal with neat "
        "handwritten checkmarks, a gold pen resting across it, and a small "
        "glass of matcha beside it, slight top-down angle."
    ),
}


def gen(name, prompt, retries=3):
    raw = os.path.join(RAW, f"{name}.jpg")
    cut = os.path.join(CUT, f"{name}.png")
    if os.path.exists(cut):
        return f"skip {name}"
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


with futures.ThreadPoolExecutor(max_workers=4) as ex:
    for result in ex.map(lambda kv: gen(*kv), PROMPTS.items()):
        print(result)
print("all done")
