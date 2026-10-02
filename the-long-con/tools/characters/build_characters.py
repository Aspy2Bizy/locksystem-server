#!/usr/bin/env python3
"""Build rigged, realistic character models for The Long Con.

Source: the MakeHuman base mesh, skeleton, weights and body-shape targets,
all released as CC0 (public domain) by the MakeHuman team in 2020.
They are downloaded into tools/characters/source/ on first run.

For each body variant (gender x ethnicity) this script:
  1. applies MakeHuman shape targets to the base mesh (metres, feet at y=0)
  2. fits the 163-bone MakeHuman skeleton to that body
  3. splits the skin into regions (head, neck, torso, arms, hands, legs, feet)
     so clothing can hide covered skin
  4. grows clothing shells from the body surface (jumpsuit, gloves, boots,
     face-cast mask, balaclava, helmet, plate carrier, shirt, trousers, shoes,
     hair), skinned to the same bones so they deform with the body
  5. adds blend shapes for build variety (muscular, heavy, thin)
  6. writes assets/characters/<variant>.glb

Usage:  python3 tools/characters/build_characters.py
Needs:  numpy
"""

import json
import os
import struct
import sys
import urllib.request

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "source")
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "characters"))
MH = "https://raw.githubusercontent.com/makehumancommunity/makehuman/master/makehuman/data/"

SOURCES = {
    "base.obj": "3dobjs/base.obj",
    "default.mhskel": "rigs/default.mhskel",
    "default_weights.mhw": "rigs/default_weights.mhw",
}
for eth in ("caucasian", "african", "asian"):
    for g in ("male", "female"):
        SOURCES[f"{eth}-{g}-young.target"] = f"targets/macrodetails/{eth}-{g}-young.target"
for g in ("male", "female"):
    for shape in ("maxmuscle-averageweight", "averagemuscle-maxweight", "averagemuscle-minweight"):
        SOURCES[f"universal-{g}-young-{shape}.target"] = f"targets/macrodetails/universal-{g}-young-{shape}.target"
SOURCES["breast-maxcup.target"] = "targets/breast/female-young-averagemuscle-averageweight-maxcup-averagefirmness.target"

# Body variants: base targets (with weights) baked in, then build blend shapes on top.
VARIANTS = {
    "male_a": {"gender": "male", "targets": {"caucasian-male-young": 1.0, "universal-male-young-maxmuscle-averageweight": 0.25}},
    "male_b": {"gender": "male", "targets": {"african-male-young": 1.0, "universal-male-young-maxmuscle-averageweight": 0.35}},
    "male_c": {"gender": "male", "targets": {"asian-male-young": 1.0, "universal-male-young-maxmuscle-averageweight": 0.15}},
    "female_a": {"gender": "female", "targets": {"caucasian-female-young": 1.0, "breast-maxcup": 0.15}},
    "female_b": {"gender": "female", "targets": {"african-female-young": 1.0, "breast-maxcup": 0.2}},
    "female_c": {"gender": "female", "targets": {"asian-female-young": 1.0, "breast-maxcup": 0.1}},
}
BLEND_SHAPES = {  # name -> target suffix (gender filled in)
    "muscular": "young-maxmuscle-averageweight",
    "heavy": "young-averagemuscle-maxweight",
    "thin": "young-averagemuscle-minweight",
}

# Which skin region each bone belongs to (prefix match, first hit wins).
REGION_OF_BONE = [
    ("neck", "neck"), ("head", "head"), ("jaw", "head"), ("eye", "head"), ("levator", "head"),
    ("oculi", "head"), ("orbicularis", "head"), ("oris", "head"), ("risorius", "head"),
    ("special", "head"), ("temporalis", "head"), ("tongue", "head"),
    ("wrist", "hand"), ("metacarpal", "hand"), ("finger", "hand"),
    ("lowerarm", "lowerarm"), ("upperarm", "upperarm"), ("shoulder", "upperarm"),
    ("foot", "foot"), ("toe", "foot"), ("lowerleg", "lowerleg"), ("upperleg", "upperleg"),
]
REGIONS = ["head", "neck", "torso", "upperarm", "lowerarm", "hand", "upperleg", "lowerleg", "foot"]


