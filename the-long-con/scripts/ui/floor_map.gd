class_name FloorMap
extends Control
## Top-down floor plan of one bank floor. Used by the planning table and the
## in-game map overlay. With `intel` set, only scouted rooms and cameras are drawn.

const ROOM_ALPHA := 0.9

var bank: Dictionary
var floor_index := 0:
	set(v):
		floor_index = v
		queue_redraw()
var intel: Dictionary = {}          # Scouting.reveal() result, or {} for full knowledge
var player_cell := Vector2i(-1, -1)
var show_civilians := true


func set_bank(b: Dictionary, scouted: Dictionary = {}) -> void:
	bank = b
	intel = scouted
	floor_index = clampi(floor_index, 0, bank.floors.size() - 1)
	queue_redraw()


func ground_floor() -> int:
	for i in bank.floors.size():
		if bank.floors[i].level == 0:
			return i
	return 0


func _draw() -> void:
	if bank.is_empty():
		return
	var f: Dictionary = bank.floors[floor_index]
	var cs := minf(size.x / bank.w, size.y / bank.h)
	var origin := (size - Vector2(bank.w, bank.h) * cs) / 2.0
	var font := get_theme_default_font()
	var known: Dictionary = {}
	for ri in intel.get("known_rooms", []):
		known[ri] = true

	for ri in f.rooms:
		var room: Dictionary = bank.rooms[ri]
		var is_known := intel.is_empty() or known.has(ri)
		var col: Color = BankBuilder.COLORS.staff
		if is_known:
			col = _color(room)
		else:
			col = Color(0.15, 0.15, 0.17)
		for c in room.cells:
			draw_rect(Rect2(origin + Vector2(c.x, c.y) * cs, Vector2(cs, cs)), Color(col, ROOM_ALPHA))
	# Walls
	for y in bank.h:
		for x in bank.w:
			var ri: int = f.cells[y * bank.w + x]
			var p := origin + Vector2(x, y) * cs
			for side in ["n", "e", "s", "w"]:
				var n: Vector2i = Vector2i(x, y) + BankGenerator.DIRS[side]
				var outside: bool = n.x < 0 or n.y < 0 or n.x >= bank.w or n.y >= bank.h
				if not outside and f.cells[n.y * bank.w + n.x] == ri:
					continue
				var seg := _edge(p, cs, side)
				draw_line(seg[0], seg[1], Color(0.05, 0.05, 0.06), 3.0 if outside else 2.0)
	# Doors
	for d in bank.doors:
		if d.floor != floor_index:
			continue
		var p := origin + Vector2(d.cell[0], d.cell[1]) * cs
		var seg := _edge(p, cs, d.side)
		var mid: Vector2 = (seg[0] + seg[1]) / 2.0
		var dir: Vector2 = (seg[1] - seg[0]).normalized() * cs * 0.15
		var col := Color(0.95, 0.95, 0.9)
		if d.b == BankGenerator.EXTERIOR:
			col = Color(0.3, 0.9, 0.4)
		elif d.lock == "vault":
			col = Color(1.0, 0.8, 0.2)
		elif d.lock != "none" and intel.is_empty():
			col = Color(0.95, 0.3, 0.25)
		draw_line(mid - dir, mid + dir, col, 5.0)
	# Labels
	for ri in f.rooms:
		var room: Dictionary = bank.rooms[ri]
		if room.id == "corridor" or not (intel.is_empty() or known.has(ri)):
			continue
		var r: Array = room.rect
		var center := origin + Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0) * cs
		var fs := int(clampf(cs * 0.16, 9, 16))
		var text: String = room.name
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		if tw > r[2] * cs - 4:
			text = text.split(" ")[0]
			tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, center - Vector2(tw / 2.0, -fs / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.05, 0.05))
	# Cameras
	var known_cams: Array = intel.get("known_cameras", range(bank.security.cameras.size()))
	for i in known_cams:
		var cam: Dictionary = bank.security.cameras[i]
		if cam.floor != floor_index:
			continue
		var p := origin + (Vector2(cam.cell[0], cam.cell[1]) + Vector2(0.8, 0.2)) * cs
		var fwd := Vector2.UP.rotated(deg_to_rad(cam.yaw_deg)) * cs * 0.25
		draw_colored_polygon(PackedVector2Array([p, p + fwd.rotated(0.5), p + fwd.rotated(-0.5)]), Color(0.9, 0.1, 0.1, 0.7))
		draw_circle(p, cs * 0.05, Color(0.1, 0.1, 0.1))
	# Civilians (full-knowledge view only)
	if show_civilians and intel.is_empty():
		var per_cell := {}
		for civ in bank.civilians:
			if civ.floor != floor_index:
				continue
			var key := Vector2i(civ.cell[0], civ.cell[1])
			var k: int = per_cell.get(key, 0)
			per_cell[key] = k + 1
			var p := origin + (Vector2(key) + Vector2(0.2 + (k % 5) * 0.15, 0.75 - (k / 5) * 0.15)) * cs
			var col := Color(0.2, 0.4, 0.9)
			if civ.type in ["guard", "security_chief"]:
				col = Color(0.05, 0.1, 0.3)
			elif civ.type == "manager":
				col = Color(0.95, 0.7, 0.1)
			elif civ.armed:
				col = Color(0.9, 0.2, 0.2)
			draw_circle(p, cs * 0.05, col)
	# Player
	if player_cell.x >= 0:
		draw_circle(origin + (Vector2(player_cell) + Vector2(0.5, 0.5)) * cs, cs * 0.12, Color(0.1, 1.0, 0.3))
	# Title
	draw_rect(Rect2(0, 0, 330, 30), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(8, 22), "Floor %d  (level %+d, %s)" % [floor_index, f.level, f.type], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _edge(p: Vector2, cs: float, side: String) -> Array:
	match side:
		"n":
			return [p, p + Vector2(cs, 0)]
		"s":
			return [p + Vector2(0, cs), p + Vector2(cs, cs)]
		"w":
			return [p, p + Vector2(0, cs)]
	return [p + Vector2(cs, 0), p + Vector2(cs, cs)]


func _color(room: Dictionary) -> Color:
	for key in ["vault", "vertical", "route", "roof", "vehicles", "secure", "public", "staff_only", "staff"]:
		if key in room.tags:
			return BankBuilder.COLORS[key]
	return BankBuilder.COLORS.staff
