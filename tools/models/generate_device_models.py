#!/usr/bin/env python3
"""Generate Reef's device models.

Builds three original, unbranded device models from parametric surfaces and
writes them as USDZ files that SceneKit loads natively:

    earbuds.usdz          a pair of in-ear wireless earbuds
    earbuds-case.usdz     the earbuds in a pebble-shaped charging case, lid open
    headphones.usdz       over-ear headphones

Every surface is computed here, so the models carry no third-party license and
can be changed by editing this file. Units are meters, Y is up, and each model
faces +Z. Materials are UsdPreviewSurface, which SceneKit maps to its
physically based lighting model.

Usage:
    python3 generate_device_models.py OUTPUT_DIR [--json PREVIEW_DIR]

`--json` also writes each model as plain JSON (positions, normals, indices, and
material parameters) for previewing in a browser.

Requires usd-core and numpy (see requirements.txt).
"""

import argparse
import json
import math
import os
import sys
import tempfile

import numpy as np
from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

# Colors are written here as they should look on screen (sRGB) and converted
# to the linear values UsdPreviewSurface expects when the file is written.
MATERIALS = {
    # Matte white plastic with a soft satin clear coat.
    "satin_white": dict(color=(0.93, 0.93, 0.92), roughness=0.42, metallic=0.0,
                        clearcoat=0.35, clearcoat_roughness=0.3),
    # The inside of the case: the same plastic, a touch darker and flatter.
    "inner_white": dict(color=(0.84, 0.84, 0.83), roughness=0.6, metallic=0.0),
    # Soft silicone ear tips.
    "silicone": dict(color=(0.96, 0.96, 0.95), roughness=0.78, metallic=0.0),
    # The wells the buds sit in.
    "grille": dict(color=(0.09, 0.09, 0.1), roughness=0.62, metallic=0.0),
    # Acoustic vents and sensor windows: a quiet grey, not a hole.
    "vent": dict(color=(0.55, 0.55, 0.56), roughness=0.7, metallic=0.0),
    # The thin seam where the case lid meets the base.
    "seam": dict(color=(0.6, 0.6, 0.6), roughness=0.6, metallic=0.0),
    # The case's single status LED.
    "led": dict(color=(0.25, 0.9, 0.45), roughness=0.3, metallic=0.0,
                emissive=(0.3, 1.0, 0.5)),
    # Headphone shells and headband.
    "charcoal": dict(color=(0.12, 0.12, 0.13), roughness=0.5, metallic=0.0,
                     clearcoat=0.15, clearcoat_roughness=0.4),
    # Plush cushions and the headband pad.
    "fabric": dict(color=(0.065, 0.065, 0.07), roughness=0.95, metallic=0.0),
    # Brushed-aluminum accents.
    "aluminum": dict(color=(0.8, 0.81, 0.82), roughness=0.3, metallic=1.0),
}


# ---------------------------------------------------------------------------
# Mesh helpers
# ---------------------------------------------------------------------------

class Mesh:
    """Triangle mesh with smooth vertex normals."""

    def __init__(self, points, faces):
        self.points = np.asarray(points, dtype=np.float64)
        self.faces = np.asarray(faces, dtype=np.int64)

    def transformed(self, matrix):
        homo = np.c_[self.points, np.ones(len(self.points))]
        moved = (homo @ matrix.T)[:, :3]
        faces = self.faces
        # A mirroring transform flips orientation; keep faces pointing out.
        if np.linalg.det(matrix[:3, :3]) < 0:
            faces = faces[:, ::-1]
        return Mesh(moved, faces)

    def normals(self):
        p, f = self.points, self.faces
        n = np.zeros_like(p)
        face_n = np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]])
        for i in range(3):
            np.add.at(n, f[:, i], face_n)
        length = np.linalg.norm(n, axis=1)
        length[length == 0] = 1
        return n / length[:, None]

    @staticmethod
    def merge(meshes):
        points, faces, offset = [], [], 0
        for m in meshes:
            points.append(m.points)
            faces.append(m.faces + offset)
            offset += len(m.points)
        return Mesh(np.vstack(points), np.vstack(faces))


def grid_faces(rows, cols, wrap_cols=True):
    """Two triangles per quad of a rows x cols vertex grid."""
    faces = []
    span = cols if wrap_cols else cols - 1
    for r in range(rows - 1):
        for c in range(span):
            a = r * cols + c
            b = r * cols + (c + 1) % cols
            d = (r + 1) * cols + c
            e = (r + 1) * cols + (c + 1) % cols
            faces.append((a, d, b))
            faces.append((b, d, e))
    return faces


