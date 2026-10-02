class_name BankGenerator
extends RefCounted
## Builds a multi-story bank from a seed.
##
## Steps (blueprint "Bank generation"):
##   1 shell     floor stack + grid size
##   2 anchors   stairs and elevator aligned vertically, lobby, vault
##   3 routes    one corridor spine row and column per floor (shared so stairs line up)
##   4 required  rooms placed by tag rules
##   5 filler    1x1 rooms fill every free cell
##   6 validate  BankValidator; a failure re-rolls with the next attempt number
##
## Output is a plain Dictionary so it can be saved as JSON, diffed in tests, and
## rebuilt identically on every client from the seed alone.

const DIRS := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}
const OPPOSITE := {"n": "s", "s": "n", "e": "w", "w": "e"}
const EXTERIOR := -1
const CORRIDOR_ID := "corridor"

var data: GameData
var rng := RandomNumberGenerator.new()
var last_errors: PackedStringArray = []
var _fail_reason := ""


func _init(game_data: GameData) -> void:
	data = game_data


## Returns a valid bank, or {} if every attempt failed (see last_errors).
func generate(bank_seed: int, stars: int) -> Dictionary:
	last_errors = []
	var max_attempts := int(data.seed_config().validation.max_attempts)
	for attempt in max_attempts:
		rng.seed = mix_seed(bank_seed, attempt)
		_fail_reason = ""
		var bank := _build(bank_seed, stars)
		if bank.is_empty():
			last_errors.append("attempt %d: %s" % [attempt, _fail_reason])
			continue
		var errs := BankValidator.validate(bank, data)
		if errs.is_empty():
			bank.attempt = attempt
			return bank
		last_errors.append("attempt %d: %s" % [attempt, "; ".join(errs)])
	return {}


static func mix_seed(bank_seed: int, attempt: int) -> int:
	# Simple deterministic mix; avoids relying on hash() implementation details.
	var x := bank_seed * 6364136223846793005 + (attempt + 1) * 1442695040888963407
	x = x ^ (x >> 29)
	return x & 0x7FFFFFFFFFFFFFFF


# ---------------------------------------------------------------------------
# Build

