#!/usr/bin/env python3
"""Instance + rename the JeniFit hero cuts from Playfair Display variable.
Inputs:  PlayfairDisplay-var.ttf, PlayfairDisplay-Italic-var.ttf (Google Fonts)
Outputs: PlayfairDisplay-Hero.ttf (wght=650), PlayfairDisplay-HeroItalic.ttf (wght=620)
"""
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

# NOTE: OFL Reserved Font Name "Playfair Display" — modified cuts MUST NOT
# carry that name in any name-table field. Hence "Jeni Hero Serif".
JOBS = [
    ("/tmp/PlayfairDisplay-var.ttf", {"wght": 650},
     "Jeni Hero Serif", "Regular", "JeniHeroSerif-Regular",
     "/tmp/JeniHeroSerif-Regular.ttf"),
    ("/tmp/PlayfairDisplay-Italic-var.ttf", {"wght": 620},
     "Jeni Hero Serif", "Italic", "JeniHeroSerif-Italic",
     "/tmp/JeniHeroSerif-Italic.ttf"),
]

for src, axes, fam, sub, ps, out in JOBS:
    f = TTFont(src)
    instantiateVariableFont(f, axes, inplace=True)
    name = f["name"]
    full = f"{fam} {sub}" if sub != "Regular" else fam
    for nid, val in [(1, fam), (2, sub), (3, f"1.0;{ps}"), (4, full),
                     (6, ps), (16, fam), (17, sub)]:
        name.setName(val, nid, 3, 1, 0x409)
        name.setName(val, nid, 1, 0, 0)
    f.save(out)
    chk = TTFont(out)
    print(out, "->", chk["name"].getDebugName(6), "| weight", chk["OS/2"].usWeightClass,
          "| italic" if chk["head"].macStyle & 2 else "| roman")
