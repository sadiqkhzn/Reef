"""The device models, described as signed distance fields in millimeters.

Each model is a list of parts. A part names its material, gives the field, the
box to mesh it in, the voxel size, and a triangle budget after decimation.
Frame: Z up, front -Y, as in Blender.
"""

from dataclasses import dataclass, field
from typing import Callable

import numpy as np

import sdf as S


@dataclass
class Part:
    name: str
    material: str
    field: Callable
    lo: tuple
    hi: tuple
    step: float
    tris: int
    # Optional rigid placement applied after meshing: rotation (3x3) then offset.
    rot: np.ndarray = field(default_factory=lambda: np.eye(3))
    offset: tuple = (0.0, 0.0, 0.0)


# ---------------------------------------------------------------------------
# Earbud
# ---------------------------------------------------------------------------
#
# One right earbud. The head is a rounded bean; the nozzle carrying the ear tip
# leaves it toward -X (into the ear) and slightly forward and up; a short stem
# drops from the lower outer side and leans a little outward. Overall about
# 31 x 22 x 24 mm with the tip.

HEAD = S.ellipsoid((8.3, 9.5, 8.5))
NOZZLE_A = np.array([-2.5, -0.9, 0.9])
NOZZLE_B = np.array([-8.6, -1.6, 1.6])
NOZZLE = S.round_cone(NOZZLE_A, NOZZLE_B, 4.6, 3.55)
STEM_A = np.array([2.6, 0.7, -5.2])
STEM_B = np.array([3.9, 1.4, -20.6])


def _stem(p):
    # A flattened oval section: wider front to back than side to side.
    return S.stretch(S.round_cone(STEM_A, STEM_B, 2.85, 2.5), (1.0, 1.17, 1.0))(p)


def bud_body(p):
    d = S.smin(HEAD(p), NOZZLE(p), 2.4)
    d = S.smin(d, _stem(p), 2.9)
    # A gently flattened stem end.
    return S.smax(d, -(p[:, 2] + 21.9), 0.9)


NOZZLE_AXIS = S.normalize(NOZZLE_B - NOZZLE_A)
TIP_CENTER = NOZZLE_B + NOZZLE_AXIS * 1.55
TIP_FRAME = S.frame_from_axis(NOZZLE_AXIS)


def _in_tip_frame(p):
    return (p - TIP_CENTER) @ TIP_FRAME


def ear_tip(p):
    """An oval silicone dome over the nozzle end, open toward the ear."""
    q = _in_tip_frame(p)
    dome = S.ellipsoid((5.95, 4.95, 3.35))(q)
    # Trim the inner side flat-ish where it meets the nozzle, and keep the
    # outer face full and rounded.
    dome = S.smax(dome, -(q[:, 2] + 2.0), 0.8)
    return dome


def _tip_opening(rx, ry):
    """The oval opening at the end of the tip, as a region."""
    def region(p):
        q = _in_tip_frame(p)
        r = np.sqrt((q[:, 0] / rx) ** 2 + (q[:, 1] / ry) ** 2) - 1.0
        return np.maximum(r * ry, -(q[:, 2] - 1.0))
    return region


# The dark ring around the opening, and the fine mesh filling it, a shade
# lighter than the silicone.
tip_mouth = S.shell(ear_tip, _tip_opening(2.5, 2.1), offset=0.02, thickness=0.05)
tip_mesh = S.shell(ear_tip, _tip_opening(1.8, 1.5), offset=0.08, thickness=0.05)


def _region_top_vent(p):
    # A long slot across the top of the head, toward the outer side.
    x, y, z = p[:, 0] - 2.4, p[:, 1] + 0.6, p[:, 2]
    r = np.sqrt((x / 1.25) ** 2 + (y / 3.9) ** 2) - 1.0
    return np.maximum(r * 1.25, -(z - 4.0))


def _region_front_vent(p):
    # A small mesh port at the front, above the nozzle.
    x, z = p[:, 0] + 2.6, p[:, 2] - 5.0
    r = np.sqrt((x / 1.35) ** 2 + (z / 0.75) ** 2) - 1.0
    return np.maximum(r * 0.75, p[:, 1] + 3.0)


def _region_sensor(p):
    # The skin-detect window on the inside of the head, below the nozzle.
    y, z = p[:, 1] - 1.6, p[:, 2] + 4.3
    r = np.sqrt((y / 1.55) ** 2 + (z / 1.05) ** 2) - 1.0
    return np.maximum(r * 1.05, p[:, 0] + 1.5)


