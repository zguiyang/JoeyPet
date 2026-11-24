#!/usr/bin/env python3
"""Build JoeyPet layered pet assets from the frozen state atlas.

This is a development-only script. It does not run at app runtime and does not
add a build dependency. It reads the SVG symbols from
docs/reference/joeypet-states-v0.html, writes standalone layer/pose SVGs, then
rasterizes 3x PNGs with headless Chrome and downsamples 2x/1x with sips.

Usage:
    python3 macos/scripts/build_joey_pose_assets.py
"""

from __future__ import annotations

import copy
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "docs/reference/joeypet-states-v0.html"
OUT = ROOT / "macos/JoeyPet/Resources/Pets/Joey"
LAYER_DIR = OUT / "layers"
POSE_DIR = OUT / "poses"
TMP = Path("/tmp/joey_asset_build")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
VIEWBOX = "0 0 320 400"
CANVAS_W = 320
CANVAS_H = 400


def load_symbols() -> dict[str, ET.Element]:
    text = ATLAS.read_text(encoding="utf-8")
    match = re.search(r"<svg aria-hidden=\"true\"[^>]*>(.*?)</svg>", text, re.S)
    if not match:
        raise RuntimeError("could not find the asset SVG block")
    root = ET.fromstring("<svg>" + match.group(1) + "</svg>")
    return {symbol.get("id"): symbol for symbol in root.iter("symbol") if symbol.get("id")}


SYMBOLS = load_symbols()


def children(symbol_id: str) -> list[ET.Element]:
    return [copy.deepcopy(child) for child in SYMBOLS[symbol_id]]


def expand(element: ET.Element) -> ET.Element:
    if element.tag == "use":
        href = element.get("href") or element.get("{http://www.w3.org/1999/xlink}href")
        if not href:
            raise RuntimeError("use without href")
        target = SYMBOLS[href.lstrip("#")]
        wrapper = ET.Element("g")
        for attribute in ("x", "y", "transform"):
            if element.get(attribute):
                wrapper.set(attribute, element.get(attribute))
        for child in target:
            wrapper.append(expand(copy.deepcopy(child)))
        return wrapper
    new = copy.deepcopy(element)
    new[:] = [expand(child) for child in element]
    return new


def write_svg(path: Path, elements: list[ET.Element]) -> None:
    svg = ET.Element(
        "svg",
        {
            "xmlns": "http://www.w3.org/2000/svg",
            "viewBox": VIEWBOX,
            "width": str(CANVAS_W),
            "height": str(CANVAS_H),
        },
    )
    for element in elements:
        svg.append(element)
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(svg).write(path, encoding="utf-8", xml_declaration=False)


