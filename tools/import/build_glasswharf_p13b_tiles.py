import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


OUT_DIR = Path("D:/black-meridian/assets/city/glasswharf_dock")


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def make_mat(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def materials():
    return [
        make_mat("bm_proxy_grey_wall", (0.46, 0.46, 0.44, 1.0)),
        make_mat("bm_proxy_grey_detail", (0.28, 0.29, 0.29, 1.0)),
        make_mat("bm_proxy_grey_dark", (0.12, 0.12, 0.12, 1.0)),
    ]


def add_box(parts, min_xyz, max_xyz, mat=0):
    x0, y0, z0 = min_xyz
    x1, y1, z1 = max_xyz
    base = len(parts["verts"])
    parts["verts"].extend(
        [
            (x0, y0, z0),
            (x1, y0, z0),
            (x1, y1, z0),
            (x0, y1, z0),
            (x0, y0, z1),
            (x1, y0, z1),
            (x1, y1, z1),
            (x0, y1, z1),
        ]
    )
    faces = [
        (0, 1, 2, 3),  # bottom
        (4, 7, 6, 5),  # top
        (0, 4, 5, 1),  # -Y
        (1, 5, 6, 2),  # +X
        (2, 6, 7, 3),  # +Y
        (3, 7, 4, 0),  # -X
    ]
    for face in faces:
        parts["faces"].append(tuple(base + i for i in face))
        parts["mats"].append(mat)


def add_cylinder_z(parts, center, radius, z0, z1, sides=12, mat=1):
    cx, cy = center
    bottom = []
    top = []
    for i in range(sides):
        a = 2.0 * math.pi * i / sides
        bottom.append(len(parts["verts"]))
        parts["verts"].append((cx + math.cos(a) * radius, cy + math.sin(a) * radius, z0))
        top.append(len(parts["verts"]))
        parts["verts"].append((cx + math.cos(a) * radius, cy + math.sin(a) * radius, z1))
    cb = len(parts["verts"])
    parts["verts"].append((cx, cy, z0))
    ct = len(parts["verts"])
    parts["verts"].append((cx, cy, z1))
    for i in range(sides):
        j = (i + 1) % sides
        parts["faces"].append((bottom[i], bottom[j], top[j], top[i]))
        parts["mats"].append(mat)
        parts["faces"].append((cb, bottom[i], bottom[j]))
        parts["mats"].append(mat)
        parts["faces"].append((ct, top[j], top[i]))
        parts["mats"].append(mat)


def add_frustum_z(parts, center, r0, r1, z0, z1, sides=12, mat=0):
    cx, cy = center
    bottom = []
    top = []
    for i in range(sides):
        a = 2.0 * math.pi * i / sides
        bottom.append(len(parts["verts"]))
        parts["verts"].append((cx + math.cos(a) * r0, cy + math.sin(a) * r0, z0))
        top.append(len(parts["verts"]))
        parts["verts"].append((cx + math.cos(a) * r1, cy + math.sin(a) * r1, z1))
    cb = len(parts["verts"])
    parts["verts"].append((cx, cy, z0))
    ct = len(parts["verts"])
    parts["verts"].append((cx, cy, z1))
    for i in range(sides):
        j = (i + 1) % sides
        parts["faces"].append((bottom[i], bottom[j], top[j], top[i]))
        parts["mats"].append(mat)
        parts["faces"].append((cb, bottom[j], bottom[i]))
        parts["mats"].append(mat)
        parts["faces"].append((ct, top[i], top[j]))
        parts["mats"].append(mat)


def new_parts():
    return {"verts": [], "faces": [], "mats": []}


def create_mesh_object(name, parts, mats):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(parts["verts"], [], parts["faces"])
    mesh.update(calc_edges=True)
    for mat in mats:
        mesh.materials.append(mat)
    for poly, mat_index in zip(mesh.polygons, parts["mats"]):
        poly.material_index = mat_index
        poly.use_smooth = False
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        for loop_index in poly.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if axis == 2:
                uv.data[loop_index].uv = (co.x, co.y)
            elif axis == 0:
                uv.data[loop_index].uv = (co.y, co.z)
            else:
                uv.data[loop_index].uv = (co.x, co.z)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (0.0, 0.0, 0.0)
    return obj


def tri_count(obj):
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def footprint_xy(obj):
    xs = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_x = min(v.x for v in xs)
    max_x = max(v.x for v in xs)
    min_y = min(v.y for v in xs)
    max_y = max(v.y for v in xs)
    return round(max_x - min_x, 3), round(max_y - min_y, 3)


def export_tile(filename, lod0_name, lod0_parts, lod1_name, lod1_parts):
    reset_scene()
    mats = materials()
    lod0 = create_mesh_object(lod0_name, lod0_parts, mats)
    lod1 = create_mesh_object(lod1_name, lod1_parts, mats)
    bpy.ops.object.select_all(action="DESELECT")
    lod0.select_set(True)
    lod1.select_set(True)
    bpy.context.view_layer.objects.active = lod0
    out_path = OUT_DIR / filename
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_normals=True,
        export_texcoords=True,
        export_materials="EXPORT",
    )
    return {
        "tile": filename,
        "lod0": tri_count(lod0),
        "lod1": tri_count(lod1),
        "footprint": footprint_xy(lod0),
        "exists": out_path.exists(),
        "path": str(out_path),
    }


