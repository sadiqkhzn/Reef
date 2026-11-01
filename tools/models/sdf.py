"""Signed distance fields for modeling Reef's device models.

Every shape here is a function from an (N, 3) array of points in millimeters to
an (N,) array of signed distances: negative inside, positive outside. Shapes are
combined with smooth unions and subtractions so joins blend with real fillets,
then turned into meshes with marching cubes.

The modeling frame is Blender's: Z is up and the front of a model faces -Y.
"""

import numpy as np
from skimage.measure import marching_cubes


# ---------------------------------------------------------------------------
# Vector helpers
# ---------------------------------------------------------------------------

def length(v, axis=-1):
    return np.sqrt(np.sum(v * v, axis=axis))


def clamp(x, lo, hi):
    return np.minimum(np.maximum(x, lo), hi)


def normalize(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


def rotation(axis, degrees):
    """3x3 rotation about a unit axis."""
    a = np.radians(degrees)
    x, y, z = normalize(axis)
    c, s, t = np.cos(a), np.sin(a), 1 - np.cos(a)
    return np.array([
        [t * x * x + c, t * x * y - s * z, t * x * z + s * y],
        [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
        [t * x * z - s * y, t * y * z + s * x, t * z * z + c],
    ])


def frame_from_axis(axis):
    """An orthonormal frame whose third column is `axis`."""
    w = normalize(axis)
    helper = np.array([0.0, 0.0, 1.0]) if abs(w[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = normalize(np.cross(helper, w))
    v = np.cross(w, u)
    return np.stack([u, v, w], axis=1)


# ---------------------------------------------------------------------------
# Combinators
# ---------------------------------------------------------------------------

def smin(a, b, k):
    """Smooth union with a fillet of roughly radius k."""
    if k <= 0:
        return np.minimum(a, b)
    h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    """Smooth intersection."""
    return -smin(-a, -b, k)


def ssub(a, b, k):
    """Smooth subtraction of b from a."""
    return smax(a, -b, k)


def transform(sdf, origin=(0, 0, 0), rot=None, scale=1.0):
    """Place `sdf` at `origin` with rotation `rot` (3x3) and uniform scale."""
    origin = np.asarray(origin, dtype=np.float64)
    inv = np.eye(3) if rot is None else np.asarray(rot).T

    def f(p):
        q = (p - origin) @ inv.T / scale
        return sdf(q) * scale
    return f


def stretch(sdf, factors):
    """Scale space non-uniformly. Not an exact distance, but close enough for
    gentle factors, which is all the models use."""
    factors = np.asarray(factors, dtype=np.float64)
    m = factors.min()

    def f(p):
        return sdf(p / factors) * m
    return f


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def ellipsoid(radii, center=(0, 0, 0)):
    r = np.asarray(radii, dtype=np.float64)
    c = np.asarray(center, dtype=np.float64)

    def f(p):
        q = p - c
        k0 = length(q / r)
        k1 = length(q / (r * r))
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    return f


def round_cone(a, b, r1, r2):
    """A capsule from a to b whose radius tapers from r1 to r2."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    ba = b - a
    l2 = float(ba @ ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def f(p):
        pa = p - a
        y = pa @ ba
        z = y - l2
        xv = pa * l2 - y[:, None] * ba
        x2 = np.sum(xv * xv, axis=1)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        out = np.empty(len(p))
        m1 = np.sign(z) * a2 * z2 > k
        m2 = (~m1) & (np.sign(y) * a2 * y2 < k)
        m3 = ~(m1 | m2)
        out[m1] = np.sqrt(x2[m1] + z2[m1]) * il2 - r2
        out[m2] = np.sqrt(x2[m2] + y2[m2]) * il2 - r1
        out[m3] = (np.sqrt(x2[m3] * a2 * il2) + y[m3] * rr) * il2 - r1
        return out
    return f


def capsule(a, b, r):
    return round_cone(a, b, r, r)


def round_box(half, radius, center=(0, 0, 0)):
    h = np.asarray(half, dtype=np.float64) - radius
    c = np.asarray(center, dtype=np.float64)

    def f(p):
        q = np.abs(p - c) - h
        outside = length(np.maximum(q, 0.0))
        inside = np.minimum(np.max(q, axis=1), 0.0)
        return outside + inside - radius
    return f


def rounded_rect_2d(u, v, half_u, half_v, corner):
    """Signed distance to a rounded rectangle in a plane."""
    qu = np.abs(u) - (half_u - corner)
    qv = np.abs(v) - (half_v - corner)
    outside = np.sqrt(np.maximum(qu, 0) ** 2 + np.maximum(qv, 0) ** 2)
    inside = np.minimum(np.maximum(qu, qv), 0)
    return outside + inside - corner


def extrude(d2, w, half, edge):
    """Extrude a 2D distance d2 along w to +-half, rounding the edges."""
    qx = d2 + edge
    qy = np.abs(w) - half + edge
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - edge


def plane(normal, offset):
    """Half-space n.p < offset is inside."""
    n = normalize(normal)

    def f(p):
        return p @ n - offset
    return f


def cylinder(axis_point, axis, radius, half_length, edge=0.0):
    """A capped cylinder with optionally rounded edges."""
    c = np.asarray(axis_point, dtype=np.float64)
    a = normalize(axis)

    def f(p):
        q = p - c
        h = q @ a
        r = length(q - h[:, None] * a)
        return extrude(r - radius, h, half_length, edge)
    return f


# ---------------------------------------------------------------------------
# Meshing
# ---------------------------------------------------------------------------

def mesh(sdf, lo, hi, step, chunk_points=4_000_000):
    """Polygonize `sdf` inside the box lo..hi with voxels of `step` mm.

    Returns (vertices, triangles) in the modeling frame. The field is
    evaluated in slabs so large grids fit in memory.
    """
    lo = np.asarray(lo, dtype=np.float64)
    hi = np.asarray(hi, dtype=np.float64)
    xs = np.arange(lo[0], hi[0] + step, step)
    ys = np.arange(lo[1], hi[1] + step, step)
    zs = np.arange(lo[2], hi[2] + step, step)
    volume = np.empty((len(xs), len(ys), len(zs)), dtype=np.float32)
    per_slab = max(1, chunk_points // (len(ys) * len(zs)))
    gy, gz = np.meshgrid(ys, zs, indexing="ij")
    for i in range(0, len(xs), per_slab):
        sl = xs[i:i + per_slab]
        gx = np.repeat(sl, gy.size)
        pts = np.stack([gx, np.tile(gy.ravel(), len(sl)), np.tile(gz.ravel(), len(sl))], axis=1)
        volume[i:i + len(sl)] = sdf(pts).reshape(len(sl), len(ys), len(zs))
    # Close the volume so surfaces touching the box edge still form solids.
    volume[0, :, :] = volume[-1, :, :] = 1
    volume[:, 0, :] = volume[:, -1, :] = 1
    volume[:, :, 0] = volume[:, :, -1] = 1
    verts, faces, _, _ = marching_cubes(volume, level=0.0, spacing=(step, step, step))
    # Winding is made consistent and outward when the mesh enters Blender.
    return verts + lo, faces


def shell(body, region, offset=0.03, thickness=0.05):
    """A thin skin over the part of `body` inside `region`, standing just
    proud of the surface: used for vents, sensors, and lights."""
    def f(p):
        d = body(p)
        skin = np.abs(d - offset - thickness) - thickness
        return np.maximum(skin, region(p))
    return f
