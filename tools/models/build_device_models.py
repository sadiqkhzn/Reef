#!/usr/bin/env python3
"""Build Reef's device models and write them as USDZ.

Run with Blender's Python (the `bpy` module; see README.md):

    python build_device_models.py WORK_DIR [--renders DIR] [--only NAME]

Writes earbuds.usdc, earbuds-case.usdc, and headphones.usdc to WORK_DIR, for
package_models.py to turn into the shipped USDZ files. With --renders, also
writes a path-traced preview PNG of each.
"""

import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402

import devices  # noqa: E402
import scene  # noqa: E402
import sdf  # noqa: E402


def place(verts, rot, offset):
    return verts @ np.asarray(rot).T + np.asarray(offset)


_meshes = {}


def polygonize(part):
    """Mesh a part's field once; parts that share a field reuse the result."""
    key = (id(part.field), part.lo, part.hi, part.step)
    if key not in _meshes:
        _meshes[key] = sdf.mesh(part.field, part.lo, part.hi, part.step)
    return _meshes[key]


def build_parts(parts, parent=None, rot=np.eye(3), offset=(0, 0, 0)):
    for part in parts:
        t = time.time()
        verts, faces = polygonize(part)
        verts = place(place(verts, part.rot, part.offset), rot, offset)
        scene.add_mesh(part.name, verts, faces, part.material, part.tris, parent)
        print(f"  {part.name}: {len(faces)} -> <= {part.tris} tris ({time.time() - t:.1f}s)", flush=True)


def earbuds():
    """A pair, tips turned toward the viewer in the classic product pose."""
    right = devices.earbud_parts("right")
    build_parts(right, rot=sdf.rotation((0, 0, 1), -38) @ sdf.rotation((0, 1, 0), 8),
                offset=(13.5, 0.0, 0.0))
    left = devices.earbud_parts("left")
    mirror = np.diag([-1.0, 1.0, 1.0])
    for part in left:
        part.rot = mirror
    build_parts(left, rot=sdf.rotation((0, 0, 1), 38) @ sdf.rotation((0, 1, 0), -8),
                offset=(-13.5, 2.0, 0.6))


def earbuds_case():
    build_parts(devices.case_parts())
    center, rot = devices.BUD_IN_CASE[0]
    build_parts(devices.earbud_parts("case_right"), rot=rot, offset=center)
    left = devices.earbud_parts("case_left")
    mirror = np.diag([-1.0, 1.0, 1.0])
    for part in left:
        part.rot = mirror
    build_parts(left, rot=mirror @ rot @ mirror, offset=center * np.array([-1, 1, 1]))


def headphones():
    build_parts(devices.headphone_parts())


MODELS = {
    "earbuds": earbuds,
    "earbuds-case": earbuds_case,
    "headphones": headphones,
}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("output")
    ap.add_argument("--renders")
    ap.add_argument("--only")
    args = ap.parse_args(argv)
    os.makedirs(args.output, exist_ok=True)
    for name, build in MODELS.items():
        if args.only and name != args.only:
            continue
        print(f"{name}:", flush=True)
        sc = scene.reset()
        build()
        tris = scene.triangle_count()
        lo, hi = scene.bounds()
        size = max(hi - lo)
        if args.renders:
            os.makedirs(args.renders, exist_ok=True)
            scene.studio(sc, size)
            scene.render(os.path.join(args.renders, f"{name}.png"), (lo + hi) / 2, size)
        target = os.path.join(args.output, f"{name}.usdc")
        scene.export_usd(target)
        print(f"  {tris} triangles, {os.path.getsize(target) // 1024} KB -> {target}", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
