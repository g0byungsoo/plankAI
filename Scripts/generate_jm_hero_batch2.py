#!/usr/bin/env python3
"""Round-8 priority hero photo batch — generates 11 topic-matched
editorial portraits via Grok Imagine, runs Vision cutout for true
alpha, trims transparent margins, promotes into Assets.xcassets, and
rewrites manifest_v1.json so the matching lesson day points at the
new slug.

The "her75 editorial" register guardrails are baked into every prompt:
faces obscured (from behind / cropped at chin / sunglasses / eyes
closed), warm natural light, neutral garments, no AI-3D look, no
licensed-stock pose, 35mm film grain.

Run: python3 scripts/generate_jm_hero_batch2.py [--dry] [--only D21]
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
ASSETS = os.path.join(ROOT, "PlankApp", "Assets.xcassets")
MANIFEST = os.path.join(ROOT, "PlankApp", "Resources", "manifest_v1.json")
os.makedirs(RAW, exist_ok=True)
os.makedirs(CUT, exist_ok=True)

VENV_PY = "/tmp/jenivenv/bin/python"  # for PIL trim

# Common scaffolding appended to every prompt — keeps the register
# consistent and reinforces the cutout-friendly background.
STYLE = (
    " Photographed on 35mm Portra 400 film, soft natural window light, "
    "shallow depth of field. Subject is a young woman in her late 20s, "
    "neutral cream / oatmeal / soft beige clothing, NO logos, NO patterns, "
    "NO jewelry. FULL HEAD AND HAIR CLEARLY VISIBLE — face hidden by "
    "BEHIND-CAMERA angle (back of head visible, no chin/jaw in frame) or "
    "by hair falling forward. NO HANDS OR FINGERS VISIBLE — hidden inside "
    "long sleeves past the wrists, in pockets, behind the body, or "
    "cropped out of frame. No mascot illustration look, no AI-3D render. "
    "Subject isolated against a CLEAN SOLID cream backdrop #F5EFE3, "
    "edge to edge, no other people, no shadow on backdrop. Editorial "
    "magazine still photography, Cereal magazine / Acne Paper register."
)

# (day, slug, headline_topic, scene_prompt)
TARGETS = [
    (1,  "jm_hero_diet_brain_learned_d1",
     "the voice in your head was taught",
     "A young woman seated at a sunlit kitchen table early morning, a "
     "linen-bound journal open in front of her with a fountain pen "
     "resting on the page, a single mug of black coffee beside it. She "
     "is hunched forward thoughtfully, weight on her forearms, looking "
     "down at the page. Cream knit sweater, hair in a loose low bun. "
     "Composition: 3/4 from behind-left, shoulders and lower head only, "
     "no face visible."),

    (7,  "jm_hero_diet_history_d7",
     "what diets actually did to you",
     "A young woman sitting cross-legged on unmade cream linen bedding, "
     "an open photo album in her lap, a few loose old polaroids scattered "
     "around her. She is looking down at the album, hair falling forward. "
     "Soft morning light from a window left, warm cream walls behind. "
     "Composition: from behind, only shoulders and back of head visible."),

    (14, "jm_hero_self_compassion_d14",
     "self-compassion is not self-indulgence",
     "A young woman seated upright in a cream-upholstered chair, one "
     "hand resting flat over her heart, the other in her lap. Eyes "
     "closed, head slightly tilted toward the heart-hand. Cream cashmere "
     "sweater, hair in a low loose pony. Soft window light from the "
     "right. Composition: 3/4 profile from her right side, chin and "
     "below visible, face from the bridge of nose up cropped out."),

    (20, "jm_hero_thought_record_d20",
     "thought record live",
     "A young woman writing in a leather-bound notebook on a small "
     "marble cafe table, a black ballpoint pen in her right hand. A "
     "single espresso cup and a small water glass beside the notebook. "
     "She is bent over the page, full attention down. Cream cardigan, "
     "loose hair to her shoulders. Composition: top-down 3/4 angle, "
     "her hands and forearms and crown of head visible — no face."),

    (26, "jm_hero_sleep_appetite_d26",
     "sleep is half your appetite",
     "A young woman waking in a cream linen bed, half-sitting up, one "
     "hand pushing tousled hair back from her brow. Soft morning light "
     "streaming in from a window left. Cream slip top, oatmeal bedding "
     "rumpled around her. Composition: from behind-right, shoulder and "
     "back of head visible, no face."),

    (29, "jm_hero_movement_mood_d29",
     "movement as mood, not punishment",
     "A young woman walking outdoors on a quiet cream-stone path, "
     "golden-hour light from the side. She wears a long oatmeal "
     "cardigan and wide cream linen trousers, hair tied back loose. "
     "Walking unhurried, looking ahead. Composition: from behind, full "
     "back and shoulders visible, no face."),

    (30, "jm_hero_stress_chain_d30",
     "the stress eating chain",
     "A young woman standing in a soft minimal kitchen, holding the "
     "open refrigerator door, paused mid-reach. Soft fridge-light "
     "spilling out, cream cabinets behind. Cream oversized sweater, "
     "hair in a low bun. Composition: 3/4 from behind-right, shoulders "
     "and lower head only, face not visible."),

    (44, "jm_hero_inner_critic_dialogue_d44",
     "the inner critic dialogue",
     "A young woman at a small writing desk under a low brass lamp, "
     "writing a letter on cream stationery with a fountain pen. A few "
     "torn-out journal pages folded beside her. She is fully bent into "
     "the page, hair falling forward over her face. Composition: "
     "side-profile from the right at desk height, hand and forearm "
     "visible, hair conceals face."),

    (50, "jm_hero_social_mirror_d50",
     "the social mirror work",
     "A young woman at a quiet cafe table with one other friend across "
     "from her, both holding warm cups in both hands. Soft window light. "
     "Cream linen blouse on the subject, loose low pony. Composition: "
     "from behind the subject, only her back and the side of her head "
     "visible — the friend across the table is heavily blurred / out of "
     "focus, no face readable."),

    (67, "jm_hero_high_risk_d67",
     "high-risk situations mapped",
     "A young woman at a desk with a paper monthly calendar laid open "
     "in front of her, a black pen in her hand, several dates lightly "
     "circled. A linen-bound notebook closed beside it. Cream wall "
     "behind, soft daylight. Composition: 3/4 top-down, her hands and "
     "the crown of her head visible — face cropped out at the eyebrows."),

    (83, "jm_hero_quiet_identity_d83",
     "the quiet identity",
     "A young woman walking unhurried away from camera down a quiet "
     "sunlit cream-stone path, soft early-morning light from the front "
     "casting a long shadow back. She wears a long oatmeal cashmere "
     "coat, hair tied back loose. Composition: from directly behind, "
     "her full back and the back of her head visible, no face."),
]


def env_key(name):
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"missing {name}")


GROK_KEY = env_key("GROK_IMAGINE_API_KEY")


def gen_one(day, slug, topic, scene, dry=False):
    raw = os.path.join(RAW, f"{slug}.jpg")
    cut = os.path.join(CUT, f"{slug}.png")
    prompt = scene + STYLE
    if dry:
        return f"DRY {slug}\n  topic: {topic}\n  prompt[:240]: {prompt[:240]}..."
    if not os.path.exists(cut):
        if not os.path.exists(raw):
            body = {
                "model": "grok-imagine-image-quality",
                "prompt": prompt,
                "response_format": "b64_json",
            }
            for attempt in range(3):
                try:
                    req = urllib.request.Request(
                        "https://api.x.ai/v1/images/generations",
                        json.dumps(body).encode(),
                        {"Content-Type": "application/json",
                         "Authorization": f"Bearer {GROK_KEY}"},
                    )
                    with urllib.request.urlopen(req, timeout=300) as r:
                        d = json.load(r)
                    img = d.get("data", [{}])[0].get("b64_json")
                    if not img:
                        return f"{slug}: NO IMAGE {json.dumps(d)[:200]}"
                    open(raw, "wb").write(base64.b64decode(img))
                    break
                except Exception as e:
                    if attempt == 2:
                        return f"{slug}: grok err {e}"
        r = subprocess.run(["/tmp/cutout", raw, cut], capture_output=True, text=True)
        if r.returncode != 0:
            return f"{slug}: cutout failed {(r.stdout + r.stderr)[:200]}"

    # Trim transparent margins via Pillow venv
    trim = subprocess.run([VENV_PY, "-c", f"""
