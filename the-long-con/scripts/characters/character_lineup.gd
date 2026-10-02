extends Node3D
## Studio view of the character models. Arrow keys orbit, mouse wheel zooms, R re-rolls.
## DevTools arg --view=lineup|robber|police|civilians picks the camera framing.

const LINEUP := [
	["male_a", "robber", "stand"],
	["male_b", "robber_heavy", "aim_rifle"],
	["female_a", "robber", "hands_up"],
	["male_c", "police_assault", "aim_rifle"],
	["female_b", "police_officer", "stand"],
	["male_a", "guard", "stand"],
	["female_c", "civilian_skirt", "stand"],
	["male_b", "civilian", "hands_up"],
	["female_a", "civilian_formal", "kneel_hostage"],
]

var cam: Camera3D
var _yaw := 0.0
var _pitch := -6.0
var _dist := 9.0
var _target := Vector3(0, 1.0, 0)
var _seed := 7


func _ready() -> void:
	_setup_studio()
	_spawn()
	if DevTools._args.has("shots"):
		_capture_all.call_deferred(String(DevTools._args.shots))
		return
	_set_view(DevTools._args.get("view", "lineup"))


## Saves one screenshot per view into `dir`, then quits. Used for automated review.
func _capture_all(dir: String) -> void:
	for v in ["lineup", "robber", "police", "civilians", "face"]:
		_set_view(v)
		for i in 25:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir.path_join(v + ".png"))
		print("saved ", v)
	get_tree().quit()


func _set_view(view: String) -> void:
	_yaw = 0.0
	_pitch = -6.0
	_dist = 9.0
	_target = Vector3(0, 1.0, 0)
	match view:
		"robber":
			_target = Vector3(-4.0, 1.45, 0)
			_dist = 2.2
			_yaw = 12.0
		"police":
			_target = Vector3(-0.5, 1.4, 0)
			_dist = 2.6
			_yaw = -18.0
		"civilians":
			_target = Vector3(3.0, 1.0, 0)
			_dist = 5.5
		"face":
			_target = Vector3(2.0, 1.55, 0)
			_dist = 0.85
			_yaw = 15.0
	_update_cam()


func _spawn() -> void:
	for c in get_children():
		if c is CharacterModel:
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for i in LINEUP.size():
		var e: Array = LINEUP[i]
		var c := CharacterModel.new()
		add_child(c)
		c.setup(DataDB.data, e[0], e[1], rng)
		c.pose(e[2])
		if e[2] == "aim_rifle":
			c.hold_rifle()
		c.position = Vector3((i - (LINEUP.size() - 1) / 2.0) * 1.0, 0, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _yaw -= 10
			KEY_RIGHT: _yaw += 10
			KEY_UP: _pitch = clampf(_pitch + 5, -60, 30)
			KEY_DOWN: _pitch = clampf(_pitch - 5, -60, 30)
			KEY_R:
				_seed += 1
				_spawn()
			KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _dist = maxf(0.6, _dist * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _dist = minf(20.0, _dist * 1.1)
	_update_cam()


func _update_cam() -> void:
	var dir := Basis(Vector3.UP, deg_to_rad(_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(_pitch)) * Vector3(0, 0, 1)
	cam.position = _target + dir * _dist
	cam.look_at(_target)


func _setup_studio() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.055, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.68)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	e.ssao_radius = 0.6
	e.ssao_intensity = 2.0
	e.ssil_enabled = true
	env.environment = e
	add_child(env)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.17)
	fm.roughness = 0.7
	floor_mi.material_override = fm
	add_child(floor_mi)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 28, 0)
	key.light_energy = 2.2
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -60, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.75, 0.82, 1.0)
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 165, 0)
	rim.light_energy = 1.6
	rim.light_color = Color(0.85, 0.9, 1.0)
	add_child(rim)

	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