func _build(bank_seed: int, stars: int) -> Dictionary:
	var cfg := data.seed_config()
	var w := rng.randi_range(int(cfg.grid.min[0]), int(cfg.grid.max[0]))
	var h := rng.randi_range(int(cfg.grid.min[1]), int(cfg.grid.max[1]))
	var bank := {
		"seed": bank_seed, "stars": stars, "attempt": -1,
		"w": w, "h": h,
		"cell_size_m": float(cfg.cell_size_m), "floor_height_m": float(cfg.floor_height_m),
		"floors": [], "rooms": [], "doors": [], "vertical_links": [], "entries": [],
	}

	# 1. Shell
	var types: Array[String] = []
	for e in cfg.floor_stack.order:
		for i in rng.randi_range(int(e.count[0]), int(e.count[1])):
			types.append(e.type)
	var ground := types.find(cfg.floor_stack.ground_floor_type)
	for i in types.size():
		var cells := PackedInt32Array()
		cells.resize(w * h)
		cells.fill(-1)
		bank.floors.append({"level": i - ground, "type": types[i], "cells": cells, "rooms": []})

	# 2-3. Spine and vertical anchors, shared by all floors
	var spine_r := rng.randi_range(2, h - 3)
	var spine_c := rng.randi_range(2, w - 3)
	var sx := 1 if rng.randf() < 0.5 else -1
	var sy := 1 if rng.randf() < 0.5 else -1
	var stair_cell := Vector2i(spine_c + sx, spine_r + sy)
	var lift_cell := Vector2i(spine_c - sx, spine_r + sy)

	for fi in bank.floors.size():
		var corridor_cells: Array[Vector2i] = []
		for x in w:
			corridor_cells.append(Vector2i(x, spine_r))
		for y in h:
			if y != spine_r:
				corridor_cells.append(Vector2i(spine_c, y))
		_add_room(bank, fi, data.rooms[CORRIDOR_ID], corridor_cells)
		_add_room(bank, fi, data.rooms["stairwell"], [stair_cell])
		_add_room(bank, fi, data.rooms["elevator"], [lift_cell])

	# 4. Required rooms: per-floor lists, then once-per-building rooms on a random allowed floor
	var required: Array = []
	for fi in bank.floors.size():
		required.append(Array(cfg.required_per_floor.get(bank.floors[fi].type, [])).duplicate())
	for room_id in cfg.required_once.rooms:
		if _building_has(bank, required, room_id):
			continue
		var prefab: Dictionary = data.rooms[room_id]
		var floor_tags: Array = prefab.get("rules", {}).get("requires_on_floor", [])
		var options: Array[int] = []
		for fi in bank.floors.size():
			var ftype: String = bank.floors[fi].type
			if ftype in prefab.floors and floor_tags.all(func(t): return _provider_for(t, ftype) != ""):
				options.append(fi)
		if options.is_empty():
			_fail_reason = "no floor allows %s" % room_id
			return {}
		var fi: int = options[rng.randi_range(0, options.size() - 1)]
		required[fi].append(room_id)
		# Bring along whatever this room needs on its floor (server room -> power + cooling).
		for t in floor_tags:
			if not required[fi].any(func(id): return t in data.rooms[id].tags):
				required[fi].append(_provider_for(t, bank.floors[fi].type))

	for fi in bank.floors.size():
		for room_id in required[fi]:
			var prefab: Dictionary = data.rooms[room_id]
			var needs_corridor: bool = not prefab.get("rules", {}).has("requires_adjacent")
			if _try_place(bank, fi, prefab, needs_corridor) < 0:
				_fail_reason = "could not place %s on floor %d (%s)" % [room_id, fi, bank.floors[fi].type]
				return {}

	# Optional rooms: a few weighted tries per floor
	for fi in bank.floors.size():
		var ftype: String = bank.floors[fi].type
		var options := data.rooms.values().filter(func(r): return r.kind == "optional" and ftype in r.floors)
		for i in 16:
			if options.is_empty():
				break
			var prefab: Dictionary = _pick_weighted(options)
			if _count_on_floor(bank, fi, prefab.id) >= int(prefab.get("max_per_floor", 99)):
				continue
			_try_place(bank, fi, prefab, true)

	# 5. Fillers
	for fi in bank.floors.size():
		var ftype: String = bank.floors[fi].type
		var fillers := data.rooms.values().filter(func(r): return r.kind == "filler" and ftype in r.floors)
		var free: Array[Vector2i] = []
		for y in h:
			for x in w:
				if bank.floors[fi].cells[y * w + x] < 0:
					free.append(Vector2i(x, y))
		_shuffle(free)
		for cell in free:
			var ok := false
			var pool := fillers.duplicate()
			while not pool.is_empty():
				var prefab: Dictionary = _pick_weighted(pool)
				pool.erase(prefab)
				if _rules_ok(bank, fi, [cell], prefab):
					_add_room(bank, fi, prefab, [cell])
					ok = true
					break
			if not ok:
				_fail_reason = "no filler fits %s on floor %d" % [cell, fi]
				return {}

	_cut_doors(bank)
	_link_vertical(bank)
	_mark_entries(bank)
	BankContents.populate(bank, data, rng)
	return bank


## First non-filler prefab with `tag` that may sit on a floor of `ftype`, or "".
func _provider_for(tag: String, ftype: String) -> String:
	for r in data.rooms.values():
		if r.kind in ["required", "anchor", "optional"] and tag in r.tags and ftype in r.floors:
			return r.id
	return ""


func _building_has(bank: Dictionary, required: Array, room_id: String) -> bool:
	for list in required:
		if room_id in list:
			return true
	return false


# ---------------------------------------------------------------------------
# Placement