def _region_stem_mic(p):
    # The microphone mesh capping the end of the stem.
    return -(p[:, 2] + 21.05)


def _region_stem_top_mic(p):
    # A small mesh slot near the top of the stem on its outer face.
    y, z = p[:, 1] - 0.9, p[:, 2] + 9.4
    r = np.sqrt((y / 1.05) ** 2 + (z / 1.75) ** 2) - 1.0
    return np.maximum(r * 1.05, -(p[:, 0] - 3.5))


def _region_force(p):
    # The flat touch area on the outer face of the stem, in satin.
    y, z = p[:, 1] - 1.3, p[:, 2] + 15.0
    r = np.sqrt((y / 1.6) ** 2 + (z / 3.6) ** 2) - 1.0
    return np.maximum(r * 1.6, -(p[:, 0] - 4.0))


def earbud_parts(prefix="bud"):
    box_lo, box_hi = (-15.5, -11.0, -23.0), (10.0, 11.0, 10.0)
    detail = 0.035
    return [
        Part(f"{prefix}_body", "gloss_white", bud_body, box_lo, box_hi, 0.085, 13000),
        Part(f"{prefix}_tip", "silicone", ear_tip, (-16.5, -9.0, -6.5), (-6.0, 6.0, 9.0), 0.06, 3200),
        Part(f"{prefix}_tip_mouth", "black_mesh", tip_mouth, (-16.5, -6.0, -4.5), (-9.0, 4.0, 7.0), detail, 700),
        Part(f"{prefix}_tip_mesh", "tip_mesh", tip_mesh, (-16.5, -6.0, -4.5), (-9.0, 4.0, 7.0), detail, 450),
        Part(f"{prefix}_top_vent", "black_mesh", S.shell(bud_body, _region_top_vent),
             (-0.5, -6.5, 3.0), (5.5, 5.5, 9.5), detail, 700),
        Part(f"{prefix}_front_vent", "black_mesh", S.shell(bud_body, _region_front_vent),
             (-5.5, -11.0, 3.0), (0.0, -3.0, 8.0), detail, 350),
        Part(f"{prefix}_sensor", "sensor", S.shell(bud_body, _region_sensor),
             (-9.0, -1.0, -6.5), (-1.0, 4.5, -2.0), detail, 400),
        Part(f"{prefix}_stem_mic", "black_mesh", S.shell(bud_body, _region_stem_mic),
             (0.5, -2.5, -22.5), (7.0, 5.5, -20.5), detail, 500),
        Part(f"{prefix}_stem_top_mic", "black_mesh", S.shell(bud_body, _region_stem_top_mic),
             (3.0, -1.0, -12.0), (7.0, 3.0, -6.5), detail, 300),
        Part(f"{prefix}_force", "satin_white", S.shell(bud_body, _region_force, offset=0.01, thickness=0.03),
             (3.0, -1.5, -19.5), (7.5, 4.5, -10.5), detail, 500),
    ]


# ---------------------------------------------------------------------------
# Charging case
# ---------------------------------------------------------------------------
#
# About 61 x 22 x 45 mm (W x D x H). The front is a rounded rectangle; the
# sides roll softly into it. The lid takes the top third, hinged at the back.

CASE_HALF = (30.3, 10.85, 22.6)
CASE_CORNER = 13.5
CASE_EDGE = 7.6
SEAM_Z = 6.1
GAP = 0.13
HINGE_Y = 8.9
LID_OPEN = 100.0


def case_outer(p):
    d2 = S.rounded_rect_2d(p[:, 0], p[:, 2], CASE_HALF[0], CASE_HALF[2], CASE_CORNER)
    return S.extrude(d2, p[:, 1], CASE_HALF[1], CASE_EDGE)


# Where the buds stand in the open case: heads above the deck, stems down,
# tips turned toward the middle and a little back.
BUD_IN_CASE = [
    (np.array([11.6, 0.4, SEAM_Z + 3.0]), S.rotation((0, 0, 1), -14)),
]
BUD_IN_CASE.append((BUD_IN_CASE[0][0] * np.array([-1, 1, 1]), None))


def _bud_cutter(p):
    """Both buds, inflated a little, to carve their cavities."""
    def one(q):
        body = S.smin(bud_body(q), ear_tip(q), 0.4)
        return body - 0.45
    center, rot = BUD_IN_CASE[0]
    right = S.transform(one, center, rot)(p)
    mirrored = p * np.array([-1.0, 1.0, 1.0])
    left = S.transform(one, center, rot)(mirrored)
    return np.minimum(right, left)