def ground_frontage_b():
    p = new_parts()
    add_box(p, (-2.25, -2.25, 0.0), (2.25, 2.245, 4.5), 0)
    add_box(p, (-1.5, 2.246, 0.2), (1.5, 2.25, 3.4), 1)
    for i in range(11):
        z = 0.35 + i * 0.27
        add_box(p, (-1.45, 2.248, z), (1.45, 2.25, z + 0.045), 2)
    add_box(p, (-1.62, 2.247, 0.1), (-1.5, 2.25, 3.52), 1)
    add_box(p, (1.5, 2.247, 0.1), (1.62, 2.25, 3.52), 1)
    add_box(p, (-1.62, 2.247, 3.42), (1.62, 2.25, 3.55), 1)

    q = new_parts()
    add_box(q, (-2.25, -2.25, 0.0), (2.25, 2.24, 4.5), 0)
    add_box(q, (-1.5, 2.245, 0.2), (1.5, 2.25, 3.4), 1)
    return "ground_frontage_b.glb", "glasswharf_dock_ground_frontage_b_LOD0", p, "glasswharf_dock_ground_frontage_b_LOD1", q


def mid_floor_b():
    p = new_parts()
    add_box(p, (-2.25, -2.25, 0.0), (2.25, 2.245, 4.5), 0)
    for x in (-1.05, 0.0, 1.05):
        add_box(p, (x - 0.35, 2.13, 1.35), (x + 0.35, 2.145, 3.15), 2)
        add_box(p, (x - 0.43, 2.146, 1.25), (x - 0.35, 2.25, 3.25), 1)
        add_box(p, (x + 0.35, 2.146, 1.25), (x + 0.43, 2.25, 3.25), 1)
        add_box(p, (x - 0.43, 2.146, 3.15), (x + 0.43, 2.25, 3.25), 1)
        add_box(p, (x - 0.43, 2.146, 1.25), (x + 0.43, 2.25, 1.35), 1)
    add_cylinder_z(p, (-2.08, 2.11), 0.075, 0.25, 4.3, 12, 1)
    add_box(p, (-2.16, 2.11, 0.2), (-2.0, 2.25, 0.35), 1)
    add_box(p, (-2.16, 2.11, 4.2), (-2.0, 2.25, 4.35), 1)

    q = new_parts()
    add_box(q, (-2.25, -2.25, 0.0), (2.25, 2.24, 4.5), 0)
    for x in (-1.05, 0.0, 1.05):
        add_box(q, (x - 0.35, 2.13, 1.35), (x + 0.35, 2.25, 3.15), 2)
    add_box(q, (-2.14, 2.08, 0.3), (-2.02, 2.22, 4.3), 1)
    return "mid_floor_b.glb", "glasswharf_dock_mid_floor_b_LOD0", p, "glasswharf_dock_mid_floor_b_LOD1", q


