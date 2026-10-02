extends TestCase
## Character models: outfits reference real meshes and materials, poses and IK behave.


func test_outfit_data() -> void:
	var cfg: Dictionary = data.raw.outfits
	for v in cfg.body_variants:
		check(ResourceLoader.exists("res://assets/characters/%s.glb" % v), "missing model %s" % v)
		check(cfg.skin_tones.has(v), "no skin tones for %s" % v)
	for id in cfg.outfits:
		for mesh in cfg.outfits[id].wear:
			check(mesh in CharacterModel.CLOTHING, "%s wears unknown mesh %s" % [id, mesh])
			var mat: String = cfg.outfits[id].wear[mesh]
			check(mat == "hair" or cfg.materials.has(mat), "%s uses unknown material %s" % [id, mat])
	for t in data.civilian_types:
		check(cfg.civilian_outfit_for_type.has(t), "no outfit for civilian type %s" % t)


func test_every_outfit_builds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for v in data.raw.outfits.body_variants:
		for id in data.raw.outfits.outfits:
			var c := CharacterModel.new()
			c.setup(data, v, id, rng)
			check(c.skeleton != null and c.skeleton.get_bone_count() == 163, "%s/%s skeleton" % [v, id])
			for mesh in data.raw.outfits.outfits[id].wear:
				check(c.meshes[mesh].visible, "%s/%s shows %s" % [v, id, mesh])
			c.free()


func test_ik_reaches_target() -> void:
	var c := CharacterModel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	c.setup(data, "male_a", "robber")
	var sk := c.skeleton
	var target := CharacterPoses.bone_pos(sk, "upperarm01.R") + Vector3(-0.1, -0.2, 0.35)
	CharacterPoses.reach(sk, "R", target, Vector3(-1, -1, 0))
	var err := CharacterPoses.bone_pos(sk, "wrist.R").distance_to(target)
	check(err < 0.01, "wrist within 1 cm of IK target (%.3f m)" % err)
	for p in CharacterPoses.POSES:
		c.pose(p)
	c.free()
