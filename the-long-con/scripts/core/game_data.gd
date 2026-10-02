class_name GameData
extends RefCounted
## Loads every JSON file in res://data and indexes entries by id.
## Pure data: no nodes, so it works in tests, tools and on a dedicated server.

const DATA_DIR := "res://data"

var raw: Dictionary = {}          # file stem -> parsed JSON
var rooms: Dictionary = {}        # room id -> prefab
var tiers: Dictionary = {}        # stars (int) -> tier
var robber_roles: Dictionary = {}
var police_roles: Dictionary = {}
var weapons: Dictionary = {}
var armor: Dictionary = {}
var gadgets: Dictionary = {}
var parts: Dictionary = {}
var recipes: Dictionary = {}
var vault_layouts: Dictionary = {}
var vault_locks: Dictionary = {}
var vault_hazards: Dictionary = {}
var staff_deps: Dictionary = {}
var civilian_types: Dictionary = {}
var escape_routes: Dictionary = {}
var errors: PackedStringArray = []


static func load_default() -> GameData:
	var d := GameData.new()
	d.load_dir(DATA_DIR)
	return d


func load_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("cannot open %s" % dir_path)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(dir_path.path_join(file_name))
		var json := JSON.new()
		if json.parse(text) != OK:
			errors.append("%s:%d %s" % [file_name, json.get_error_line(), json.get_error_message()])
			continue
		raw[file_name.get_basename()] = json.data
	_index()


func _index() -> void:
	rooms = _by_id(_table("room_prefabs", "rooms"))
	for t in _table("difficulty_tiers", "tiers"):
		tiers[int(t.stars)] = t
	robber_roles = _by_id(_table("roles", "robber_roles"))
	police_roles = _by_id(_table("roles", "police_roles"))
	weapons = _by_id(_table("weapons_gadgets", "weapons"))
	armor = _by_id(_table("weapons_gadgets", "armor"))
	gadgets = _by_id(_table("weapons_gadgets", "gadgets"))
	gadgets.merge(_by_id(_table("weapons_gadgets", "crafted_only")))
	parts = _by_id(_table("weapons_gadgets", "parts"))
	recipes = _by_id(_table("weapons_gadgets", "recipes"))
	vault_layouts = _by_id(_table("vault_modules", "layouts"))
	vault_locks = _by_id(_table("vault_modules", "locks"))
	vault_hazards = _by_id(_table("vault_modules", "hazards"))
	staff_deps = _by_id(_table("vault_modules", "staff_dependencies"))
	civilian_types = _by_id(_table("civilians", "types"))
	escape_routes = _by_id(_table("escape_routes", "routes"))


func _table(file: String, key: String) -> Array:
	if not raw.has(file):
		errors.append("missing data file %s.json" % file)
		return []
	var v = raw[file].get(key)
	if v == null:
		errors.append("%s.json has no '%s'" % [file, key])
		return []
	return v


func _by_id(arr: Array) -> Dictionary:
	var out := {}
	for e in arr:
		if out.has(e.id):
			errors.append("duplicate id %s" % e.id)
		out[e.id] = e
	return out


func seed_config() -> Dictionary:
	return raw.get("seed_config", {})


func tier(stars: int) -> Dictionary:
	return tiers.get(clampi(stars, 1, 6), {})