from PIL import Image
img = Image.open('{cut}').convert('RGBA')
bbox = img.split()[-1].point(lambda x: 255 if x > 10 else 0).getbbox()
if bbox and bbox != (0,0,*img.size):
    img.crop(bbox).save('{cut}', optimize=True)
"""], capture_output=True, text=True)
    if trim.returncode != 0:
        return f"{slug}: trim err {trim.stderr[:200]}"

    # Promote to Assets.xcassets
    imgset = os.path.join(ASSETS, f"{slug}.imageset")
    os.makedirs(imgset, exist_ok=True)
    dst = os.path.join(imgset, f"{slug}.png")
    subprocess.run(["cp", cut, dst], check=True)
    contents = {
        "images": [{"filename": f"{slug}.png", "idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1},
    }
    json.dump(contents, open(os.path.join(imgset, "Contents.json"), "w"), indent=2)
    return f"done D{day} -> {slug}"


def asset_centroid_x(slug):
    """Smart horizontal anchor: L/R 20% band-mass asymmetry first,
    centroid fallback. Returns 0.20 / 0.80 for one-side-hugging
    subjects, otherwise the alpha-weighted x centroid."""
    from PIL import Image
    p = os.path.join(ASSETS, f"{slug}.imageset", f"{slug}.png")
    if not os.path.exists(p):
        return 0.5
    img = Image.open(p).convert("RGBA")
    w, h = img.size
    alpha = img.split()[-1]
    def band_mass(x_start, x_end):
        total = 0; count = 0
        for x in range(x_start, x_end, 2):
            col = [alpha.getpixel((x, y)) for y in range(0, h, 4)]
            total += sum(1 for a in col if a > 100)
            count += len(col)
        return total / count if count else 0
    L20 = band_mass(0, max(1, w // 5))
    R20 = band_mass(w - w // 5, w)
    asym = L20 - R20
    if asym > 0.15: return 0.20
    if asym < -0.15: return 0.80
    total = 0.0
    weighted = 0.0
    for x in range(0, w, 4):
        col = [alpha.getpixel((x, y)) for y in range(0, h, 8)]
        m = sum(a for a in col if a > 50)
        total += m
        weighted += m * x
    return round(weighted / total / w, 3) if total > 0 else 0.5


def rewrite_manifest():
    """Point each TARGETS day at its new slug + store the asset's
    alpha-weighted x centroid in `xPct` so LayoutArchetypeView can
    pick a per-photo horizontal anchor (.leading/.center/.trailing).
    Idempotent."""
    data = json.load(open(MANIFEST))
    updates = 0
    by_day = {d: slug for (d, slug, _, _) in TARGETS}
    for bucket in ("canonical84", "extension18"):
        for entry in data.get(bucket, []):
            day = entry.get("canonicalDay") or entry.get("extendedDay")
            if day not in by_day:
                continue
            slug = by_day[day]
            anchor = entry.get("anchor") or {}
            if anchor.get("archetype") == "bottom_bleed_hero":
                slots = anchor.get("archetypeSlots") or []
                if slots:
                    if slots[0].get("assetSlug") != slug:
                        slots[0]["assetSlug"] = slug
                    slots[0]["xPct"] = round(asset_centroid_x(slug), 3)
                    updates += 1
    json.dump(data, open(MANIFEST, "w"), indent=2)
    return updates


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", type=str, default="",
                    help="comma-separated day numbers, e.g. D14,D26")
    ap.add_argument("--manifest-only", action="store_true",
                    help="skip generation, only rewrite manifest pointers")
    ap.add_argument("--parallel", type=int, default=3)
    args = ap.parse_args()

    if args.manifest_only:
        n = rewrite_manifest()
        print(f"manifest updated: {n} entries")
        return

    targets = TARGETS
    if args.only:
        wanted = {x.lstrip("D").lstrip("d") for x in args.only.split(",")}
        targets = [t for t in TARGETS if str(t[0]) in wanted]

    print(f"Generating {len(targets)} hero photos (parallel={args.parallel})...")
    with futures.ThreadPoolExecutor(max_workers=args.parallel) as ex:
        for r in ex.map(lambda t: gen_one(*t, dry=args.dry), targets):
            print(r)

    if not args.dry:
        n = rewrite_manifest()
        print(f"manifest updated: {n} entries")


if __name__ == "__main__":
    main()
