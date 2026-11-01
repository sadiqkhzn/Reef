# Device models

Reef draws connected devices as small 3D models in the device wing and the
onboarding tiles, with SF Symbols as the fallback. The models live in
`Reef/Assets/Models`:

| File | What it is |
|---|---|
| `earbuds.usdz` | A pair of glossy white in-ear buds: rounded heads, oval silicone tips with a mesh-filled mouth, short flattened stems with a satin touch area, a black vent on top, a front vent, a sensor window, and microphone meshes at the top and tip of each stem |
| `earbuds-case.usdz` | The buds standing in a charging case with a squircle front: a hollow lid open on a stainless hinge, a recessed tray with cavities shaped to the buds, a front status light, a stainless lanyard loop, and a USB-C port and speaker holes underneath |
| `headphones.usdz` | Over-ear headphones: silver aluminum cups with rounded-rectangle faces, knit cushions over dark speaker cloth, a knurled crown and a button on the right cup, swiveling stainless arms, a slim stainless frame, and a knit canopy |

They follow the look of today's premium earbuds and headphones so a connected
device is recognizable at a glance, but they carry no logos, brand marks, or
product names. Every shape is described in code, so the models are covered by
the project's MIT license like the rest of the repository.

## How they are made

- `devices.py` describes each model as signed distance fields in millimeters
  (`sdf.py`), joined with smooth fillets the way the real products blend body
  into nozzle and head into stem. Vents, sensors, and the status light are
  thin skins that follow the surface.
- `build_device_models.py` meshes each part with marching cubes, then uses
  Blender to decimate it to its triangle budget, assign materials, and export
  binary USD with Y up and the front facing +Z. `--renders DIR` also writes a
  path-traced preview of each model.
- `package_models.py` folds the per-corner normals to per-vertex, drops unused
  texture coordinates, clears the build path from the file, and writes the
  shipped USDZ.

The models are shown at about an inch across, so each is kept near 20k to 35k
triangles and the three ship in about 1.2 MB.

## Rebuilding

Blender's Python module needs Python 3.11; packaging needs `usd-core`.

```
python3.11 -m venv .venv-build
.venv-build/bin/pip install bpy==5.0.1 numpy scikit-image
.venv-build/bin/python tools/models/build_device_models.py /tmp/reef-models --renders /tmp/reef-renders

python3 -m venv .venv-package
.venv-package/bin/pip install usd-core numpy
.venv-package/bin/python tools/models/package_models.py /tmp/reef-models Reef/Assets/Models
```

A full build takes a few minutes; most of it is meshing.
