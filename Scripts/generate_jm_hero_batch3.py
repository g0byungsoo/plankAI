#!/usr/bin/env python3
"""Batch 3 — remaining 22 lessons that still use generic onb-itgirl-*
assets. Same Grok pipeline as batch2, same guardrails (face obscured,
neutral garments, 35mm Portra). After generation, also rewrites
manifest_v1.json so each day points at its new slug.

Run: python3 scripts/generate_jm_hero_batch3.py
"""
import argparse
import base64
import concurrent.futures as futures
import json
import os
import subprocess
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "generated_illustrations", "jenimethod_v2", "raw")
CUT = os.path.join(ROOT, "generated_illustrations", "jenimethod_v2", "cut")
ASSETS = os.path.join(ROOT, "PlankApp", "Assets.xcassets")
MANIFEST = os.path.join(ROOT, "PlankApp", "Resources", "manifest_v1.json")
os.makedirs(RAW, exist_ok=True)
os.makedirs(CUT, exist_ok=True)

VENV_PY = "/tmp/jenivenv/bin/python"

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
    "edge to edge, no other people in frame, no shadow on backdrop. "
    "Editorial magazine still photography, Cereal / Acne Paper register."
)

# (day, slug, scene)
TARGETS = [
    (4,  "jm_hero_automatic_thoughts_d4",
     "A young woman seated at the edge of a cream-linen bed in soft "
     "morning light, hands folded loosely in her lap, gaze toward the "
     "window. Cream long-sleeve top, hair tied back. Composition: "
     "side profile from her left, shoulders to chest visible, eyes "
     "and forehead cropped above the frame."),

    (10, "jm_hero_category_error_d10",
     "A young woman at a soft kitchen counter, two small ceramic plates "
     "in front of her — one with a single croissant, one with sliced "
     "fruit. Her hands rest open beside the plates, no judgment. Cream "
     "cardigan, hair in a low bun. Composition: top-down 3/4, hands and "
     "lower crown of head visible, no face."),

    (22, "jm_hero_tracking_mirror_d22",
     "A young woman holding a small leather notebook open in her left "
     "hand and a fountain pen in her right, standing relaxed near a "
     "cream-painted wall. She is looking down at the page. Oatmeal "
     "knit, hair in a half-up. Composition: 3/4 from her right side, "
     "shoulders to waist visible, head leaning down so face is hidden."),

    (23, "jm_hero_if_then_d23",
     "A young woman seated cross-legged on a cream rug, a small slate "
     "card balanced on her knee with handwriting visible but blurred. "
     "She is reading the card, hair falling forward to obscure her face. "
     "Cream sweater, oatmeal trousers. Composition: 3/4 from the front-"
     "right, hair conceals the entire face."),

    (33, "jm_hero_social_food_d33",
     "A young woman seated at a long candlelit dinner table among "
     "softly-blurred companions, holding a small wine glass. The "
     "background figures are heavily out of focus, completely unreadable. "
     "Cream silk blouse, low loose pony. Composition: 3/4 from behind "
     "the subject's right shoulder, only her back and side of head "
     "visible — no faces anywhere in frame."),

    (35, "jm_hero_weekly_review_d35",
     "A young woman at a cream-stone kitchen table reviewing a small "
     "stack of opened notebooks, a single mug of coffee beside her. "
     "She is tracing a finger down a column on the page, fully "
     "concentrated. Oatmeal sweater, hair in a low bun. Composition: "
     "top-down 3/4, her hands and the back of her head visible."),

    (36, "jm_hero_maintainers_morning_d36",
     "A young woman standing at a sunlit window in a quiet bedroom, "
     "holding a warm ceramic mug in both hands, looking out. Soft "
     "morning light wraps her silhouette. Long cream sleep tee, hair "
     "loose. Composition: from behind, full back and shoulders and "
     "back of head visible, face not in frame."),

    (41, "jm_hero_plateau_script_d41",
     "A young woman seated at a small writing desk under a brass lamp, "
     "head resting on one hand, pen lying on the open page in front of "
     "her. The scene reads as paused, mid-thought. Cream chunky-knit "
     "sweater. Composition: side profile from the left, elbow on desk, "
     "lower half of face hidden by the propping hand."),

    (47, "jm_hero_body_neutrality_d47",
     "A young woman standing barefoot on a cream rug in front of a "
     "soft-lit window, hands at her sides, weight even. She is wearing "
     "a simple cream slip dress, hair down loose. Composition: from "
     "behind, full back and shoulders and back of head visible, no face."),

    (48, "jm_hero_self_as_context_d48",
     "A young woman seated cross-legged on a cream meditation cushion, "
     "hands resting palms-up on her knees, head slightly tilted forward. "
     "Cream linen pants and oatmeal long-sleeve top. Composition: 3/4 "
     "from the front-right, head tilted down so face is in shadow / out "
     "of frame."),

    (51, "jm_hero_comparison_snare_d51",
     "A young woman seated by a sunny window holding a closed phone "
     "face-down on the table beside her, looking out the window instead. "
     "Cream cardigan, hair in a low pony. Composition: side profile "
     "from her left, shoulders and lower head only, eyes lifted to "
     "window so face is in shadow."),

    (54, "jm_hero_values_conflict_d54",
     "A young woman seated on a cream linen couch, two open notebooks "
     "side by side on the coffee table in front of her, one finger "
     "resting on each. She is looking down between the two. Cream "
     "cashmere sweater, hair in a half-up. Composition: 3/4 top-down, "
     "her hands and crown of head visible, no face."),

    (55, "jm_hero_what_your_body_did_d55",
     "A young woman seated with her legs tucked under her on a cream "
     "armchair, one hand resting flat on her chest, the other on her "
     "thigh. Eyes closed, head tipped slightly back into the chair. "
     "Cream knit top, oatmeal trousers. Composition: 3/4 from her "
     "right side, shoulders to waist visible, face mostly in shadow."),

    (60, "jm_hero_body_image_continuum_d60",
     "A young woman seated on the floor of a sunlit bedroom in front "
     "of a full-length mirror leaning against the wall — but the mirror "
     "is angled so it reflects only the cream wall, not her body. She "
     "is wrapping her arms loosely around her bent knees. Cream slip "
     "top and shorts. Composition: from behind, only her back and back "
     "of head visible."),

    (66, "jm_hero_maintainers_daily_three_d66",
     "A young woman standing at a small kitchen counter, three small "
     "ceramic vessels in front of her — a water glass, a coffee mug, a "
     "small bowl of fruit. Her hands rest on the counter between them. "
     "Cream oversized sweater. Composition: top-down 3/4, only the "
     "hands and crown of head visible."),

    (69, "jm_hero_holiday_plan_d69",
     "A young woman at a softly-lit holiday dinner table, holding a "
     "small dessert plate in both hands, paused mid-bite. Other people "
     "blurred completely in background, faces not readable. Cream silk "
     "blouse, hair in a low pony. Composition: side profile from her "
     "right, shoulders to chest visible, eyes lowered to plate."),

    (71, "jm_hero_regulator_skills_d71",
     "A young woman seated on a cream rug, eyes closed, one hand on her "
     "belly and one hand on her chest, in a soft body-scan posture. "
     "Cream long-sleeve top, oatmeal linen pants. Composition: 3/4 from "
     "the front-right, eyes closed, hair falling forward over the face."),

    (74, "jm_hero_if_you_regain_d74",
     "A young woman walking forward unhurried in soft golden light "
     "outdoors on a cream-stone path, hands relaxed at her sides. Long "
     "oatmeal coat, hair down loose. Composition: from directly behind, "
     "full back and shoulders and back of head visible, no face."),

    (76, "jm_hero_critic_ongoing_d76",
     "A young woman at a cream-painted vanity, applying tinted lip "
     "balm with a small wand brush. She is looking at her hands in her "
     "lap, not at the mirror. The mirror's reflection is angled so it "
     "shows only the cream wall behind. Cream cardigan, hair half-up. "
     "Composition: 3/4 from her left, only chin and below visible."),

    (78, "jm_hero_body_keeps_changing_d78",
     "A young woman seated at the edge of an unmade cream linen bed in "
     "morning light, one hand resting on her thigh, the other in her "
     "hair pushing it back. Cream slip top. Composition: from behind-"
     "right, shoulder and back of head visible, no face."),

    (80, "jm_hero_every_january_d80",
     "A young woman walking past a row of brightly-lit storefront "
     "windows on a quiet sidewalk in the early evening, hands in pockets. "
     "Long cream coat, hair loose. Composition: from directly behind, "
     "back and shoulders and back of head visible, no face, no readable "
     "signage in the storefront windows."),

    (82, "jm_hero_lifetime_plan_d82",
     "A young woman at a cream-stone garden bench in soft morning light, "
     "a small open notebook on her knee, fountain pen mid-air. She is "
     "looking down at the page, head bent. Long oatmeal cardigan. "
     "Composition: 3/4 from her right, shoulders and crown of head "
     "visible, no face."),
]


