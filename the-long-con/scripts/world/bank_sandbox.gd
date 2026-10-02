extends Node3D
## Walk a generated bank in first person. F5 = new seed, M = map, Esc = free mouse.

var bank: Dictionary
var builder: BankBuilder
var player: PlayerController
var _hud_label: Label
var _prompt: Label
var _map: FloorMap
var _map_panel: PanelContainer


func _ready() -> void:
	_setup_environment()
	builder = BankBuilder.new()
	add_child(builder)
	player = PlayerController.new()
	add_child(player)
	_setup_hud()
	player.interact_target_changed.connect(func(t): _prompt.text = t)
	_generate(Session.bank_seed)


func _generate(bank_seed: int) -> void:
	Session.bank_seed = bank_seed
	var gen := BankGenerator.new(DataDB.data)
	bank = gen.generate(bank_seed, Session.stars)
	if bank.is_empty():
		_hud_label.text = "Generation failed:\n" + "\n".join(gen.last_errors.slice(-3))
		return
	builder.build(bank)
	_map.set_bank(bank)
	Events.bank_generated.emit(bank)
	# Spawn just inside the main entrance, facing into the lobby.
	for e in bank.entries:
		if e.kind != "main_entrance":
			continue
		for di in bank.rooms[e.room].doors:
			var d: Dictionary = bank.doors[di]
			if d.b != BankGenerator.EXTERIOR:
				continue
			var out: Vector2i = BankGenerator.DIRS[d.side]
			var c := Vector2i(d.cell[0], d.cell[1])
			player.global_position = builder.cell_center(d.floor, c) + Vector3(out.x, 0, out.y) * (builder.cell * 0.3) + Vector3(0, 0.2, 0)
			player.rotation.y = atan2(float(out.x), float(out.y))
			player.velocity = Vector3.ZERO


func _process(_dt: float) -> void:
	if bank.is_empty():
		return
	var loc := builder.locate(player.global_position)
	var where := "outside"
	if loc.floor >= 0:
		var room: Dictionary = bank.rooms[loc.room]
		where = "%s  |  floor %+d (%s)" % [room.name, bank.floors[loc.floor].level, bank.floors[loc.floor].type]
		_map.player_cell = loc.cell
		if _map.floor_index != loc.floor and _map_panel.visible:
			_map.floor_index = loc.floor
	_hud_label.text = "Seed %d  %s  |  %s\nWASD move, Shift sprint, Ctrl crouch, E use, M map, F5 new bank, Esc mouse" % [
		bank.seed, "*".repeat(bank.stars), where]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("regenerate"):
		_generate(randi() % 1000000)
	elif event.is_action_pressed("toggle_map"):
		_map_panel.visible = not _map_panel.visible
		var loc := builder.locate(player.global_position)
		if loc.floor >= 0:
			_map.floor_index = loc.floor
	elif event.is_action_pressed("next_floor"):
		_map.floor_index = mini(bank.floors.size() - 1, _map.floor_index + 1)
	elif event.is_action_pressed("prev_floor"):
		_map.floor_index = maxi(0, _map.floor_index - 1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	add_child(sun)


func _setup_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 8)
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_child(_hud_label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(4, 12)
	hud.add_child(cross)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position += Vector2(-120, 30)
	_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_child(_prompt)
	_map_panel = PanelContainer.new()
	_map_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_map_panel.custom_minimum_size = Vector2(520, 520)
	_map_panel.position = Vector2(-530, 10)
	_map_panel.visible = false
	hud.add_child(_map_panel)
	_map = FloorMap.new()
	_map.custom_minimum_size = Vector2(520, 520)
	_map_panel.add_child(_map)
