"""Blender helpers: turn meshes into a lit, materialed scene, render previews,
and export USDZ.

Runs under Blender's Python (the `bpy` module). Meshes arrive in millimeters in
the modeling frame (Z up, front -Y) and are stored in meters.
"""

import math
import os

import bpy  # noqa: I001  (bpy must load before bmesh and mathutils)
import bmesh
from mathutils import Vector

MM = 0.001


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

# Colors are sRGB as they should read on screen; Blender works in linear, so
# they are converted on the way in.
MATERIALS = {
    # Glossy white polycarbonate: the earbuds and their case.
    "gloss_white": dict(color=(0.955, 0.955, 0.95), roughness=0.16, coat=0.7, coat_roughness=0.06),
    # The same plastic where a fingertip rests: a satin patch on the stem.
    "satin_white": dict(color=(0.93, 0.93, 0.925), roughness=0.42),
    # The inside of the case and lid: a softer, flatter white.
    "inner_white": dict(color=(0.9, 0.9, 0.895), roughness=0.5),
    # Ear tips: soft silicone, a touch grey and matte.
    "silicone": dict(color=(0.9, 0.905, 0.91), roughness=0.62, coat=0.15, coat_roughness=0.4),
    # The fine white mesh in the mouth of an ear tip.
    "tip_mesh": dict(color=(0.8, 0.8, 0.8), roughness=0.85),
    # Black acoustic mesh: vents and microphones.
    "black_mesh": dict(color=(0.03, 0.03, 0.035), roughness=0.78),
    # The dark sensor window on the inside of each bud.
    "sensor": dict(color=(0.02, 0.02, 0.025), roughness=0.12, coat=0.6, coat_roughness=0.05),
    # The cavities the buds sit in.
    "cavity": dict(color=(0.8, 0.8, 0.8), roughness=0.55),
    # The case's status light.
    "led": dict(color=(0.35, 0.95, 0.55), roughness=0.3, emission=(0.35, 1.0, 0.55), emission_strength=4.0),
    # Polished stainless steel: hinge, lanyard loop, port, headband frame and arms.
    "steel": dict(color=(0.88, 0.88, 0.89), metallic=1.0, roughness=0.12),
    # Silver anodized aluminum: the headphone cups and crown.
    "aluminum": dict(color=(0.86, 0.87, 0.88), metallic=1.0, roughness=0.3),
    # Light knit mesh: cushions and the headband canopy.
    "knit": dict(color=(0.86, 0.86, 0.855), roughness=0.95, sheen=0.4),
    # The dark speaker cloth inside each cushion.
    "speaker_cloth": dict(color=(0.2, 0.2, 0.21), roughness=0.95),
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    spec = MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    lin = [srgb_to_linear(c) for c in spec["color"]]
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    if "coat" in spec:
        bsdf.inputs["Coat Weight"].default_value = spec["coat"]
        bsdf.inputs["Coat Roughness"].default_value = spec["coat_roughness"]
    if "sheen" in spec:
        bsdf.inputs["Sheen Weight"].default_value = spec["sheen"]
    if "emission" in spec:
        bsdf.inputs["Emission Color"].default_value = (*[srgb_to_linear(c) for c in spec["emission"]], 1.0)
        bsdf.inputs["Emission Strength"].default_value = spec["emission_strength"]
    mat.diffuse_color = (*lin, 1.0)
    mat.metallic = spec.get("metallic", 0.0)
    mat.roughness = spec["roughness"]
    return mat


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def add_mesh(name, verts, faces, material_name, target_tris=None, parent=None):
    """Create an object from a millimeter mesh, decimated to about
    `target_tris` triangles, with outward normals and smooth shading."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v * MM) for v in verts], [], [tuple(int(i) for i in f) for f in faces])
    me.validate()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material(material_name))

    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()

    if target_tris and len(me.polygons) > target_tris:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = target_tris / len(me.polygons)
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)

    for poly in me.polygons:
        poly.use_smooth = True
    if parent is not None:
        obj.parent = parent
    return obj


def group(name, location=(0, 0, 0), rotation_deg=(0, 0, 0), parent=None):
    empty = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(empty)
    empty.location = Vector(location) * MM
    empty.rotation_euler = [math.radians(a) for a in rotation_deg]
    if parent is not None:
        empty.parent = parent
    return empty


def triangle_count():
    total = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return total


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def studio(scene, size_m):
    """A soft product-photography rig scaled to the model: a large key above
    and to the right, a fill on the left, a rim behind, and a light grey
    world for gentle reflections."""
    world = bpy.data.worlds.new("studio")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.22, 0.22, 0.23, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world

    def area(name, loc, size, energy):
        light = bpy.data.lights.new(name, "AREA")
        light.size = size
        light.energy = energy
        obj = bpy.data.objects.new(name, light)
        obj.location = Vector(loc)
        direction = -Vector(loc)
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)

    s = size_m
    area("key", (2.2 * s, -2.6 * s, 3.0 * s), 3.0 * s, 900 * s * s)
    area("fill", (-3.0 * s, -1.6 * s, 1.2 * s), 3.5 * s, 360 * s * s)
    area("rim", (0.4 * s, 3.0 * s, 2.2 * s), 2.0 * s, 700 * s * s)


def render(path, center, size_m, yaw=-35.0, pitch=16.0, resolution=900, samples=96):
    """Render a three-quarter product shot on a transparent background."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = resolution
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"

    cam_data = bpy.data.cameras.new("camera")
    cam_data.lens = 85
    cam = bpy.data.objects.new("camera", cam_data)
    scene.collection.objects.link(cam)
    distance = size_m * 3.5
    y, p = math.radians(yaw), math.radians(pitch)
    offset = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * distance
    cam.location = Vector(center) + offset
    cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_start = size_m * 0.01
    cam_data.clip_end = size_m * 100
    scene.camera = cam

    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def bounds():
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_usd(path):
    """Write the scene as binary USD with Y up and the model's front facing
    +Z, the convention SceneKit expects. package_models.py turns it into the
    shipped USDZ."""
    if os.path.exists(path):
        os.remove(path)
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj)
    bpy.ops.wm.usd_export(
        filepath=path,
        export_materials=True,
        generate_preview_surface=True,
        export_normals=True,
        export_uvmaps=False,
        export_animation=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Y",
        export_global_up_selection="Y",
        root_prim_path="/Model",
    )
