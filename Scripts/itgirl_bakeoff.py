#!/usr/bin/env python3
"""it-girl cutout bake-off: Grok Imagine vs Gemini image models."""
import base64
import concurrent.futures as futures
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "generated_illustrations", "itgirl_test")
os.makedirs(OUT, exist_ok=True)


def env_key(name):
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"missing {name}")


GROK_KEY = env_key("GROK_IMAGINE_API_KEY")
GEM_KEY = env_key("GEMINI_API_KEY")

STYLE = (
    "Editorial photograph for a luxury women's wellness magazine, pinterest "
    "it-girl aesthetic, shot on film, warm natural light, soft shadows, "
    "expensive minimal styling. The ENTIRE subject fully visible and isolated "
    "on a SOLID FLAT cream background, exact hex #FDF6F4, edge to edge, no "
    "other background elements, no surface line, no horizon, no text, no "
    "watermark. Subject fills most of the frame like a die-cut sticker."
)

PROMPTS = {
    "headphones": (
        "A stylish young woman seen in profile from the shoulders up, wearing "
        "premium silver over-ear headphones, thin black tank top, narrow black "
        "sunglasses, sleek low bun, holding an iced latte in a clear cup near "
        "her chin. Face mostly turned away, editorial calm. " + STYLE
    ),
    "matcha": (
        "Two elegant female hands with neutral manicure whisking bright green "
        "matcha with a bamboo whisk in a ceramic bowl, gold bracelet on one "
        "wrist. " + STYLE
    ),
}


def post(url, payload, headers):
    req = urllib.request.Request(
        url, json.dumps(payload).encode(), {"Content-Type": "application/json", **headers}
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)


def gen_grok(name, prompt):
    f = os.path.join(OUT, f"grok_{name}.jpg")
    if os.path.exists(f):
        return f"skip {f}"
    d = post(
        "https://api.x.ai/v1/images/generations",
        {"model": "grok-imagine-image-quality", "prompt": prompt, "response_format": "b64_json"},
        {"Authorization": f"Bearer {GROK_KEY}"},
    )
    img = d.get("data", [{}])[0].get("b64_json")
    if not img:
        return f"GROK {name} FAIL: {json.dumps(d)[:200]}"
    open(f, "wb").write(base64.b64decode(img))
    return f"wrote {f}"


def gen_gemini(model, name, prompt):
    tag = model.replace(".", "_").replace("-", "_")
    f = os.path.join(OUT, f"{tag}_{name}.png")
    if os.path.exists(f):
        return f"skip {f}"
    try:
        d = post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GEM_KEY}",
            {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {
                    "responseModalities": ["IMAGE"],
                    "imageConfig": {"aspectRatio": "3:4"},
                },
            },
            {},
        )
        parts = d["candidates"][0]["content"]["parts"]
        img = next(p["inlineData"]["data"] for p in parts if "inlineData" in p)
    except Exception as e:  # surface API refusals readably
        return f"GEMINI {model} {name} FAIL: {e}"
    open(f, "wb").write(base64.b64decode(img))
    return f"wrote {f}"


jobs = []
with futures.ThreadPoolExecutor(max_workers=6) as ex:
    for name, prompt in PROMPTS.items():
        jobs.append(ex.submit(gen_grok, name, prompt))
        for model in ("gemini-3-pro-image", "gemini-3.1-flash-image"):
            jobs.append(ex.submit(gen_gemini, model, name, prompt))
    for j in futures.as_completed(jobs):
        print(j.result())
print("done")