func _try_place(bank: Dictionary, fi: int, prefab: Dictionary, needs_corridor: bool) -> int:
	var w: int = bank.w
	var h: int = bank.h
	var sizes: Array[Vector2i] = [Vector2i(prefab.size[0], prefab.size[1])]
	if prefab.size[0] != prefab.size[1]:
		sizes.append(Vector2i(prefab.size[1], prefab.size[0]))
	var candidates: Array = []
	for s in sizes:
		for y in range(0, h - s.y + 1):
			for x in range(0, w - s.x + 1):
				var cells: Array[Vector2i] = []
				var free := true
				for dy in s.y:
					for dx in s.x:
						var c := Vector2i(x + dx, y + dy)
						if bank.floors[fi].cells[c.y * w + c.x] >= 0:
							free = false
						cells.append(c)
				if not free:
					continue
				var on_edge := x == 0 or y == 0 or x + s.x == w or y + s.y == h
				if prefab.get("outer_edge", false) and not on_edge:
					continue
				if prefab.get("inner_only", false) and on_edge:
					continue
				if needs_corridor and not _touches_id(bank, fi, cells, CORRIDOR_ID):
					continue
				if not _rules_ok(bank, fi, cells, prefab):
					continue
				candidates.append(cells)
	if candidates.is_empty():
		return -1
	return _add_room(bank, fi, prefab, candidates[rng.randi_range(0, candidates.size() - 1)])


func _rules_ok(bank: Dictionary, fi: int, cells: Array, prefab: Dictionary) -> bool:
	var rules: Dictionary = prefab.get("rules", {})
	var never: Array = rules.get("never_adjacent", [])
	var needs: Array = rules.get("requires_adjacent", [])
	var needs_met := needs.is_empty()
	for ni in _neighbour_rooms(bank, fi, cells):
		var other: Dictionary = bank.rooms[ni]
		if _shares(never, other.tags):
			return false
		if _shares(other.get("rules", {}).get("never_adjacent", []), prefab.tags):
			return false
		if _shares(needs, other.tags):
			needs_met = true
	return needs_met


func _neighbour_rooms(bank: Dictionary, fi: int, cells: Array) -> Array[int]:
	var out: Array[int] = []
	var w: int = bank.w
	for c in cells:
		for d in DIRS.values():
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= bank.h or n in cells:
				continue
			var ri: int = bank.floors[fi].cells[n.y * w + n.x]
			if ri >= 0 and ri not in out:
				out.append(ri)
	return out


func _touches_id(bank: Dictionary, fi: int, cells: Array, room_id: String) -> bool:
	for ni in _neighbour_rooms(bank, fi, cells):
		if bank.rooms[ni].id == room_id:
			return true
	return false


func _add_room(bank: Dictionary, fi: int, prefab: Dictionary, cells: Array) -> int:
	var idx: int = bank.rooms.size()
	var min_c := Vector2i(1 << 20, 1 << 20)
	var max_c := Vector2i(-1, -1)
	for c in cells:
		bank.floors[fi].cells[c.y * bank.w + c.x] = idx
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	bank.rooms.append({
		"idx": idx, "id": prefab.id, "name": prefab.name, "kind": prefab.kind, "floor": fi,
		"cells": cells.duplicate(), "rect": [min_c.x, min_c.y, max_c.x - min_c.x + 1, max_c.y - min_c.y + 1],
		"tags": prefab.tags.duplicate(), "rules": prefab.get("rules", {}),
		"door_sides": prefab.door_sides, "max_doors": int(prefab.get("max_doors", 99)),
		"door_to_tags": prefab.get("door_to_tags", []), "doors": [],
	})
	bank.floors[fi].rooms.append(idx)
	return idx


func _count_on_floor(bank: Dictionary, fi: int, room_id: String) -> int:
	var n := 0
	for ri in bank.floors[fi].rooms:
		if bank.rooms[ri].id == room_id:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Doors and links

