#!/usr/bin/env python3
"""Package Blender's USD exports as the USDZ files Reef ships.

Run with a Python that has usd-core (see README.md):

    python package_models.py WORK_DIR OUTPUT_DIR

For each earbuds, earbuds-case, and headphones .usdc in WORK_DIR:

- Smooth-shaded meshes store one normal per face corner when exported; they
  are folded to one per vertex, which halves the file without changing how
  the model looks.
- Unused texture coordinates are dropped.
- The stage is flattened and packaged as OUTPUT_DIR/<name>.usdz.
"""

import os
import sys
import tempfile

import numpy as np
from pxr import Sdf, Usd, UsdGeom, UsdUtils, Vt

NAMES = ("earbuds", "earbuds-case", "headphones")


def fold_normals(mesh):
    normals_attr = mesh.GetNormalsAttr()
    normals = normals_attr.Get()
    if normals is None or mesh.GetNormalsInterpolation() != UsdGeom.Tokens.faceVarying:
        return
    indices = np.asarray(mesh.GetFaceVertexIndicesAttr().Get())
    count = len(mesh.GetPointsAttr().Get())
    corner = np.asarray(normals, dtype=np.float64)
    summed = np.zeros((count, 3))
    np.add.at(summed, indices, corner)
    lengths = np.linalg.norm(summed, axis=1)
    lengths[lengths == 0] = 1
    folded = (summed / lengths[:, None]).astype(np.float32)
    normals_attr.Set(Vt.Vec3fArray.FromNumpy(folded))
    mesh.SetNormalsInterpolation(UsdGeom.Tokens.vertex)


def package(src, dst):
    stage = Usd.Stage.Open(src)
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Mesh):
            mesh = UsdGeom.Mesh(prim)
            fold_normals(mesh)
            api = UsdGeom.PrimvarsAPI(prim)
            for primvar in api.GetPrimvars():
                if primvar.GetTypeName().role == Sdf.ValueRoleNames.TextureCoordinate:
                    api.RemovePrimvar(primvar.GetPrimvarName())
    with tempfile.TemporaryDirectory() as tmp:
        flat = os.path.join(tmp, os.path.basename(dst).replace(".usdz", ".usdc"))
        layer = stage.Flatten()
        # Flattening records the source file's path; replace it so the shipped
        # file carries no details of the machine it was built on.
        layer.documentation = "Reef device model"
        layer.Export(flat)
        if os.path.exists(dst):
            os.remove(dst)
        if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(flat), dst):
            raise RuntimeError(f"could not package {dst}")


def main(argv):
    work, out = argv
    os.makedirs(out, exist_ok=True)
    for name in NAMES:
        src = os.path.join(work, f"{name}.usdc")
        dst = os.path.join(out, f"{name}.usdz")
        package(src, dst)
        print(f"{name}: {os.path.getsize(src) // 1024} KB -> {os.path.getsize(dst) // 1024} KB", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