def case_base(p):
    outer = case_outer(p)
    d = S.smax(outer, p[:, 2] - (SEAM_Z - GAP), 0.25)
    # A shallow tray inside the rim, then the bud cavities.
    tray = S.smax(outer + 1.35, -(p[:, 2] - (SEAM_Z - 0.9)), 0.3)
    d = S.ssub(d, tray, 0.35)
    d = S.ssub(d, _bud_cutter(p), 0.5)
    # USB-C port centered on the bottom, and a row of speaker holes.
    port = S.extrude(S.rounded_rect_2d(p[:, 0], p[:, 1], 4.3, 1.35, 1.3),
                     p[:, 2] + CASE_HALF[2], 3.2, 0.2)
    d = S.ssub(d, port, 0.15)
    for x in (-19.0, -16.6, -14.2):
        hole = S.cylinder((x, 0.0, -CASE_HALF[2]), (0, 0, 1), 0.55, 1.6)(p)
        d = np.maximum(d, -hole)
    return d


def _lid_closed(p):
    outer = case_outer(p)
    d = S.smax(outer, -(p[:, 2] - (SEAM_Z + GAP)), 0.25)
    # Hollow it out to a 1.3 mm wall with a slightly deeper inner lip.
    hollow = S.smax(outer + 1.3, -(p[:, 2] - (SEAM_Z - 0.4)), 0.3)
    hollow = S.smax(hollow, p[:, 2] - (CASE_HALF[2] - 1.6), 0.4)
    return S.ssub(d, hollow, 0.3)


LID_ROT = S.rotation((1, 0, 0), -LID_OPEN)
HINGE_POINT = np.array([0.0, HINGE_Y, SEAM_Z])


def case_lid(p):
    # Rotate space the other way about the hinge to open the lid.
    q = (p - HINGE_POINT) @ LID_ROT + HINGE_POINT
    return _lid_closed(q)


def case_hinge(p):
    barrel = S.cylinder((0.0, HINGE_Y + 0.9, SEAM_Z + 0.2), (1, 0, 0), 1.25, 7.5, edge=0.5)(p)
    return barrel


def _region_led(p):
    r = np.sqrt(p[:, 0] ** 2 + (p[:, 2] + 3.4) ** 2) - 0.85
    return np.maximum(r, p[:, 1] + 6.0)


def case_lanyard(p):
    """A small stainless loop on the right side, near the bottom."""
    c = np.array([CASE_HALF[0] - 0.4, 0.0, -14.0])
    q = p - c
    ring = np.sqrt((np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - 2.15) ** 2 + (q[:, 1] / 1.35) ** 2) - 0.62
    return ring


def case_parts():
    lo, hi = (-31.5, -12.0, -23.5), (31.5, 12.0, 8.0)
    lid_lo, lid_hi = (-31.5, -8.0, 4.0), (31.5, 28.0, 30.0)
    detail = 0.04
    return [
        Part("case_base", "gloss_white", case_base, lo, hi, 0.13, 17000),
        Part("case_lid", "gloss_white", case_lid, lid_lo, lid_hi, 0.13, 9000),
        Part("case_hinge", "steel", case_hinge, (-9.0, 7.0, 3.5), (9.0, 13.0, 9.0), 0.05, 800),
        Part("case_led", "led", S.shell(case_outer, _region_led, offset=0.02, thickness=0.05),
             (-1.5, -12.0, -5.0), (1.5, -9.5, -1.8), 0.025, 600),
        Part("case_lanyard", "steel", case_lanyard, (26.5, -2.5, -17.5), (33.5, 2.5, -10.5), 0.04, 1000),
    ]


# ---------------------------------------------------------------------------
# Headphones
# ---------------------------------------------------------------------------
#
# About 169 x 83 x 187 mm (W x D x H). Cups centered at x = +-63.

CUP_X = 63.0
CUP_HALF = (17.0, 33.0, 41.0)
CUP_CORNER = 22.0
ARM_TOP = 64.0


def cup(p, side):
    x = p[:, 0] - side * CUP_X
    d2 = S.rounded_rect_2d(p[:, 1], p[:, 2], CUP_HALF[1], CUP_HALF[2], CUP_CORNER)
    d = S.extrude(d2, x, CUP_HALF[0], 10.5)
    # The outer face swells very slightly, like a pressed aluminum shell.
    outer = side * x
    bulge = np.clip(1 - (p[:, 1] / 33.0) ** 2 - (p[:, 2] / 41.0) ** 2, 0, 1) * 1.1
    return d - np.where(outer > 0, bulge, 0.0)