def signed_pow(value, exponent):
    return np.sign(value) * np.abs(value) ** exponent


def superellipsoid(rx, ry, rz, e1, e2, rows=36, cols=64, lat_range=(-0.5, 0.5)):
    """A superellipsoid, optionally cut to a band of latitudes.

    `lat_range` is in units of pi: (-0.5, 0.5) is the whole surface. Exponents
    below 1 square off the shape; 1 gives an ellipsoid.
    """
    lats = np.linspace(lat_range[0] * math.pi, lat_range[1] * math.pi, rows)
    lons = np.linspace(-math.pi, math.pi, cols, endpoint=False)
    pts = []
    for u in lats:
        cu, su = signed_pow(math.cos(u), e1), signed_pow(math.sin(u), e1)
        for v in lons:
            cv, sv = signed_pow(math.cos(v), e2), signed_pow(math.sin(v), e2)
            pts.append((rx * cu * cv, ry * su, rz * cu * sv))
    return Mesh(pts, grid_faces(rows, cols))


def lathe(profile, segments=48):
    """Revolve a (radius, y) profile around the Y axis."""
    pts = []
    for r, y in profile:
        for k in range(segments):
            a = 2 * math.pi * k / segments
            pts.append((r * math.cos(a), y, r * math.sin(a)))
    return Mesh(pts, grid_faces(len(profile), segments))


def rounded_profile(radius_top, radius_bottom, height, round_top, round_bottom, steps=8):
    """Profile for a rounded cylinder from y=0 (bottom) to y=height (top)."""
    prof = [(0.0, 0.0)]
    for i in range(1, steps + 1):
        a = (math.pi / 2) * i / steps
        prof.append((radius_bottom - round_bottom + round_bottom * math.sin(a),
                     round_bottom - round_bottom * math.cos(a)))
    for i in range(steps + 1):
        a = (math.pi / 2) * i / steps
        prof.append((radius_top - round_top + round_top * math.cos(a),
                     height - round_top + round_top * math.sin(a)))
    prof.append((0.0, height))
    return prof


def superellipse_ring(a, b, exponent, count):
    """Points of a superellipse in the plane, counter-clockwise."""
    ts = np.linspace(0, 2 * math.pi, count, endpoint=False)
    return np.c_[a * signed_pow(np.cos(ts), exponent), b * signed_pow(np.sin(ts), exponent)]


def sweep(path, width, height, exponent=0.6, section=24, closed=False, cap=True):
    """Sweep a superellipse cross-section along a path.

    `width` runs along the path's binormal and `height` along its normal, using
    a frame transported along the path so the section does not twist.
    """
    path = np.asarray(path, dtype=np.float64)
    count = len(path)
    tangents = np.zeros_like(path)
    for i in range(count):
        if closed:
            tangents[i] = path[(i + 1) % count] - path[i - 1]
        else:
            tangents[i] = path[min(i + 1, count - 1)] - path[max(i - 1, 0)]
    tangents /= np.linalg.norm(tangents, axis=1)[:, None]

    ref = np.array([0.0, 0.0, 1.0])
    if abs(np.dot(ref, tangents[0])) > 0.9:
        ref = np.array([0.0, 1.0, 0.0])
    normal = np.cross(tangents[0], ref)
    normal /= np.linalg.norm(normal)
    ring = superellipse_ring(width / 2, height / 2, exponent, section)

    pts = []
    for i in range(count):
        t = tangents[i]
        normal = normal - np.dot(normal, t) * t
        normal /= np.linalg.norm(normal)
        binormal = np.cross(t, normal)
        for x, y in ring:
            pts.append(path[i] + binormal * x + normal * y)

    faces = []
    rows = count + (1 if closed else 0)
    for r in range(rows - 1):
        r0, r1 = r % count, (r + 1) % count
        for c in range(section):
            a = r0 * section + c
            b = r0 * section + (c + 1) % section
            d = r1 * section + c
            e = r1 * section + (c + 1) % section
            faces.append((a, b, d))
            faces.append((b, e, d))

    if cap and not closed:
        for end, flip in ((0, True), (count - 1, False)):
            centre = len(pts)
            pts.append(path[end])
            base = end * section
            for c in range(section):
                a, b = base + c, base + (c + 1) % section
                faces.append((centre, b, a) if flip else (centre, a, b))
    return Mesh(pts, faces)


