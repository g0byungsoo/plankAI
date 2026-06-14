#!/usr/bin/env python3
"""Round-8 hand-caution pass — re-prompts every Grok hero photo whose
original scene featured visible hands. Default: hands hidden in long
sleeves, behind the body, in pockets, or cropped out of frame entirely.
Founder flagged D14 for "weird hand shape" 2026-06-13; this batch
preempts the same issue everywhere else.

Run: python3 scripts/regen_hands_hidden.py
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

VENV_PY = "/tmp/jenivenv/bin/python"

STYLE = (
    " Photographed on 35mm Portra 400 film, soft natural window light. "
    "Subject is a young woman, late 20s, cream/oatmeal/beige clothing, "
    "NO logos, NO jewelry. NO HANDS OR FINGERS VISIBLE ANYWHERE — "
    "either hidden in long sleeves past the wrists, in pockets, behind "
    "the body, or cropped out of frame. FACE COMPLETELY HIDDEN — "
    "photographed from BEHIND with full hair visible OR head tilted "
    "down so only the crown is in frame. Subject isolated against "
    "CLEAN SOLID cream backdrop #F5EFE3, edge to edge, no shadow on "
    "backdrop, no other people in frame, no AI-3D render. Editorial "
    "magazine still photography, Cereal / Acne Paper register."
)

# (slug, fresh scene that hides hands entirely)
TARGETS = [
    ("jm_hero_thought_record_d20",
     "A young woman seated at a small marble cafe table, photographed "
     "from BEHIND. A leather-bound notebook open on the table in front "
     "of her, a single espresso cup beside it. She is leaning forward "
     "over the page; her chunky cream cardigan has long sleeves that "
     "completely cover her hands — arms folded under her on the table, "
     "no fingers visible. Hair down loose past her shoulders, head bent."),

    ("jm_hero_sleep_appetite_d26",
     "A young woman lying on her side in a cream linen bed, photographed "
     "from BEHIND her shoulder. The duvet is pulled up to mid-shoulder; "
     "her tousled hair spreads on the cream pillow. No arms or hands "
     "visible — both arms tucked under the duvet. Soft morning light "
     "from a window left."),

    ("jm_hero_inner_critic_dialogue_d44",
     "A young woman seated at a small writing desk, photographed from "
     "DIRECTLY BEHIND. A brass lamp casts soft light over the desk and "
     "her hair. The desk surface holds an open notebook and a single "
     "fountain pen lying on the page (UNUSED, lying still). Her chunky "
     "cream knit sweater has very long sleeves; both arms rest under "
     "the desk edge, NO hands or fingers anywhere in the frame. Hair "
     "down loose in a low pony."),

    ("jm_hero_tracking_mirror_d22",
     "A young woman standing in soft profile next to a cream-painted "
     "wall, photographed from DIRECTLY BEHIND. A small leather notebook "
     "is propped open on a nearby shelf in front of her (NOT held). Her "
     "long cream cardigan has oversized sleeves that fall past where "
     "her wrists would be — both arms relaxed at her sides, NO hands "
     "visible. Hair half-up, soft side light."),

    ("jm_hero_social_food_d33",
     "A view from BEHIND the subject at a softly-lit dinner table, only "
     "her back and shoulders visible — no arms or hands in frame at all. "
     "Across the table are a few softly-blurred companions, faces "
     "completely unreadable, just background figures out of focus. "
     "Cream silk blouse, hair in a low loose pony. Warm candle-soft "
     "light, dinnerware blurred on the table."),

    ("jm_hero_values_conflict_d54",
     "A young woman seated on a cream linen couch, photographed from "
     "DIRECTLY BEHIND. Two open notebooks lie side by side on the "
     "coffee table in front of her, just visible past her shoulder. Her "
     "cream cashmere sweater has long sleeves; both arms folded across "
     "her lap, hidden inside the sleeves — NO hands visible. Hair in a "
     "half-up, head bent down toward the notebooks."),

    ("jm_hero_what_your_body_did_d55",
     "A young woman seated with her legs tucked under her on a cream "
     "armchair, photographed from BEHIND. Her chunky cream knit top "
     "has long oversized sleeves that completely cover her arms; both "
     "arms fold across her lap, NO hands visible. Hair down loose past "
     "her shoulders. Head tipped slightly back into the chair, soft "
     "window light from her right."),

    ("jm_hero_high_risk_d67",
     "A young woman at a wooden desk, photographed from DIRECTLY BEHIND. "
     "An open paper monthly calendar laid flat on the desk in front of "
     "her (a few dates lightly circled in ink, but pen NOT held). A "
     "linen-bound notebook closed beside it. Cream wall behind, soft "
     "daylight. Cream oversized sweater with long sleeves; both arms "
     "rest below the desk edge, NO hands or fingers anywhere in frame. "
     "Hair in a low loose pony, head bent down."),

    ("jm_hero_regulator_skills_d71",
     "A young woman seated cross-legged on a cream rug, photographed "
     "from DIRECTLY BEHIND. Her cream long-sleeve top has very long "
     "sleeves that completely cover her arms; both arms wrap loosely "
     "around her own torso in a self-hug, hidden inside the sleeves — "
     "NO hands or fingers visible. Hair in a long loose braid down her "
     "back. Soft morning light."),

    ("jm_hero_holiday_plan_d69",
     "A view from BEHIND the subject at a softly-lit holiday dinner "
     "table; only her back and shoulders visible — no arms or hands "
     "in frame. Other people blurred completely in background, faces "
     "not readable. Cream silk blouse, hair in a low pony. Warm candle "
     "light, decorated table with greenery just visible past her "
     "shoulder."),

    ("jm_hero_weekly_review_d35",
     "A young woman at a cream-stone kitchen table, photographed from "
     "DIRECTLY BEHIND. A small stack of opened notebooks lies on the "
     "table; a single mug of coffee beside them. Cream oversized "
     "sweater with sleeves past the wrists; arms folded under the "
     "table, NO hands or fingers visible. Hair in a low bun, head "
     "bent forward."),

    ("jm_hero_lifetime_plan_d82",
     "A young woman seated on a cream-stone garden bench in soft "
     "morning light, photographed from DIRECTLY BEHIND. A small open "
     "notebook lies on her lap, a fountain pen resting beside it on "
     "the bench (NOT held). Long oatmeal cardigan with sleeves past "
     "the wrists; arms fold inside the cardigan around her own waist, "
     "NO hands visible. Hair down loose, head bent slightly forward."),
]


def env_key(name):
    for line in open(os.path.join(ROOT, ".env")):
        if line.startswith(name + "="):
            return line.split("=",1)[1].strip().strip('"').strip("'")


GROK = env_key("GROK_IMAGINE_API_KEY")


def gen_one(slug, scene):
    raw = os.path.join(RAW, f"{slug}.jpg")
    cut = os.path.join(CUT, f"{slug}.png")
    # Delete old to force regen
    for p in (raw, cut):
        if os.path.exists(p):
            os.remove(p)
    body = {"model":"grok-imagine-image-quality",
            "prompt": scene + STYLE,
            "response_format":"b64_json"}
    for attempt in range(3):
        try:
            req = urllib.request.Request(
                "https://api.x.ai/v1/images/generations",
                json.dumps(body).encode(),
                {"Content-Type":"application/json",
                 "Authorization":f"Bearer {GROK}"})
            with urllib.request.urlopen(req, timeout=300) as r:
                d = json.load(r)
            img = d.get("data",[{}])[0].get("b64_json")
            if not img: return f"{slug}: NO IMAGE"
            open(raw,"wb").write(base64.b64decode(img))
            break
        except Exception as e:
            if attempt == 2: return f"{slug}: {e}"
    r = subprocess.run(["/tmp/cutout", raw, cut], capture_output=True, text=True)
    if r.returncode != 0:
        return f"{slug}: cutout {r.stderr[:200]}"
    trim = subprocess.run([VENV_PY, "-c", f"""
from PIL import Image
img = Image.open('{cut}').convert('RGBA')
bb = img.split()[-1].point(lambda x: 255 if x > 10 else 0).getbbox()
if bb and bb != (0,0,*img.size):
    img.crop(bb).save('{cut}', optimize=True)
"""], capture_output=True, text=True)
    if trim.returncode != 0:
        return f"{slug}: trim {trim.stderr[:200]}"
    dst = os.path.join(ASSETS, f"{slug}.imageset", f"{slug}.png")
    subprocess.run(["cp", cut, dst], check=True)
    return f"done {slug}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--parallel", type=int, default=4)
    args = ap.parse_args()
    print(f"Regenerating {len(TARGETS)} hand-visible photos with hands hidden...")
    with futures.ThreadPoolExecutor(max_workers=args.parallel) as ex:
        for r in ex.map(lambda t: gen_one(*t), TARGETS):
            print(r)


if __name__ == "__main__":
    main()
