#!/usr/bin/env python3
"""Build Joey cat pet runtime spritesheet and copy reference PNGs (read-only source in Downloads)."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

SOURCE_DIR = Path("/Users/joyzhao/Downloads/joeypet_pics")
REPO_ROOT = Path(__file__).resolve().parents[1]
JOEY_PKG = REPO_ROOT / "src/JoeyPet/Resources/Pets/Joey"
QA_SHEET = REPO_ROOT / "scripts/output/joey_state_qa_sheet.png"

RUNTIME_STATES: list[tuple[str, str]] = [
    ("idle", "joey-idle.png"),
    ("blink", "joey-blink.png"),
    ("walking", "joey-walking.png"),
    ("sleeping", "joey-sleeping.png"),
    ("sweating", "joey-sweating.png"),
    ("tired", "joey-tired.png"),
    ("carryingTrash", "joey-carryingTrash.png"),
    ("cleaning", "joey-cleaning.png"),
    ("celebrating", "joey-celebrating.png"),
    ("notifying", "joey-notifying.png"),
]

REFERENCE_FILES = ["joey-front.png", "joey-side.png", "joey-back.png"]

CELL_SIZE = 256
DISPLAY_POINT_SIZE = 128
BODY_CENTER_FRACTION = 0.72
BODY_TARGET_FRACTION = 0.86

# Per-state tuning: scale multiplier on body height (not full alpha bbox).
STATE_BODY_SCALE: dict[str, float] = {
    "idle": 1.0,
    "walking": 1.0,
    "carryingTrash": 1.06,
    "cleaning": 1.02,
    "celebrating": 1.1,
    "notifying": 1.03,
}

STATE_OFFSET_Y: dict[str, int] = {
    "carryingTrash": -4,
    "cleaning": -2,
    "celebrating": 0,
    "notifying": 2,
}


def alpha_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    alpha = img.split()[3]
    box = alpha.getbbox()
    if box is None:
        return (0, 0, img.width, img.height)
    return box


def body_bbox(img: Image.Image, center_fraction: float = BODY_CENTER_FRACTION) -> tuple[int, int, int, int]:
    """Estimate torso bbox by ignoring wide props in the horizontal margins."""
    alpha = img.split()[3]
    w, h = img.size
    margin = (1.0 - center_fraction) / 2.0
    left = int(round(w * margin))
    right = int(round(w * (1.0 - margin)))
    sub = alpha.crop((left, 0, right, h))
    box = sub.getbbox()
    if box is None:
        return alpha_bbox(img)
    return (left + box[0], box[1], left + box[2], box[3])


def normalize_frame(img: Image.Image, anim_id: str, target_body_height: float) -> Image.Image:
    bb = body_bbox(img)
    body_h = max(1, bb[3] - bb[1])
    body_cx = (bb[0] + bb[2]) / 2.0
    body_cy = (bb[1] + bb[3]) / 2.0

    scale_mul = STATE_BODY_SCALE.get(anim_id, 1.0)
    scale = (target_body_height / body_h) * scale_mul
    new_w = max(1, int(round(img.width * scale)))
    new_h = max(1, int(round(img.height * scale)))
    scaled = img.resize((new_w, new_h), Image.Resampling.LANCZOS)

    scaled_bb = body_bbox(scaled)
    scaled_body_cx = (scaled_bb[0] + scaled_bb[2]) / 2.0
    scaled_body_cy = (scaled_bb[1] + scaled_bb[3]) / 2.0

    canvas = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    anchor_x = CELL_SIZE / 2.0
    anchor_y = CELL_SIZE / 2.0 + STATE_OFFSET_Y.get(anim_id, 0)
    paste_x = int(round(anchor_x - scaled_body_cx))
    paste_y = int(round(anchor_y - scaled_body_cy))
    canvas.paste(scaled, (paste_x, paste_y), scaled)
    return canvas


def write_qa_sheet(frames: list[tuple[str, Image.Image]]) -> None:
    QA_SHEET.parent.mkdir(parents=True, exist_ok=True)
    labels = 28
    cols = 5
    rows = (len(frames) + cols - 1) // cols
    pad = 8
    sheet_w = cols * (CELL_SIZE + pad) + pad
    sheet_h = rows * (CELL_SIZE + labels + pad) + pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (32, 32, 32, 255))
    from PIL import ImageDraw, ImageFont

    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (anim_id, frame) in enumerate(frames):
        col = index % cols
        row = index // cols
        x = pad + col * (CELL_SIZE + pad)
        y = pad + row * (CELL_SIZE + labels + pad)
        checker = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (48, 48, 48, 255))
        for cy in range(0, CELL_SIZE, 16):
            for cx in range(0, CELL_SIZE, 16):
                if (cx // 16 + cy // 16) % 2:
                    checker.putpixel((cx, cy), (64, 64, 64, 255))
        sheet.paste(checker, (x, y))
        sheet.paste(frame, (x, y), frame)
        draw.text((x, y + CELL_SIZE + 4), anim_id, fill=(220, 220, 220, 255), font=font)
    sheet.save(QA_SHEET)


def main() -> None:
    runtime_dir = JOEY_PKG / "runtime"
    source_dir = JOEY_PKG / "source"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    source_dir.mkdir(parents=True, exist_ok=True)

    for name in REFERENCE_FILES:
        shutil.copy2(SOURCE_DIR / name, source_dir / name)

    idle_path = SOURCE_DIR / "joey-idle.png"
    idle_img = Image.open(idle_path).convert("RGBA")
    idle_bb = body_bbox(idle_img)
    target_body_height = CELL_SIZE * BODY_TARGET_FRACTION

    normalized: list[Image.Image] = []
    qa_frames: list[tuple[str, Image.Image]] = []
    for anim_id, filename in RUNTIME_STATES:
        img = Image.open(SOURCE_DIR / filename).convert("RGBA")
        frame = normalize_frame(img, anim_id, target_body_height)
        normalized.append(frame)
        if anim_id in {"idle", "walking", "carryingTrash", "cleaning", "celebrating", "notifying"}:
            qa_frames.append((anim_id, frame))

    columns = len(RUNTIME_STATES)
    rows = 1
    sheet = Image.new("RGBA", (columns * CELL_SIZE, rows * CELL_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        sheet.paste(frame, (index * CELL_SIZE, 0))

    for (_anim_id, filename), frame in zip(RUNTIME_STATES, normalized, strict=True):
        frame.save(runtime_dir / filename)
    sheet.save(JOEY_PKG / "spritesheet.png")
    write_qa_sheet(qa_frames)

    animations: dict[str, dict] = {}
    for index, (anim_id, _filename) in enumerate(RUNTIME_STATES):
        loop = anim_id not in ("blink", "celebrating", "notifying")
        fps = 6 if anim_id == "blink" else (4 if anim_id in ("walking", "cleaning", "celebrating") else 3)
        if anim_id in ("idle", "sleeping"):
            fps = 1
        animations[anim_id] = {"frames": [index], "fps": fps, "loop": loop}

    manifest = {
        "id": "joey-cat",
        "name": "Joey",
        "spriteSheet": "spritesheet.png",
        "frameWidth": CELL_SIZE,
        "frameHeight": CELL_SIZE,
        "columns": columns,
        "rows": rows,
        "defaultScale": 1,
        "displayPointSize": DISPLAY_POINT_SIZE,
        "textureFiltering": "smooth",
        "fallbackAnimation": "idle",
        "animations": animations,
    }

    (JOEY_PKG / "pet.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(
        f"Wrote {JOEY_PKG} ({columns}x{rows} @ {CELL_SIZE}px, "
        f"displayPointSize={DISPLAY_POINT_SIZE}pt, QA sheet -> {QA_SHEET})"
    )


if __name__ == "__main__":
    main()