def _crown(p):
    c = np.array([CUP_X, -16.0, CUP_HALF[2] - 1.5])
    q = p - c
    r = np.sqrt(q[:, 0] ** 2 + q[:, 1] ** 2)
    theta = np.arctan2(q[:, 1], q[:, 0])
    knurl = 0.16 * np.cos(48 * theta)
    side = r - (5.1 + knurl)
    return S.extrude(side, q[:, 2] - 3.3, 3.3, 0.7)


def _button(p):
    return S.round_box((2.5, 5.8, 1.7), 1.6, center=(CUP_X, 15.5, CUP_HALF[2] - 0.2))(p)


def cup_shell(side):
    def f(p):
        d = cup(p, side)
        if side > 0:
            d = S.smin(d, _crown(p), 0.6)
            d = S.smin(d, _button(p), 0.5)
        return d
    return f


def cushion(side):
    def f(p):
        x = p[:, 0] - side * (CUP_X - CUP_HALF[0] - 11.0)
        outer = S.rounded_rect_2d(p[:, 1], p[:, 2], 31.0, 39.0, 20.0)
        inner = S.rounded_rect_2d(p[:, 1], p[:, 2], 15.5, 24.0, 12.0)
        ring = np.maximum(outer, -inner)
        return S.extrude(ring, x, 11.5, 8.0)
    return f


def speaker_cloth(side):
    def f(p):
        x = p[:, 0] - side * (CUP_X - CUP_HALF[0] - 0.6)
        d2 = S.rounded_rect_2d(p[:, 1], p[:, 2], 16.5, 25.0, 12.5)
        return S.extrude(d2, x, 0.5, 0.3)
    return f


def arm(side):
    def f(p):
        rod = S.capsule((side * CUP_X, 0, CUP_HALF[2] + 1.0), (side * CUP_X, 0, ARM_TOP), 2.3)(p)
        swivel = S.ellipsoid((4.0, 5.2, 3.2), center=(side * CUP_X, 0, CUP_HALF[2] + 1.2))(p)
        block = S.round_box((3.4, 4.6, 3.0), 1.6, center=(side * (CUP_X - 1.0), 0, ARM_TOP + 1.0))(p)
        return S.smin(S.smin(rod, swivel, 1.4), block, 1.2)
    return f


FRAME_CENTER_Z = 80.4
FRAME_R = 65.6


def frame(p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2] - FRAME_CENTER_Z
    s = np.sqrt(x * x + z * z) - FRAME_R
    d = S.rounded_rect_2d(s, y, 1.55, 3.5, 1.45)
    # Keep the arc above the arm tops, with rounded ends.
    return S.smax(d, -(p[:, 2] - (ARM_TOP + 0.5)), 1.0)


CANOPY_CENTER_Z = 75.3
CANOPY_R = 56.8


def canopy(p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2] - CANOPY_CENTER_Z
    s = np.sqrt(x * x + z * z) - CANOPY_R
    d = S.rounded_rect_2d(s, y, 1.7, 21.0, 1.6)
    return S.smax(d, -(p[:, 2] - (ARM_TOP + 2.5)), 2.5)


def headphone_parts():
    parts = []
    for side, tag in ((1, "right"), (-1, "left")):
        cx = side * CUP_X
        parts += [
            Part(f"{tag}_cup", "aluminum", cup_shell(side),
                 (cx - 19, -36, -44), (cx + 19, 36, 50), 0.2, 9000),
            Part(f"{tag}_cushion", "knit", cushion(side),
                 (side * 34.5 - 13, -33, -41), (side * 34.5 + 13, 33, 41), 0.2, 6500),
            Part(f"{tag}_cloth", "speaker_cloth", speaker_cloth(side),
                 (side * 45.4 - 1.5, -18, -27), (side * 45.4 + 1.5, 18, 27), 0.12, 600),
            Part(f"{tag}_arm", "steel", arm(side),
                 (cx - 6, -7, 38), (cx + 6, 7, 69), 0.1, 2500),
        ]
    parts += [
        Part("frame", "steel", frame, (-70, -5, 60), (70, 5, 149), 0.13, 5000),
        Part("canopy", "knit", canopy, (-62, -23, 63), (62, 23, 135), 0.22, 5000),
    ]
    return parts
