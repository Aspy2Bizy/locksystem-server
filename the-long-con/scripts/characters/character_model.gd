class_name CharacterModel
extends Node3D
## A rigged human (assets/characters/<variant>.glb, built from CC0 MakeHuman data)
## dressed in an outfit from data/outfits.json, with procedural PBR materials.
##
##   var c := CharacterModel.new()
##   add_child(c)
##   c.setup(DataDB.data, "male_a", "robber", rng)
##   c.pose("hands_up")

const ASSET_DIR := "res://assets/characters/"
const TEX_DIR := "res://assets/characters/textures/"
const CLOTHING := ["jumpsuit", "gloves", "boots", "mask", "uniform", "balaclava", "helmet", "vest",
	"shirt", "shirt_long", "trousers", "skirt_short", "shoes", "hair_short"]

static var _scenes := {}
static var _textures := {}

var variant := ""
var outfit_id := ""
var skeleton: Skeleton3D
var meshes := {}          # mesh name -> MeshInstance3D
var _model: Node3D


func setup(data: GameData, body_variant: String, outfit: String, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var cfg: Dictionary = data.raw.outfits
	variant = body_variant
	outfit_id = outfit
	if _model:
		_model.queue_free()
	_model = _scene(variant).instantiate()
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false)
	meshes.clear()
	for n in skeleton.get_children():
		if n is MeshInstance3D:
			meshes[String(n.name)] = n

	var o: Dictionary = cfg.outfits[outfit]
	var tones: Array = cfg.skin_tones[variant]
	var tone: Array = tones[rng.randi_range(0, tones.size() - 1)]
	var hc: Array = cfg.hair_colors[rng.randi_range(0, cfg.hair_colors.size() - 1)]
	var hair_color := Color(hc[0], hc[1], hc[2])
	var skin := _skin_material(Color(tone[0], tone[1], tone[2]), hair_color, rng)
	for region in ["head", "neck", "torso", "upperarm", "lowerarm", "hand", "upperleg", "lowerleg", "foot"]:
		var mi: MeshInstance3D = meshes["skin_" + region]
		mi.visible = region not in o.hide_skin
		mi.material_override = skin
	var eyes := _eye_material(rng)
	for e in ["eyes_l", "eyes_r"]:
		meshes[e].material_override = eyes
	var picked := {}
	for c in CLOTHING:
		var mi: MeshInstance3D = meshes.get(c)
		if mi == null:
			continue
		mi.visible = o.wear.has(c)
		if not mi.visible:
			continue
		var mat_id: String = o.wear[c]
		if mat_id == "hair":
			mi.material_override = _hair_material(hair_color)
		else:
			if not picked.has(mat_id):
				picked[mat_id] = _cloth_material(cfg.materials[mat_id], rng)
			mi.material_override = picked[mat_id]
	# Build variety: blend shapes and a small height spread.
	var muscular := rng.randf_range(0.0, 0.5)
	var heavy := rng.randf_range(0.0, 0.45) if rng.randf() < 0.5 else 0.0
	var thin := rng.randf_range(0.0, 0.4) if heavy == 0.0 and rng.randf() < 0.4 else 0.0
	for mi in meshes.values():
		mi.set("blend_shapes/muscular", muscular)
		mi.set("blend_shapes/heavy", heavy)
		mi.set("blend_shapes/thin", thin)
	scale = Vector3.ONE * rng.randf_range(0.96, 1.05)
	pose("stand")


## Random civilian of a civilians.json type, e.g. "customer", "manager".
static func random_civilian(data: GameData, civ_type: String, rng: RandomNumberGenerator) -> CharacterModel:
	var cfg: Dictionary = data.raw.outfits
	var variants: Array = cfg.body_variants
	var v: String = variants[rng.randi_range(0, variants.size() - 1)]
	var options: Array = cfg.civilian_outfit_for_type.get(civ_type, ["civilian"])
	var outfit: String = options[rng.randi_range(0, options.size() - 1)]
	if outfit == "civilian_skirt" and not v.begins_with("female"):
		outfit = "civilian"
	var c := CharacterModel.new()
	c.setup(data, v, outfit, rng)
	return c


func pose(pose_name: String) -> void:
	CharacterPoses.apply(skeleton, pose_name)


# --------------------------------------------------------------------------- materials

static func _scene(v: String) -> PackedScene:
	if not _scenes.has(v):
		_scenes[v] = load(ASSET_DIR + v + ".glb")
	return _scenes[v]


## Loads a texture and makes sure it has mipmaps (prevents shimmering on fine detail maps).
static func _tex(file: String) -> Texture2D:
	if not _textures.has(file):
		var t: Texture2D = load(TEX_DIR + file)
		var img := t.get_image()
		if img and not img.has_mipmaps():
			if img.is_compressed():
				img.decompress()
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
		_textures[file] = t
	return _textures[file]


const SKIN_SHADER := preload("res://shaders/skin.gdshader")