def build_sources() -> list[Path]:
    body = children("j-body")
    if len(body) != 12:
        raise RuntimeError(f"unexpected j-body child count: {len(body)}")

    shadow_default = [body[0]]
    tail_default = [body[1]]
    ears_default = body[2:6]
    body_default = body[6:12]

    arms_rest = children("j-arms-rest")
    arms_up = children("j-arms-up")
    arms_sign = children("j-arms-sign")
    arms_groom = children("j-arms-groom")

    sleep = children("joey-sleep")
    peek = children("joey-peek")
    carry = children("joey-carry")
    sign = children("joey-sign")

    layers: dict[str, list[ET.Element]] = {
        "shadow.default": shadow_default,
        "shadow.sleep": [sleep[0]],
        "shadow.peek": [peek[0]],
        "tail.default": tail_default,
        "tail.sleep": [sleep[2]],
        "body.default": body_default,
        "body.sleep": [sleep[1], sleep[11]],
        "body.peek": peek[5:9],
        "ears.default": ears_default,
        "ears.sleep": sleep[3:5],
        "ears.peek": peek[1:5],
        "arm.backRest": [arms_rest[0]],
        "arm.frontRest": [arms_rest[1]],
        "arm.backUp": [arms_up[0], arms_up[2]],
        "arm.frontUp": [arms_up[1], arms_up[3]],
        "arm.backSign": [arms_sign[0]],
        "arm.frontSign": arms_sign[1:3],
        "arm.backGroom": [arms_groom[0]],
        "arm.frontGroom": arms_groom[1:3],
        "face.calm": children("j-face-calm"),
        "face.look": children("j-face-look"),
        "face.happy": children("j-face-happy"),
        "face.stretch": children("j-face-stretch"),
        "face.yawn": children("j-face-yawn"),
        "face.doze": children("j-face-doze"),
        "face.groom": children("j-face-groom"),
        "face.sign": children("j-face-calm"),
        "face.sleep": sleep[5:11],
        "face.peek": [expand(peek[9])],
        "face.calm.blink2": children("j-face-blink2"),
        "face.calm.blink3": children("j-face-blink3"),
        "prop.sign": sign[3:],
        "prop.leaf": carry[3:],
    }

    written: list[Path] = []
    for layer_id, elements in layers.items():
        path = LAYER_DIR / ("layer_" + layer_id.replace(".", "_") + ".svg")
        write_svg(path, elements)
        written.append(path)

    pose_ids = [
        "sit",
        "look",
        "sign",
        "stretch",
        "happy",
        "sleep",
        "groom",
        "yawn",
        "doze",
        "peek",
        "carry",
    ]
    for pose_id in pose_ids:
        elements = [expand(child) for child in SYMBOLS["joey-" + pose_id]]
        path = POSE_DIR / f"pose_{pose_id}.svg"
        write_svg(path, elements)
        written.append(path)

    return written


def rasterize(svg_path: Path) -> None:
    stem = svg_path.stem
    base = POSE_DIR if svg_path.parent == POSE_DIR else LAYER_DIR
    png_dir = base / "png"
    png3 = png_dir / "3x" / f"{stem}.png"
    png2 = png_dir / "2x" / f"{stem}.png"
    png1 = png_dir / "1x" / f"{stem}.png"
    for path in (png3, png2, png1):
        path.parent.mkdir(parents=True, exist_ok=True)

    svg_text = svg_path.read_text(encoding="utf-8")
    svg_text = svg_text.replace(
        f'width="{CANVAS_W}" height="{CANVAS_H}"',
        f'width="{CANVAS_W * 3}" height="{CANVAS_H * 3}"',
    )
    wrapper = TMP / f"{stem}.html"
    wrapper.write_text(
        "<!doctype html><html><body style=\"margin:0;background:transparent\">"
        + svg_text
        + "</body></html>",
        encoding="utf-8",
    )

    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--default-background-color=00000000",
            f"--window-size={CANVAS_W * 3},{CANVAS_H * 3}",
            "--virtual-time-budget=1200",
            f"--screenshot={png3}",
            wrapper.as_uri(),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["sips", "-z", str(CANVAS_H * 2), str(CANVAS_W * 2), str(png3), "--out", str(png2)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["sips", "-z", str(CANVAS_H), str(CANVAS_W), str(png3), "--out", str(png1)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> int:
    if not ATLAS.exists():
        print(f"missing atlas: {ATLAS}", file=sys.stderr)
        return 1
    if not Path(CHROME).exists():
        print("Google Chrome is required for the dev-only raster step", file=sys.stderr)
        return 1

    TMP.mkdir(parents=True, exist_ok=True)
    for directory in (LAYER_DIR, POSE_DIR):
        if directory.exists():
            shutil.rmtree(directory)
    LAYER_DIR.mkdir(parents=True)
    POSE_DIR.mkdir(parents=True)

    sources = build_sources()
    print(f"wrote {len(sources)} SVG sources")
    for index, svg_path in enumerate(sources, start=1):
        rasterize(svg_path)
        if index % 10 == 0 or index == len(sources):
            print(f"rasterized {index}/{len(sources)}")
    print(f"assets ready in {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