def disc(a, b, exponent, count=48):
    """A flat superellipse in the XZ plane facing +Y."""
    ring = superellipse_ring(a, b, exponent, count)
    pts = [(0.0, 0.0, 0.0)] + [(x, 0.0, z) for x, z in ring]
    faces = [(0, 1 + (k + 1) % count, 1 + k) for k in range(count)]
    return Mesh(pts, faces)


# ---------------------------------------------------------------------------
# Transforms
# ---------------------------------------------------------------------------

def translate(x, y, z):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def scale(x, y, z):
    return np.diag([x, y, z, 1.0])


def rotate(axis, degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    if axis == "x":
        m[1:3, 1:3] = [[c, -s], [s, c]]
    elif axis == "y":
        m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    else:
        m[0:2, 0:2] = [[c, -s], [s, c]]
    return m


def chain(*matrices):
    """Compose transforms, applied right to left."""
    out = np.eye(4)
    for m in matrices:
        out = out @ m
    return out


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

def earbud(side=1):
    """One earbud as {material: Mesh}. side is 1 for right, -1 for left.

    The head is a soft bean. The silicone tip points inward along -X and a
    short rounded stem drops below with a slight outward lean.
    """
    parts = {"satin_white": [], "silicone": [], "vent": []}

    head = superellipsoid(0.0105, 0.0098, 0.0112, 0.85, 0.9, rows=32, cols=56)
    parts["satin_white"].append(head)

    # Ear tip: a short neck flaring into a rounded silicone dome.
    tip_profile = [(0.0, 0.0), (0.0034, 0.0), (0.0036, 0.0022), (0.0052, 0.0034),
                   (0.0063, 0.0046), (0.0066, 0.0058), (0.0061, 0.007),
                   (0.0046, 0.0079), (0.0024, 0.0084), (0.0, 0.0085)]
    tip = lathe(tip_profile, 40).transformed(
        chain(translate(-0.0085, 0.0012, 0.0), rotate("z", 90), rotate("x", 0)))
    parts["silicone"].append(tip)

    # Stem: a gently tapered rounded cylinder.
    stem = lathe(rounded_profile(0.0037, 0.0031, 0.0185, 0.0018, 0.0028, 8), 36)
    parts["satin_white"].append(stem.transformed(
        chain(translate(0.0016, -0.0035, 0.0012), rotate("z", 168), rotate("x", -6))))

    # A slim acoustic vent on the outer face, and a small sensor window.
    vent = superellipsoid(0.00045, 0.0021, 0.0011, 0.6, 0.6, rows=12, cols=24)
    parts["vent"].append(vent.transformed(
        chain(translate(0.0097, 0.0028, 0.0028), rotate("y", -18))))
    sensor = superellipsoid(0.0003, 0.0011, 0.0011, 1.0, 1.0, rows=10, cols=20)
    parts["vent"].append(sensor.transformed(translate(-0.006, -0.0014, 0.0088)))

    mirror = np.eye(4) if side > 0 else scale(-1, 1, 1)
    return {k: Mesh.merge(v).transformed(mirror) for k, v in parts.items() if v}


def earbuds_pair():
    left = earbud(-1)
    right = earbud(1)
    model = {}
    # Tips turned toward the viewer, the classic product pose.
    placements = (
        (left, chain(translate(-0.0165, 0.0, -0.002), rotate("y", -42), rotate("z", -8))),
        (right, chain(translate(0.0165, 0.0008, 0.002), rotate("y", 42), rotate("z", 8))),
    )
    for parts, matrix in placements:
        for material, mesh in parts.items():
            model.setdefault(material, []).append(mesh.transformed(matrix))
    return model


def charging_case():
    """A pebble case cut at a seam, lid hinged open at the back, buds inside."""
    model = {}

    def add(material, mesh):
        model.setdefault(material, []).append(mesh)

    rx, ry, rz, e1, e2 = 0.026, 0.018, 0.0124, 0.6, 0.66
    seam_y = 0.0045

    def lat_at(y):
        return math.asin(min(1.0, (y / ry) ** (1.0 / e1))) / math.pi

    seam_lat = lat_at(seam_y)
    base = superellipsoid(rx, ry, rz, e1, e2, rows=34, cols=72, lat_range=(-0.5, seam_lat))
    add("satin_white", base)

    # The seam ring: the cross-section where the base was cut.
    cu = signed_pow(math.cos(seam_lat * math.pi), e1)
    ring = superellipse_ring(rx * cu, rz * cu, e2, 72)
    seam_path = [(x, seam_y, z) for x, z in ring]
    add("seam", sweep(seam_path, 0.0009, 0.0007, exponent=1.0, section=8, closed=True))

    # The deck closing the base, with two wells for the buds.
    deck = disc(rx * cu * 0.985, rz * cu * 0.985, e2, 72).transformed(translate(0, seam_y, 0))
    add("inner_white", deck)
    for x in (-0.0105, 0.0105):
        well = disc(0.0068, 0.006, 1.0, 40).transformed(translate(x, seam_y + 0.00005, 0.0006))
        add("grille", well)

    # The lid, hinged along the back edge and opened.
    lid = superellipsoid(rx, ry, rz, e1, e2, rows=22, cols=72, lat_range=(seam_lat, 0.5))
    lid_inside = disc(rx * cu * 0.985, rz * cu * 0.985, e2, 72).transformed(
        chain(translate(0, seam_y, 0), scale(1, -1, 1)))
    hinge = chain(translate(0, seam_y, -rz * cu), rotate("x", -78), translate(0, -seam_y, rz * cu))
    add("satin_white", lid.transformed(hinge))
    add("inner_white", lid_inside.transformed(hinge))

    # The status LED on the front face.
    led = superellipsoid(0.0011, 0.0011, 0.0005, 1.0, 1.0, rows=12, cols=20)
    add("led", led.transformed(translate(0.0, -0.0028, rz * 0.995)))

    # Two buds standing in their wells, stems sunk into the base.
    for side, x, turn in ((-1, -0.0105, 25), (1, 0.0105, -25)):
        bud = earbud(side)
        matrix = chain(translate(x, seam_y + 0.0016, 0.0004), rotate("y", turn), rotate("x", 8),
                       scale(0.86, 0.86, 0.86))
        for material, mesh in bud.items():
            add(material, mesh.transformed(matrix))
    return model


def headphones():
    model = {}

    def add(material, mesh):
        model.setdefault(material, []).append(mesh)

    cup_x = 0.084
    for side in (-1, 1):
        # The ear cup shell: an oval puck with softly squared edges.
        shell = superellipsoid(0.019, 0.046, 0.035, 0.5, 0.75, rows=30, cols=64)
        add("charcoal", shell.transformed(translate(side * cup_x, 0, 0)))
        # The brushed-aluminum plate on the outside of the cup.
        plate = disc(0.03, 0.021, 0.75, 64).transformed(
            chain(translate(side * (cup_x + 0.0197), 0, 0), rotate("z", -90 * side)))
        add("aluminum", plate)
        # The plush oval cushion on the inside face.
        path = [(0.0, 0.031 * math.sin(t), 0.023 * math.cos(t))
                for t in np.linspace(0, 2 * math.pi, 64, endpoint=False)]
        cushion = sweep(path, 0.017, 0.0145, exponent=0.7, section=24, closed=True)
        add("fabric", cushion.transformed(translate(side * (cup_x - 0.022), 0, 0)))
        # Yoke arm and pivot linking the cup to the headband.
        arm_path = [(side * cup_x, 0.083, 0), (side * cup_x, 0.062, 0), (side * cup_x, 0.049, 0)]
        add("aluminum", sweep(arm_path, 0.0075, 0.005, exponent=0.7, section=16))
        pivot = lathe(rounded_profile(0.0048, 0.0048, 0.006, 0.0012, 0.0012, 5), 28)
        add("aluminum", pivot.transformed(
            chain(translate(side * cup_x, 0.0465, -0.003), rotate("x", 90))))

    # The headband: a smooth arc from one yoke to the other.
    arc = [(cup_x * math.cos(t), 0.083 + 0.088 * math.sin(t), 0.0)
           for t in np.linspace(math.pi, 0, 72)]
    add("charcoal", sweep(arc, 0.030, 0.0075, exponent=0.55, section=28))
    pad = [(0.9 * cup_x * math.cos(t), 0.083 + 0.0805 * math.sin(t), 0.0)
           for t in np.linspace(math.radians(152), math.radians(28), 48)]
    add("fabric", sweep(pad, 0.023, 0.0072, exponent=0.6, section=24))
    return model


MODELS = {
    "earbuds": earbuds_pair,
    "earbuds-case": charging_case,
    "headphones": headphones,
}


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def linear(color):
    """Convert an sRGB color to the linear values the renderers expect."""
    def channel(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(round(channel(c), 5) for c in color)


def merged(model):
    return {material: Mesh.merge(meshes) for material, meshes in model.items()}


def write_usd(name, model, path):
    stage = Usd.Stage.CreateNew(path)
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)
    root = UsdGeom.Xform.Define(stage, "/Model")
    stage.SetDefaultPrim(root.GetPrim())
    Usd.ModelAPI(root.GetPrim()).SetKind("component")

    materials = {}
    for key in model:
        spec = MATERIALS[key]
        mat = UsdShade.Material.Define(stage, f"/Model/Materials/{key}")
        shader = UsdShade.Shader.Define(stage, f"/Model/Materials/{key}/Surface")
        shader.CreateIdAttr("UsdPreviewSurface")
        shader.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).Set(
            Gf.Vec3f(*linear(spec["color"])))
        shader.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(spec["roughness"])
        shader.CreateInput("metallic", Sdf.ValueTypeNames.Float).Set(spec["metallic"])
        if "clearcoat" in spec:
            shader.CreateInput("clearcoat", Sdf.ValueTypeNames.Float).Set(spec["clearcoat"])
            shader.CreateInput("clearcoatRoughness", Sdf.ValueTypeNames.Float).Set(
                spec["clearcoat_roughness"])
        if "emissive" in spec:
            shader.CreateInput("emissiveColor", Sdf.ValueTypeNames.Color3f).Set(
                Gf.Vec3f(*linear(spec["emissive"])))
        mat.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
        materials[key] = mat

    for key, mesh in model.items():
        prim = UsdGeom.Mesh.Define(stage, f"/Model/{key}")
        prim.CreatePointsAttr([Gf.Vec3f(*p) for p in mesh.points])
        prim.CreateFaceVertexCountsAttr([3] * len(mesh.faces))
        prim.CreateFaceVertexIndicesAttr([int(i) for i in mesh.faces.flatten()])
        prim.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
        prim.CreateNormalsAttr([Gf.Vec3f(*n) for n in mesh.normals()])
        prim.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
        lo, hi = mesh.points.min(axis=0), mesh.points.max(axis=0)
        prim.CreateExtentAttr([Gf.Vec3f(*lo), Gf.Vec3f(*hi)])
        UsdShade.MaterialBindingAPI.Apply(prim.GetPrim()).Bind(materials[key])

    stage.GetRootLayer().Save()