def region_of(bone):
    for prefix, region in REGION_OF_BONE:
        if bone.startswith(prefix):
            return region
    return "torso"


def fetch():
    os.makedirs(SRC, exist_ok=True)
    for name, path in SOURCES.items():
        dest = os.path.join(SRC, name)
        if not os.path.exists(dest):
            print("downloading", name)
            urllib.request.urlretrieve(MH + path, dest)


# --------------------------------------------------------------------------- loading

def load_obj():
    v, vt, faces = [], [], []
    group = None
    with open(os.path.join(SRC, "base.obj")) as f:
        for line in f:
            if line.startswith("v "):
                v.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vt "):
                vt.append([float(x) for x in line.split()[1:3]])
            elif line.startswith("g "):
                group = line.split()[1]
            elif line.startswith("f "):
                corners = []
                for tok in line.split()[1:]:
                    p = tok.split("/")
                    corners.append((int(p[0]) - 1, int(p[1]) - 1 if len(p) > 1 and p[1] else -1))
                faces.append((group, corners))
    return np.array(v, dtype=np.float64), np.array(vt, dtype=np.float64), faces


def load_target(name):
    d = {}
    with open(os.path.join(SRC, name + ".target")) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            p = line.split()
            d[int(p[0])] = [float(p[1]), float(p[2]), float(p[3])]
    return d


def apply_target(verts, target, w):
    if not target or w == 0:
        return
    idx = np.fromiter(target.keys(), dtype=np.int64)
    delta = np.array(list(target.values()))
    verts[idx] += delta * w


def target_delta(n_verts, target):
    out = np.zeros((n_verts, 3))
    apply_target(out, target, 1.0)
    return out


# --------------------------------------------------------------------------- geometry