func _skin_material(tone: Color, hair: Color, rng: RandomNumberGenerator) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKIN_SHADER
	m.set_shader_parameter("tone", tone.lerp(Color(tone.r * 1.05, tone.g * 0.97, tone.b * 0.95), rng.randf()))
	m.set_shader_parameter("brow_color", hair.lerp(Color(0.04, 0.03, 0.03), 0.3))
	m.set_shader_parameter("brow_strength", rng.randf_range(0.7, 0.95))
	m.set_shader_parameter("stubble", rng.randf_range(0.0, 0.8) if variant.begins_with("male") else 0.0)
	m.set_shader_parameter("lip_tint", Color(0.62, 0.30, 0.30) if not variant.begins_with("female") or rng.randf() < 0.5
		else Color(0.70, 0.22, 0.26))
	m.set_shader_parameter("pores_normal", _tex("skin_pores_n.png"))
	m.set_shader_parameter("mottle", _tex("skin_mottle.png"))
	return m


func _cloth_material(def: Dictionary, rng: RandomNumberGenerator) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var col: Array = def.get("color", [0.5, 0.5, 0.5])
	if def.has("palette"):
		col = def.palette[rng.randi_range(0, def.palette.size() - 1)]
	m.albedo_color = Color(col[0], col[1], col[2])
	m.roughness = float(def.get("roughness", 0.8))
	var ns := float(def.get("normal_scale", 0.0))
	if def.has("normal") and ns > 0.0:
		m.normal_enabled = true
		m.normal_texture = _tex(def.normal)
		m.normal_scale = ns
		var s := float(def.get("uv_scale", 20))
		m.uv1_scale = Vector3(s, s, 1)
	var cc := float(def.get("clearcoat", 0.0))
	if cc > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = cc
		m.clearcoat_roughness = 0.4
	var sheen := float(def.get("sheen", 0.0))
	if sheen > 0.0:
		# Fabric catches light at grazing angles.
		m.rim_enabled = true
		m.rim = sheen * 0.35
		m.rim_tint = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _hair_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.78
	m.metallic_specular = 0.3
	m.normal_enabled = true
	m.normal_texture = _tex("hair_n.png")
	m.normal_scale = 0.8
	m.uv1_scale = Vector3(10, 10, 1)
	m.anisotropy_enabled = true
	m.anisotropy = 0.4
	return m


func _eye_material(rng: RandomNumberGenerator) -> StandardMaterial3D:
	var options := ["eye_brown", "eye_brown", "eye_dark", "eye_blue", "eye_green"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(options[rng.randi_range(0, options.size() - 1)] + ".png")
	m.roughness = 0.08
	m.metallic_specular = 0.6
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.02
	return m


## Shoulders a simple carbine (primitives; placeholder until real weapon art) and
## uses arm IK so both hands grip it. Call after pose("aim_rifle").
func hold_rifle() -> Node3D:
	var rifle := _build_rifle()
	skeleton.add_child(rifle)
	var eye := CharacterPoses.bone_pos(skeleton, "eye.R")
	var shoulder := CharacterPoses.bone_pos(skeleton, "upperarm01.R")
	# Stock in the shoulder pocket, sight line just under the right eye, pointing forward (+Z).
	var butt := Vector3(eye.x - 0.01, eye.y - 0.075, shoulder.z + 0.02)
	rifle.position = butt
	CharacterPoses.reach(skeleton, "R", butt + Vector3(0.0, -0.06, 0.22), Vector3(-1.0, -1.0, -0.3))
	CharacterPoses.reach(skeleton, "L", butt + Vector3(0.0, -0.035, 0.47), Vector3(0.6, -1.0, 0.0))
	return rifle


func _build_rifle() -> Node3D:
	var rifle := Node3D.new()
	rifle.name = "Rifle"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.06, 0.065, 0.07)
	metal.metallic = 0.7
	metal.roughness = 0.4
	var polymer := StandardMaterial3D.new()
	polymer.albedo_color = Color(0.09, 0.09, 0.085)
	polymer.roughness = 0.75
	# [size, centre] with the butt plate at z = 0 and the muzzle at z = +0.86.
	var parts := [
		[Vector3(0.05, 0.075, 0.22), Vector3(0, -0.005, 0.11), polymer],   # stock
		[Vector3(0.06, 0.07, 0.24), Vector3(0, 0.0, 0.33), polymer],       # receiver
		[Vector3(0.035, 0.11, 0.045), Vector3(0, -0.075, 0.27), polymer],  # pistol grip
		[Vector3(0.03, 0.14, 0.06), Vector3(0, -0.085, 0.38), metal],      # magazine
		[Vector3(0.055, 0.06, 0.24), Vector3(0, 0.0, 0.57), polymer],      # handguard
		[Vector3(0.018, 0.018, 0.16), Vector3(0, 0.005, 0.77), metal],     # barrel
		[Vector3(0.03, 0.03, 0.05), Vector3(0, 0.005, 0.84), metal],       # muzzle
		[Vector3(0.035, 0.045, 0.11), Vector3(0, 0.06, 0.34), metal],      # optic
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		mi.material_override = p[2]
		rifle.add_child(mi)
	return rifle