func _cut_doors(bank: Dictionary) -> void:
	for fi in bank.floors.size():
		var corridor: int = bank.floors[fi].rooms[0]
		var connected := {corridor: true}
		var pending: Array = bank.floors[fi].rooms.slice(1)
		var progress := true
		while progress and not pending.is_empty():
			progress = false
			_shuffle(pending)
			for ri in pending.duplicate():
				var edges := _door_edges(bank, fi, ri, connected)
				if edges.is_empty():
					continue
				var to_corridor := edges.filter(func(e): return e.to == corridor)
				var pool: Array = to_corridor if not to_corridor.is_empty() else edges
				_add_door(bank, pool[rng.randi_range(0, pool.size() - 1)])
				connected[ri] = true
				pending.erase(ri)
				progress = true
		# A few extra doors between neighbours give alternate routes.
		for ri in bank.floors[fi].rooms:
			if rng.randf() < 0.2:
				var all_connected := {}
				for rj in bank.floors[fi].rooms:
					all_connected[rj] = true
				var edges := _door_edges(bank, fi, ri, all_connected).filter(
					func(e): return not _has_door_between(bank, e.from, e.to))
				if not edges.is_empty():
					_add_door(bank, edges[rng.randi_range(0, edges.size() - 1)])


## Candidate wall edges from room ri to any room in `targets`.
func _door_edges(bank: Dictionary, fi: int, ri: int, targets: Dictionary) -> Array:
	var room: Dictionary = bank.rooms[ri]
	var out: Array = []
	if room.doors.size() >= room.max_doors:
		return out
	for c in room.cells:
		for side in DIRS:
			if side not in room.door_sides:
				continue
			var n: Vector2i = c + DIRS[side]
			if n.x < 0 or n.y < 0 or n.x >= bank.w or n.y >= bank.h:
				continue
			var ni: int = bank.floors[fi].cells[n.y * bank.w + n.x]
			if ni == ri or not targets.has(ni):
				continue
			var other: Dictionary = bank.rooms[ni]
			if OPPOSITE[side] not in other.door_sides or other.doors.size() >= other.max_doors:
				continue
			if not room.door_to_tags.is_empty() and not _shares(room.door_to_tags, other.tags):
				continue
			if not other.door_to_tags.is_empty() and not _shares(other.door_to_tags, room.tags):
				continue
			out.append({"from": ri, "to": ni, "cell": c, "side": side})
	return out


func _add_door(bank: Dictionary, e: Dictionary) -> void:
	var di: int = bank.doors.size()
	bank.doors.append({"idx": di, "a": e.from, "b": e.to, "floor": bank.rooms[e.from].floor,
		"cell": [e.cell.x, e.cell.y], "side": e.side, "lock": "none"})
	bank.rooms[e.from].doors.append(di)
	if e.to != EXTERIOR:
		bank.rooms[e.to].doors.append(di)


func _has_door_between(bank: Dictionary, a: int, b: int) -> bool:
	for di in bank.rooms[a].doors:
		var d: Dictionary = bank.doors[di]
		if (d.a == a and d.b == b) or (d.a == b and d.b == a):
			return true
	return false


func _link_vertical(bank: Dictionary) -> void:
	for fi in range(bank.floors.size() - 1):
		for slot in [1, 2]:  # stairwell, elevator are always rooms 1 and 2 on each floor
			bank.vertical_links.append([bank.floors[fi].rooms[slot], bank.floors[fi + 1].rooms[slot]])


func _mark_entries(bank: Dictionary) -> void:
	for room in bank.rooms:
		var entry: String = data.rooms[room.id].get("entry", "")
		if entry == "":
			continue
		var outer: Array = []
		for c in room.cells:
			for side in DIRS:
				var n: Vector2i = c + DIRS[side]
				if n.x < 0 or n.y < 0 or n.x >= bank.w or n.y >= bank.h:
					outer.append({"from": room.idx, "to": EXTERIOR, "cell": c, "side": side})
		if not outer.is_empty():
			_add_door(bank, outer[rng.randi_range(0, outer.size() - 1)])
		bank.entries.append({"room": room.idx, "kind": entry})


# ---------------------------------------------------------------------------
# Helpers

static func _shares(a: Array, b: Array) -> bool:
	for x in a:
		if x in b:
			return true
	return false


func _pick_weighted(options: Array) -> Dictionary:
	var total := 0.0
	for o in options:
		total += float(o.get("weight", 1))
	var roll := rng.randf() * total
	for o in options:
		roll -= float(o.get("weight", 1))
		if roll <= 0.0:
			return o
	return options.back()


func _shuffle(arr: Array) -> void:
	# Fisher-Yates on our own rng so results are seed-stable (Array.shuffle uses the global rng).
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