def env_key(name):
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"missing {name}")


GROK_KEY = env_key("GROK_IMAGINE_API_KEY")


def gen_one(day, slug, scene):
    raw = os.path.join(RAW, f"{slug}.jpg")
    cut = os.path.join(CUT, f"{slug}.png")
    prompt = scene + STYLE
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
        r = subprocess.run(["/tmp/cutout", raw, cut],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return f"{slug}: cutout failed {(r.stdout + r.stderr)[:200]}"

    trim = subprocess.run([VENV_PY, "-c", f"""
from PIL import Image
img = Image.open('{cut}').convert('RGBA')
bbox = img.split()[-1].point(lambda x: 255 if x > 10 else 0).getbbox()
if bbox and bbox != (0,0,*img.size):
    img.crop(bbox).save('{cut}', optimize=True)
"""], capture_output=True, text=True)
    if trim.returncode != 0:
        return f"{slug}: trim err {trim.stderr[:200]}"

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
    """Smart horizontal anchor for the PNG (0..1). Combines alpha-
    weighted centroid with L/R 20% band-mass asymmetry. If one side
    is >15% heavier, anchor to it (xPct = 0.20 or 0.80). Otherwise
    use the centroid. Stored in the manifest's xPct field so
    LayoutArchetypeView can pick .leading / .center / .trailing per
    asset and avoid the "side cut" issue when scaledToFit centers a
    wider-than-tall composition."""
    from PIL import Image
    p = os.path.join(ASSETS, f"{slug}.imageset", f"{slug}.png")
    if not os.path.exists(p):
        return 0.5
    img = Image.open(p).convert("RGBA")
    w, h = img.size
    alpha = img.split()[-1]
    # L/R 20% band mass
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
    if asym > 0.15:
        return 0.20
    if asym < -0.15:
        return 0.80
    # Centroid fallback
    total = 0.0
    weighted = 0.0
    for x in range(0, w, 4):
        col = [alpha.getpixel((x, y)) for y in range(0, h, 8)]
        m = sum(a for a in col if a > 50)
        total += m
        weighted += m * x
    return round(weighted / total / w, 3) if total > 0 else 0.5


def rewrite_manifest():
    data = json.load(open(MANIFEST))
    updates = 0
    by_day = {d: slug for (d, slug, _) in TARGETS}
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
                    # Always recompute centroid after regen.
                    slots[0]["xPct"] = round(asset_centroid_x(slug), 3)
                    updates += 1
    json.dump(data, open(MANIFEST, "w"), indent=2)
    return updates


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--parallel", type=int, default=4)
    args = ap.parse_args()
    print(f"Generating {len(TARGETS)} hero photos (parallel={args.parallel})...")
    with futures.ThreadPoolExecutor(max_workers=args.parallel) as ex:
        for r in ex.map(lambda t: gen_one(*t), TARGETS):
            print(r)
    n = rewrite_manifest()
    print(f"manifest updated: {n} entries")


if __name__ == "__main__":
    main()