def roof_cap_b():
    p = new_parts()
    add_box(p, (-2.25, -2.25, 0.0), (2.25, 2.25, 0.35), 0)
    add_box(p, (-2.25, -2.25, 0.35), (-2.0, 2.25, 1.0), 0)
    add_box(p, (2.0, -2.25, 0.35), (2.25, 2.25, 1.0), 0)
    add_box(p, (-2.25, -2.25, 0.35), (-0.85, -2.0, 1.0), 0)
    add_box(p, (0.85, -2.25, 0.35), (2.25, -2.0, 1.0), 0)
    add_box(p, (-0.85, -2.25, 0.35), (0.85, -2.0, 1.8), 0)
    add_box(p, (-2.25, 2.0, 0.35), (-0.85, 2.25, 1.0), 0)
    add_box(p, (0.85, 2.0, 0.35), (2.25, 2.25, 1.0), 0)
    add_box(p, (-0.85, 2.0, 0.35), (0.85, 2.25, 1.8), 0)
    add_box(p, (-0.55, -2.25, 1.8), (0.55, -2.0, 2.2), 1)
    add_box(p, (-0.55, 2.0, 1.8), (0.55, 2.25, 2.2), 1)

    q = new_parts()
    add_box(q, (-2.25, -2.25, 0.0), (2.25, 2.25, 0.35), 0)
    add_box(q, (-2.25, -2.25, 0.35), (2.25, -2.0, 1.0), 0)
    add_box(q, (-0.85, -2.25, 1.0), (0.85, -2.0, 1.8), 0)
    add_box(q, (-2.25, 2.0, 0.35), (2.25, 2.25, 1.0), 0)
    add_box(q, (-0.85, 2.0, 1.0), (0.85, 2.25, 1.8), 0)
    return "roof_cap_b.glb", "glasswharf_dock_roof_cap_b_LOD0", p, "glasswharf_dock_roof_cap_b_LOD1", q


def tower_mid():
    p = new_parts()
    add_box(p, (-2.25, -2.25, 0.0), (2.25, 2.1, 4.2), 0)
    add_box(p, (-2.05, -2.05, 4.2), (2.05, 2.05, 4.5), 0)
    for x in [(-1.95 + i * (3.9 / 7.0)) for i in range(8)]:
        add_box(p, (x - 0.035, 2.1, 0.25), (x + 0.035, 2.25, 4.15), 1)
    for x in [(-1.68 + i * (3.36 / 6.0)) for i in range(7)]:
        add_box(p, (x - 0.13, 2.08, 0.55), (x + 0.13, 2.1, 3.75), 2)

    q = new_parts()
    add_box(q, (-2.25, -2.25, 0.0), (2.25, 2.1, 4.2), 0)
    add_box(q, (-2.05, -2.05, 4.2), (2.05, 2.05, 4.5), 0)
    for x in (-1.6, -0.55, 0.55, 1.6):
        add_box(q, (x - 0.04, 2.1, 0.3), (x + 0.04, 2.25, 4.05), 1)
    return "tower_mid.glb", "glasswharf_tower_mid_LOD0", p, "glasswharf_tower_mid_LOD1", q