def vertex_normals(verts, tris):
    n = np.zeros_like(verts)
    a, b, c = verts[tris[:, 0]], verts[tris[:, 1]], verts[tris[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    ln[ln == 0] = 1
    return n / ln


def triangulate(faces, keep_groups, with_face=False):
    """Returns list of (group, [(v, vt) x3]) triangles (plus source face index if asked)."""
    out = []
    for fi, (g, c) in enumerate(faces):
        if g not in keep_groups:
            continue
        for i in range(1, len(c) - 1):
            out.append((g, [c[0], c[i], c[i + 1]], fi) if with_face else (g, [c[0], c[i], c[i + 1]]))
    return out


# --------------------------------------------------------------------------- skeleton

def build_skeleton(skel, verts):
    joints = {k: verts[v].mean(axis=0) for k, v in skel["joints"].items()}
    names = sorted(skel["bones"].keys(), key=lambda b: depth(skel, b))
    mats = {}
    for b in names:
        info = skel["bones"][b]
        head, tail = joints[info["head"]], joints[info["tail"]]
        y = tail - head
        y = y / (np.linalg.norm(y) or 1)
        p = [joints[j] for j in skel["planes"][info["rotation_plane"]]]
        nrm = np.cross(p[1] - p[0], p[2] - p[1])
        x = nrm - np.dot(nrm, y) * y
        if np.linalg.norm(x) < 1e-8:
            x = np.cross(y, [0, 0, 1.0])
            if np.linalg.norm(x) < 1e-8:
                x = np.cross(y, [1.0, 0, 0])
        x = x / np.linalg.norm(x)
        z = np.cross(x, y)
        m = np.eye(4)
        m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = x, y, z, head
        mats[b] = m
    return names, mats


def depth(skel, b):
    d = 0
    while skel["bones"][b]["parent"]:
        b = skel["bones"][b]["parent"]
        d += 1
    return d


def mat_to_quat(m):
    r = m[:3, :3]
    t = np.trace(r)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        w, x, y, z = 0.25 * s, (r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s
    elif r[0, 0] > r[1, 1] and r[0, 0] > r[2, 2]:
        s = np.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
        w, x, y, z = (r[2, 1] - r[1, 2]) / s, 0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s
    elif r[1, 1] > r[2, 2]:
        s = np.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
        w, x, y, z = (r[0, 2] - r[2, 0]) / s, (r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s
    else:
        s = np.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
        w, x, y, z = (r[1, 0] - r[0, 1]) / s, (r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def skin_weights(n_verts, weights, bone_index):
    per = [[] for _ in range(n_verts)]
    for bone, lst in weights.items():
        if bone not in bone_index:
            continue
        bi = bone_index[bone]
        for vi, w in lst:
            if vi < n_verts:
                per[vi].append((w, bi))
    joints = np.zeros((n_verts, 4), dtype=np.uint16)
    wts = np.zeros((n_verts, 4), dtype=np.float32)
    dominant = [None] * n_verts
    for i, lst in enumerate(per):
        lst.sort(reverse=True)
        lst = lst[:4]
        if not lst:
            lst = [(1.0, bone_index["head"])]
        tot = sum(w for w, _ in lst)
        for k, (w, b) in enumerate(lst):
            joints[i, k] = b
            wts[i, k] = w / tot
        dominant[i] = lst[0][1]
    return joints, wts, dominant


# --------------------------------------------------------------------------- glTF writer

class Glb:
    def __init__(self):
        self.bin = bytearray()
        self.gltf = {"asset": {"version": "2.0", "generator": "the-long-con build_characters.py"},
                     "buffers": [], "bufferViews": [], "accessors": [], "meshes": [],
                     "nodes": [], "materials": [], "skins": [], "scenes": [{"nodes": []}], "scene": 0}
        self.material_index = {}

    def accessor(self, arr, comp, typ, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin.extend(arr.tobytes())
        bv = {"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes}
        if target:
            bv["target"] = target
        self.gltf["bufferViews"].append(bv)
        acc = {"bufferView": len(self.gltf["bufferViews"]) - 1, "componentType": comp,
               "count": int(arr.shape[0]), "type": typ}
        if minmax:
            acc["min"] = arr.min(axis=0).astype(float).tolist()
            acc["max"] = arr.max(axis=0).astype(float).tolist()
        self.gltf["accessors"].append(acc)
        return len(self.gltf["accessors"]) - 1

    def material(self, name):
        if name not in self.material_index:
            self.gltf["materials"].append({"name": name, "pbrMetallicRoughness": {
                "baseColorFactor": [0.8, 0.8, 0.8, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.7}})
            self.material_index[name] = len(self.gltf["materials"]) - 1
        return self.material_index[name]

    def write(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.gltf["buffers"] = [{"byteLength": len(self.bin)}]
        js = json.dumps(self.gltf, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)


# --------------------------------------------------------------------------- build

def build_variant(name, spec, obj, skel, weights_json, targets):
    v0, vt, faces = obj
    verts = v0.copy()
    for t, w in spec["targets"].items():
        apply_target(verts, targets[t], w)
    g = spec["gender"]
    shape_deltas = {bs: target_delta(len(v0), targets[f"universal-{g}-{suffix}"]) * 0.1
                    for bs, suffix in BLEND_SHAPES.items()}

    # MakeHuman units are decimetres; move feet to y=0.
    verts *= 0.1
    ground = verts[skel["joints"]["ground"]].mean(axis=0) if "ground" in skel["joints"] else None
    floor_y = verts[:, 1].min() if ground is None else ground[1]
    body_tris_all = triangulate(faces, {"body"})
    body_vidx = np.unique([c[0] for _, tri in body_tris_all for c in tri])
    floor_y = verts[body_vidx, 1].min()
    verts[:, 1] -= floor_y

    bone_names, bone_mats = build_skeleton(skel, verts)
    bone_index = {b: i for i, b in enumerate(bone_names)}
    joints, wts, dominant = skin_weights(len(verts), weights_json["weights"], bone_index)
    region_v = [region_of(bone_names[d]) if d is not None else "torso" for d in dominant]

    tri_v = np.array([[c[0] for c in tri] for _, tri in body_tris_all])
    normals = vertex_normals(verts, tri_v)

    J = {k: verts[v].mean(axis=0) for k, v in skel["joints"].items()}

    def jp(bone, end="head"):
        return J[skel["bones"][bone][end]]

    eye_l, eye_r = jp("eye.L"), jp("eye.R")
    eye_y = (eye_l[1] + eye_r[1]) / 2
    head_top = verts[body_vidx, 1].max()
    neck_y = jp("neck01")[1]
    hip_y = jp("pelvis.L", "tail")[1]
    waist_y = jp("spine03")[1]
    ankle_y = jp("foot.L")[1]
    knee_y = jp("lowerleg01.L")[1]
    wrist_l = jp("wrist.L")
    ear_z = jp("head")[2] - 0.01

    # Classify whole source faces (quads), not triangles, so clothing edges stay clean.
    src_face = [fi for _, _, fi in triangulate(faces, {"body"}, with_face=True)]
    face_verts = {}
    for fi in set(src_face):
        face_verts[fi] = [c[0] for c in faces[fi][1]]
    face_region, face_center, face_normal = {}, {}, {}
    for fi, vs in face_verts.items():
        rs = [region_v[x] for x in vs]
        face_region[fi] = max(set(rs), key=rs.count)
        face_center[fi] = verts[vs].mean(axis=0)
        face_normal[fi] = normals[vs].mean(axis=0)
    tri_region = [face_region[fi] for fi in src_face]
    tri_center = np.array([face_center[fi] for fi in src_face])
    tri_normal = np.array([face_normal[fi] for fi in src_face])

    # Face paint masks in vertex colour: R lips, G brows, B stubble, A eye-socket shade.
    mouth = np.mean([jp(b) for b in ("oris01", "oris02", "oris05", "oris06")], axis=0)
    chin_y = mouth[1] - 0.045
    paint = np.zeros((len(verts), 4), dtype=np.float32)
    hv = np.array([i for i in body_vidx if region_v[i] in ("head", "neck")])
    P, Nn = verts[hv], normals[hv]
    front = np.clip((Nn[:, 2] - 0.05) / 0.4, 0, 1)

    def ellipse(cx, cy, rx, ry, cz=None):
        d = ((P[:, 0] - cx) / rx) ** 2 + ((P[:, 1] - cy) / ry) ** 2
        m = np.clip(1.0 - d, 0, 1) ** 0.7
        return m

    paint[hv, 0] = ellipse(mouth[0], mouth[1], 0.026, 0.011) * front * (P[:, 2] > mouth[2] - 0.02)
    brows = np.zeros(len(hv))
    for e in (eye_l, eye_r):
        side = np.sign(e[0])
        # brow arches: higher in the middle, thinning outwards
        t = np.clip((P[:, 0] - e[0]) * side / 0.03, -1, 1)
        cy = e[1] + 0.021 + 0.004 * (1 - t * t)
        d = ((P[:, 0] - (e[0] + side * 0.004)) / 0.026) ** 2 + ((P[:, 1] - cy) / (0.0045 * (1.2 - 0.5 * t))) ** 2
        brows = np.maximum(brows, np.clip(1.0 - d, 0, 1) ** 0.5)
    paint[hv, 1] = brows * front
    jaw_zone = (P[:, 1] < mouth[1] + 0.022) & (P[:, 1] > chin_y - 0.03) & (Nn[:, 1] > -0.85)
    stub = jaw_zone * np.clip((P[:, 2] - (jp("head")[2] - 0.0)) / 0.04, 0, 1)
    stub *= 1.0 - np.clip(paint[hv, 0] * 2, 0, 1)
    paint[hv, 2] = np.clip(stub, 0, 1)
    sock = np.zeros(len(hv))
    for e in (eye_l, eye_r):
        d = ((P[:, 0] - e[0]) / 0.024) ** 2 + ((P[:, 1] - (e[1] + 0.002)) / 0.016) ** 2
        sock = np.maximum(sock, np.clip(1.0 - d, 0, 1))
    paint[hv, 3] = sock * front

    g_out = Glb()
    # ---- skeleton nodes
    first_bone_node = 0
    for b in bone_names:
        parent = skel["bones"][b]["parent"]
        local = np.linalg.inv(bone_mats[parent]) @ bone_mats[b] if parent else bone_mats[b]
        g_out.gltf["nodes"].append({"name": b, "translation": local[:3, 3].tolist(),
                                    "rotation": mat_to_quat(local).tolist()})
    for b in bone_names:
        children = [bone_index[c] for c in bone_names if skel["bones"][c]["parent"] == b]
        if children:
            g_out.gltf["nodes"][bone_index[b]]["children"] = children
    roots = [bone_index[b] for b in bone_names if not skel["bones"][b]["parent"]]
    ibm = np.array([np.linalg.inv(bone_mats[b]).T.reshape(16) for b in bone_names], dtype=np.float32)
    g_out.gltf["skins"].append({"name": "MakeHumanRig", "joints": list(range(len(bone_names))),
                                "inverseBindMatrices": g_out.accessor(ibm, 5126, "MAT4"), "skeleton": roots[0]})
    scene_nodes = list(roots)

    def shell_positions(tris, offset, smooth):
        """Grow the surface along normals, then relax it so cloth hides anatomy."""
        used = np.unique([c[0] for tri in tris for c in tri])
        pos = verts.copy()
        pos[used] += normals[used] * offset
        if smooth <= 0:
            return pos
        edge_count = {}
        for tri in tris:
            a, b, c = (x[0] for x in tri)
            for u, w in ((a, b), (b, c), (c, a)):
                k = (min(u, w), max(u, w))
                edge_count[k] = edge_count.get(k, 0) + 1
        nbrs, bnb = {}, {}
        for (u, w), n in edge_count.items():
            nbrs.setdefault(u, set()).add(w)
            nbrs.setdefault(w, set()).add(u)
            if n == 1:
                bnb.setdefault(u, []).append(w)
                bnb.setdefault(w, []).append(u)
        # Relax the interior; rims stay pinned so cuffs and boot tops do not creep.
        keys = np.array([k for k in nbrs if k not in bnb])
        lists = [np.array(list(nbrs[k])) for k in keys]
        for _ in range(smooth):
            avg = np.array([pos[l].mean(axis=0) for l in lists])
            pos[keys] += 0.5 * (avg - pos[keys])
        # Straighten the zig-zag of open edges (necklines, cuffs, hairlines) along the boundary.
        if bnb:
            bkeys = np.array(list(bnb.keys()))
            blists = [np.array(bnb[k]) for k in bkeys]
            for _ in range(12):
                avg = np.array([pos[l].mean(axis=0) for l in blists])
                pos[bkeys] += 0.5 * (avg - pos[bkeys])
        # Never sink back into the body.
        d = np.einsum("ij,ij->i", pos[used] - verts[used], normals[used])
        push = np.maximum(0.0, offset * 0.7 - d)
        pos[used] += normals[used] * push[:, None]
        return pos

    def add_mesh(mesh_name, tris, offset=0.0, material=None, flip=False, smooth=0, colors=False, eye_center=None):
        """tris: list of [(v, vt) x3]; offset grows the surface along normals (clothing)."""
        if not tris:
            return
        shell = shell_positions(tris, offset, smooth) if offset > 0 else verts
        key = {}
        vi_list, uv_list, idx = [], [], []
        for tri in tris:
            order = tri[::-1] if flip else tri
            for c in order:
                if c not in key:
                    key[c] = len(vi_list)
                    vi_list.append(c[0])
                    uv_list.append(vt[c[1]] if c[1] >= 0 else (0.0, 0.0))
                idx.append(key[c])
        vi = np.array(vi_list)
        pos = shell[vi].astype(np.float32)
        nrm = (-normals[vi] if flip else normals[vi]).astype(np.float32)
        uv = np.array(uv_list, dtype=np.float32)
        uv[:, 1] = 1.0 - uv[:, 1]
        if eye_center is not None:
            # Spherical projection: pupil (straight ahead, +Z) at the texture centre.
            d = pos - eye_center
            d /= np.linalg.norm(d, axis=1, keepdims=True)
            theta = np.arccos(np.clip(d[:, 2], -1, 1))
            phi = np.arctan2(d[:, 1], d[:, 0])
            r = theta / np.pi * 0.5
            uv = np.stack([0.5 + r * np.cos(phi), 0.5 - r * np.sin(phi)], axis=1).astype(np.float32)
        prim = {"attributes": {
            "POSITION": g_out.accessor(pos, 5126, "VEC3", 34962, True),
            "NORMAL": g_out.accessor(nrm, 5126, "VEC3", 34962),
            "TEXCOORD_0": g_out.accessor(uv, 5126, "VEC2", 34962),
            "JOINTS_0": g_out.accessor(joints[vi], 5123, "VEC4", 34962),
            "WEIGHTS_0": g_out.accessor(wts[vi], 5126, "VEC4", 34962),
            **({"COLOR_0": g_out.accessor(paint[vi], 5126, "VEC4", 34962)} if colors else {})},
            "indices": g_out.accessor(np.array(idx, dtype=np.uint32), 5125, "SCALAR", 34963),
            "material": g_out.material(material or mesh_name),
            "targets": [{"POSITION": g_out.accessor(shape_deltas[bs][vi].astype(np.float32), 5126, "VEC3", 34962, True)}
                        for bs in BLEND_SHAPES]}
        g_out.gltf["meshes"].append({"name": mesh_name, "primitives": [prim],
                                     "weights": [0.0] * len(BLEND_SHAPES),
                                     "extras": {"targetNames": list(BLEND_SHAPES)}})
        g_out.gltf["nodes"].append({"name": mesh_name, "mesh": len(g_out.gltf["meshes"]) - 1, "skin": 0})
        scene_nodes.append(len(g_out.gltf["nodes"]) - 1)

    def select(pred):
        return [tri for i, (_, tri) in enumerate(body_tris_all) if pred(i)]

    R = tri_region
    C = tri_center
    N = tri_normal

    # ---- skin, split by region so outfits can hide what they cover
    for region in REGIONS:
        add_mesh("skin_" + region, select(lambda i, r=region: R[i] == region), 0.0, "skin", colors=True)

    # ---- helpers from the base mesh: eyes, hair cap
    for grp, mname in (("helper-l-eye", "eyes"), ("helper-r-eye", "eyes")):
        etris = [t for _, t in triangulate(faces, {grp})]
        ec = verts[np.unique([c[0] for t in etris for c in t])].mean(axis=0)
        add_mesh(mname + ("_l" if "-l-" in grp else "_r"), etris, 0.0, "eyes", eye_center=ec)

    def near_eyes(i, rad):
        return min(np.linalg.norm(C[i] - eye_l), np.linalg.norm(C[i] - eye_r)) < rad

    torso_like = {"torso", "upperarm", "lowerarm", "upperleg", "lowerleg", "neck"}
    shells = {
        # robbers
        "jumpsuit": (lambda i: R[i] in torso_like and not (R[i] == "neck" and C[i][1] > neck_y + 0.03)
                     and not (R[i] == "lowerleg" and C[i][1] < ankle_y + 0.10), 0.018),
        "gloves": (lambda i: R[i] == "hand" or (R[i] == "lowerarm" and np.linalg.norm(C[i][[0, 2]] - wrist_l[[0, 2]] * [np.sign(C[i][0]), 1]) < 0.05
                                                and abs(C[i][1] - wrist_l[1]) < 0.06), 0.006),
        "boots": (lambda i: R[i] == "foot" or (R[i] == "lowerleg" and C[i][1] < ankle_y + 0.16), 0.02),
        "mask": (lambda i: R[i] == "head" and N[i][2] > 0.25 and C[i][1] < head_top - 0.06 and C[i][1] > eye_y - 0.14
                 and not near_eyes(i, 0.016), 0.010),
        # police
        "uniform": (lambda i: R[i] in torso_like and not (R[i] == "neck" and C[i][1] > neck_y + 0.04)
                    and not (R[i] == "lowerleg" and C[i][1] < ankle_y + 0.10), 0.016),
        "balaclava": (lambda i: (R[i] == "head" or (R[i] == "neck")) and not (abs(C[i][1] - eye_y) < 0.022 and N[i][2] > 0.3), 0.005),
        "vest": (lambda i: R[i] == "torso" and waist_y - 0.08 < C[i][1] < neck_y - 0.05, 0.035),
        # civilians and guards
        "shirt": (lambda i: (R[i] == "torso" and C[i][1] > hip_y + 0.03) or R[i] == "upperarm"
                  or (R[i] == "neck" and C[i][1] < neck_y + 0.01), 0.014),
        "shirt_long": (lambda i: (R[i] == "torso" and C[i][1] > hip_y + 0.03) or R[i] in ("upperarm", "lowerarm")
                       or (R[i] == "neck" and C[i][1] < neck_y + 0.01), 0.014),
        "trousers": (lambda i: (R[i] == "torso" and C[i][1] < hip_y + 0.10) or R[i] == "upperleg"
                     or (R[i] == "lowerleg" and C[i][1] > ankle_y + 0.03), 0.02),
        "skirt_short": (lambda i: (R[i] == "torso" and C[i][1] < hip_y + 0.10) or (R[i] == "upperleg" and C[i][1] > knee_y + 0.12), 0.010),
        "shoes": (lambda i: R[i] == "foot" or (R[i] == "lowerleg" and C[i][1] < ankle_y + 0.04), 0.014),
    }
    head_c = jp("head", "tail")

    def is_face(i):
        c, n = C[i], N[i]
        hairline = eye_y + 0.065
        if c[1] < hairline and (n[2] > 0.15 or c[2] > head_c[2] + 0.03):
            return True
        # ears
        return abs(c[0]) > 0.062 and eye_y - 0.055 < c[1] < eye_y + 0.025 and abs(c[2] - head_c[2]) < 0.035

    shells["hair_short"] = (lambda i: R[i] == "head" and not is_face(i) and C[i][1] > neck_y + 0.055, 0.007)
    shells["helmet"] = (lambda i: R[i] == "head" and C[i][1] > eye_y + 0.004
                        and not (C[i][1] < eye_y + 0.045 and C[i][2] > head_c[2] + 0.02), 0.045)
    smooth = {"jumpsuit": 16, "uniform": 16, "trousers": 20, "shirt": 14, "shirt_long": 14, "skirt_short": 16,
              "vest": 24, "helmet": 30, "boots": 90, "shoes": 90, "balaclava": 3, "mask": 1, "gloves": 1, "hair_short": 6}
    for sname, (pred, off) in shells.items():
        add_mesh(sname, select(pred), off, sname, smooth=smooth.get(sname, 0))

    g_out.gltf["scenes"][0]["nodes"] = scene_nodes
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    g_out.write(path)
    print(f"{name}: {len(verts)} verts, {len(bone_names)} bones, {len(g_out.gltf['meshes'])} meshes, "
          f"{os.path.getsize(path) / 1e6:.1f} MB, height {verts[body_vidx, 1].max():.2f} m")


def main():
    fetch()
    obj = load_obj()
    skel = json.load(open(os.path.join(SRC, "default.mhskel")))
    weights_json = json.load(open(os.path.join(SRC, "default_weights.mhw")))
    targets = {n[:-len(".target")]: load_target(n[:-len(".target")]) for n in SOURCES if n.endswith(".target")}
    only = sys.argv[1:]
    for name, spec in VARIANTS.items():
        if not only or name in only:
            build_variant(name, spec, obj, skel, weights_json, targets)


if __name__ == "__main__":
    main()
