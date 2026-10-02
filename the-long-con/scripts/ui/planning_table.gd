extends Control
## Plan-phase prototype: floor plans, vault intel and loadout detectability.
## Toggle between "scouted" (what your crew knows at this difficulty) and "full" (debug).

var bank: Dictionary
var intel: Dictionary
var _map: FloorMap
var _info: RichTextLabel
var _scouted := true
var _scout_btn: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.12, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	var bar := HBoxContainer.new()
	left.add_child(bar)
	_add_btn(bar, "< Menu", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_add_btn(bar, "Floor down", func(): _map.floor_index = maxi(0, _map.floor_index - 1))
	_add_btn(bar, "Floor up", func(): _map.floor_index = mini(bank.floors.size() - 1, _map.floor_index + 1))
	_scout_btn = _add_btn(bar, "", func():
		_scouted = not _scouted
		_refresh())
	_add_btn(bar, "New seed", func():
		Session.bank_seed = randi() % 1000000
		_generate())
	_add_btn(bar, "Walk it", func(): get_tree().change_scene_to_file("res://scenes/bank_sandbox.tscn"))

	_map = FloorMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_map)

	_info = RichTextLabel.new()
	_info.custom_minimum_size.x = 420
	_info.bbcode_enabled = true
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_info)
	_generate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_floor"):
		_map.floor_index = mini(bank.floors.size() - 1, _map.floor_index + 1)
	elif event.is_action_pressed("prev_floor"):
		_map.floor_index = maxi(0, _map.floor_index - 1)


func _add_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _generate() -> void:
	var gen := BankGenerator.new(DataDB.data)
	bank = gen.generate(Session.bank_seed, Session.stars)
	if bank.is_empty():
		_info.text = "[color=red]Generation failed[/color]\n" + "\n".join(gen.last_errors.slice(-5))
		return
	intel = Scouting.reveal(bank, DataDB.data, Session.bank_seed)
	_map.set_bank(bank)
	_map.floor_index = _map.ground_floor()
	_refresh()


func _refresh() -> void:
	_scout_btn.text = "View: scouted intel" if _scouted else "View: full (debug)"
	_map.set_bank(bank, intel if _scouted else {})
	var d := DataDB.data
	var t := d.tier(bank.stars)
	var v: Dictionary = bank.vault
	var s := ""
	s += "[font_size=22][b]Seed %d[/b][/font_size]\n" % bank.seed
	s += "%s  [b]%s[/b]\n" % ["*".repeat(bank.stars), t.name]
	s += "Payout x%.2f, scouting reveals %d%%\n\n" % [t.payout_multiplier, int(t.scouting_reveal_fraction * 100)]
	s += "[b]Building[/b]\n%d floors, %dx%d grid (%d m cells)\n" % [bank.floors.size(), bank.w, bank.h, int(bank.cell_size_m)]
	s += "Entries: %s\n" % ", ".join(bank.entries.map(func(e): return e.kind))
	s += "Escape routes: %s\n\n" % ", ".join(bank.escape_routes)
	s += "[b]Vault[/b]\n"
	if _scouted:
		s += "Layout: %s\n" % d.vault_layouts[intel.vault_layout].name
		s += "Lock: %s\n" % (d.vault_locks[intel.vault_lock].name if intel.vault_lock != "" else "%s (model unknown)" % intel.vault_lock_family)
		s += "Lockdown hazard: %s\n" % d.vault_hazards[intel.vault_hazard].name
		s += "Staff dependency: %s\n" % (d.staff_deps[intel.staff_dependency].name if intel.staff_dependency != "" else "unknown")
		s += "[i]Solutions not scouted - find them on site.[/i]\n\n"
		s += "[b]Security[/b]\n~%d guards, %d of %d cameras spotted\n~%d civilians\n" % [
			intel.guards_estimate, intel.known_cameras.size(), bank.security.cameras.size(), intel.civilians_estimate]
		s += "%d of %d rooms mapped\n" % [intel.known_rooms.size(), bank.rooms.size()]
	else:
		s += "Layout: %s\nLock: %s\nHazard: %s\nStaff: %s\n" % [
			d.vault_layouts[v.layout].name, d.vault_locks[v.lock].name, d.vault_hazards[v.hazard].name, d.staff_deps[v.staff_dependency].name]
		s += "[color=#9c9]Lock solutions:[/color] %s\n" % ", ".join(v.lock_solutions)
		s += "[color=#9c9]Hazard solutions:[/color] %s\n\n" % ", ".join(v.hazard_solutions)
		s += "[b]Security[/b]\n%d guards, %d cameras, %d civilians\n" % [bank.security.guards, bank.security.cameras.size(), bank.civilians.size()]
		var armed: Array = bank.civilians.filter(func(c): return c.armed and c.type not in ["guard", "security_chief"])
		s += "Armed civilians: %d\n" % armed.size()
	s += "\n[b]Loadout detectability[/b] (0 hidden - 100 obvious)\n"
	for lo in [
		{"name": "Pistol + lockpicks", "role": "breacher", "weapons": ["pistol_compact"], "armor": "none", "gadgets": ["lockpick_set"]},
		{"name": "SMG + vest + jammer", "role": "tech", "weapons": ["smg_compact"], "armor": "concealed_vest", "gadgets": ["jammer"]},
		{"name": "Rifle + plate + drill", "role": "breacher", "weapons": ["rifle_carbine"], "armor": "light_plate", "gadgets": ["drill"]},
		{"name": "Forger in uniform", "role": "medic_forger", "weapons": ["pistol_suppressed"], "armor": "none", "gadgets": ["staff_uniform", "med_kit"]},
	]:
		s += "  %s: [b]%d[/b]\n" % [lo.name, Detectability.score(d, lo)]
	s += "\n[color=#888]PageUp / PageDown change floor[/color]"
	_info.text = s
