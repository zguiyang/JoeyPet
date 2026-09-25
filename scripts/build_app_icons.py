#!/usr/bin/env python3
"""Generate AppIcon.appiconset PNGs from app-logo.png (content-bounds fit square, no crop of logo)."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

SOURCE = Path("/Users/joyzhao/Downloads/joeypet_pics/app-logo.png")
ICONSET = Path(__file__).resolve().parents[1] / "src/JoeyPet/Assets.xcassets/AppIcon.appiconset"
MASTER_OUT = Path(__file__).resolve().parent / "output/app_icon_master_square.png"

SLOTS = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def alpha_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    alpha = img.split()[3]
    box = alpha.getbbox()
    if box is None:
        return (0, 0, img.width, img.height)
    return box


def visual_bbox(img: Image.Image, alpha_threshold: int = 32) -> tuple[int, int, int, int]:
    """Tight bbox of visible pixels; ignores wide low-alpha fringe in source exports."""
    alpha = img.split()[3]
    mask = alpha.point(lambda p: 255 if p > alpha_threshold else 0)
    box = mask.getbbox()
    if box is None:
        return alpha_bbox(img)
    return box


def fit_square_master(
    img: Image.Image,
    canvas_side: int = 1024,
    target_fill: float = 0.85,
) -> Image.Image:
    """Center logo visual主体 on a square canvas at optical size (no extra % padding)."""
    box = visual_bbox(img)
    content = img.crop(box)
    cw, ch = content.size
    content_max = max(cw, ch)
    scale = (target_fill * canvas_side) / content_max
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    scaled = content.resize((new_w, new_h), Image.Resampling.LANCZOS)
    square = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
    paste_x = (canvas_side - new_w) // 2
    paste_y = (canvas_side - new_h) // 2
    square.paste(scaled, (paste_x, paste_y), scaled)
    return square


def main() -> None:
    img = Image.open(SOURCE).convert("RGBA")
    square = fit_square_master(img)
    MASTER_OUT.parent.mkdir(parents=True, exist_ok=True)
    square.save(MASTER_OUT)

    ICONSET.mkdir(parents=True, exist_ok=True)
    for filename, side in SLOTS:
        out = square.resize((side, side), Image.Resampling.LANCZOS)
        out.save(ICONSET / filename)

    contents = {
        "images": [
            {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
            {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
            {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
            {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
            {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
            {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
            {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
            {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
            {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
            {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
        ],
        "info": {"author": "xcode", "version": 1},
    }

    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    loose = alpha_bbox(img)
    tight = visual_bbox(img)
    master_bb = alpha_bbox(square)
    fill_pct = round(max(master_bb[2] - master_bb[0], master_bb[3] - master_bb[1]) / square.width * 100, 1)
    print(
        f"Source {img.size[0]}x{img.size[1]}, loose {loose[2]-loose[0]}x{loose[3]-loose[1]}, "
        f"visual {tight[2]-tight[0]}x{tight[3]-tight[1]}, master {square.size[0]}x{square.size[1]} "
        f"fill {fill_pct}% -> {ICONSET}"
    )


if __name__ == "__main__":
    main()