def write_usdz(name, model, out_dir):
    with tempfile.TemporaryDirectory() as tmp:
        usdc = os.path.join(tmp, f"{name}.usdc")
        write_usd(name, model, usdc)
        target = os.path.join(out_dir, f"{name}.usdz")
        if os.path.exists(target):
            os.remove(target)
        if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(usdc), target):
            raise RuntimeError(f"could not package {target}")
    return target


def write_json(name, model, out_dir):
    data = {"name": name, "parts": []}
    for key, mesh in model.items():
        data["parts"].append({
            "material": key,
            "params": dict(MATERIALS[key], color=linear(MATERIALS[key]["color"]),
                           **({"emissive": linear(MATERIALS[key]["emissive"])}
                              if "emissive" in MATERIALS[key] else {})),
            "positions": np.round(mesh.points, 6).flatten().tolist(),
            "normals": np.round(mesh.normals(), 4).flatten().tolist(),
            "indices": mesh.faces.flatten().tolist(),
        })
    path = os.path.join(out_dir, f"{name}.json")
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    return path


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("output", help="directory for the .usdz files")
    parser.add_argument("--json", help="also write browser preview JSON here")
    args = parser.parse_args(argv)
    os.makedirs(args.output, exist_ok=True)
    if args.json:
        os.makedirs(args.json, exist_ok=True)

    for name, build in MODELS.items():
        model = merged(build())
        tris = sum(len(m.faces) for m in model.values())
        target = write_usdz(name, model, args.output)
        size = os.path.getsize(target) / 1024
        print(f"{name}: {tris} triangles, {size:.0f} KB -> {target}")
        if args.json:
            write_json(name, model, args.json)


if __name__ == "__main__":
    main(sys.argv[1:])