def tower_cap():
    p = new_parts()
    add_box(p, (-2.25, -2.25, 0.0), (2.25, 2.25, 0.45), 0)
    add_box(p, (-1.8, -1.8, 0.45), (1.8, 1.8, 1.0), 0)
    add_box(p, (-1.25, -1.25, 1.0), (1.25, 1.25, 1.55), 0)
    add_box(p, (-0.65, -0.65, 1.55), (0.65, 0.65, 2.0), 1)
    add_box(p, (-0.08, -0.9, 1.65), (0.08, 0.9, 2.0), 1)
    add_box(p, (-0.9, -0.08, 1.65), (0.9, 0.08, 2.0), 1)

    q = new_parts()
    add_box(q, (-2.25, -2.25, 0.0), (2.25, 2.25, 0.65), 0)
    add_box(q, (-1.45, -1.45, 0.65), (1.45, 1.45, 1.35), 0)
    add_box(q, (-0.65, -0.65, 1.35), (0.65, 0.65, 2.0), 1)
    return "tower_cap.glb", "glasswharf_tower_cap_LOD0", p, "glasswharf_tower_cap_LOD1", q


def transit_pier():
    p = new_parts()
    add_box(p, (-1.15, -1.15, 0.0), (1.15, 1.15, 0.35), 0)
    add_frustum_z(p, (0.0, 0.0), 1.0, 0.7, 0.35, 5.4, 12, 0)
    add_box(p, (-1.4, -1.15, 5.4), (1.4, 1.15, 6.0), 0)
    add_box(p, (-0.85, -0.85, 5.2), (0.85, 0.85, 5.4), 1)

    q = new_parts()
    add_box(q, (-1.15, -1.15, 0.0), (1.15, 1.15, 0.35), 0)
    add_frustum_z(q, (0.0, 0.0), 1.0, 0.7, 0.35, 5.4, 8, 0)
    add_box(q, (-1.4, -1.15, 5.4), (1.4, 1.15, 6.0), 0)
    return "transit_pier.glb", "glasswharf_transit_pier_LOD0", p, "glasswharf_transit_pier_LOD1", q


def transit_deck():
    p = new_parts()
    add_box(p, (-2.25, -1.5, 0.0), (2.25, 1.5, 0.55), 0)
    add_box(p, (-2.25, -1.5, 0.55), (2.25, -1.32, 1.0), 1)
    add_box(p, (-2.25, 1.32, 0.55), (2.25, 1.5, 1.0), 1)
    add_box(p, (-2.25, -0.55, 0.58), (2.25, -0.45, 0.72), 2)
    add_box(p, (-2.25, 0.45, 0.58), (2.25, 0.55, 0.72), 2)
    add_box(p, (-2.25, -1.18, 0.1), (2.25, -1.05, 0.3), 1)
    add_box(p, (-2.25, 1.05, 0.1), (2.25, 1.18, 0.3), 1)

    q = new_parts()
    add_box(q, (-2.25, -1.5, 0.0), (2.25, 1.5, 0.6), 0)
    add_box(q, (-2.25, -1.5, 0.6), (2.25, -1.32, 1.0), 1)
    add_box(q, (-2.25, 1.32, 0.6), (2.25, 1.5, 1.0), 1)
    return "transit_deck.glb", "glasswharf_transit_deck_LOD0", p, "glasswharf_transit_deck_LOD1", q


BUILDERS = [
    ground_frontage_b,
    mid_floor_b,
    roof_cap_b,
    tower_mid,
    tower_cap,
    transit_pier,
    transit_deck,
]


def main():
    rows = []
    for builder in BUILDERS:
        rows.append(export_tile(*builder()))
    print("tile | LOD0 tris | LOD1 tris | footprint XY | file exists")
    print("--- | ---: | ---: | --- | ---")
    for row in rows:
        footprint = f"{row['footprint'][0]:.3f} x {row['footprint'][1]:.3f} m"
        print(f"{row['tile']} | {row['lod0']} | {row['lod1']} | {footprint} | {row['exists']}")
    too_large = [r for r in rows if r["lod0"] >= 3000 or r["lod1"] >= 500]
    if too_large:
        raise RuntimeError(f"LOD budget exceeded: {too_large}")
    missing = [r["path"] for r in rows if not os.path.exists(r["path"])]
    if missing:
        raise RuntimeError(f"Missing exports: {missing}")


if __name__ == "__main__":
    main()
