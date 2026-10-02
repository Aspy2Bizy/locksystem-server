class_name BankBuilder
extends Node3D
## Turns a generated bank Dictionary into walkable greybox geometry:
## floor slabs, walls with door gaps, doors, room labels, cameras and civilian markers.
## This is placeholder art. Later, swap _room_floor / _wall for real room prefab scenes.

const WALL_T := 0.2
const SLAB_T := 0.2
const DOOR_W := 1.4
const DOOR_H := 2.4
const PARAPET_H := 1.1

const COLORS := {
	"route": Color(0.55, 0.55, 0.52),
	"public": Color(0.78, 0.70, 0.58),
	"staff": Color(0.70, 0.72, 0.74),
	"staff_only": Color(0.52, 0.58, 0.66),
	"secure": Color(0.32, 0.34, 0.38),
	"vault": Color(0.75, 0.62, 0.25),
	"vertical": Color(0.40, 0.55, 0.45),
	"roof": Color(0.30, 0.30, 0.32),
	"vehicles": Color(0.35, 0.35, 0.37),
	"wall": Color(0.86, 0.86, 0.84),
	"wall_ext": Color(0.45, 0.47, 0.50),
	"door": Color(0.45, 0.30, 0.18),
	"door_locked": Color(0.65, 0.15, 0.12),
	"door_vault": Color(0.85, 0.75, 0.30),
	"camera": Color(0.10, 0.10, 0.10),
	"civilian": Color(0.20, 0.45, 0.85),
	"guard": Color(0.10, 0.15, 0.35),
	"vip": Color(0.85, 0.65, 0.10),
	"armed": Color(0.80, 0.20, 0.20),
}

var bank: Dictionary
var data: GameData      ## set by the owner; needed to dress civilians
var cell := 6.0
var floor_h := 4.0
var _mats := {}


func build(b: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	bank = b
	cell = bank.cell_size_m
	floor_h = bank.floor_height_m
	for fi in bank.floors.size():
		var floor_node := Node3D.new()
		floor_node.name = "Floor_%d_%s" % [fi, bank.floors[fi].type]
		floor_node.position.y = bank.floors[fi].level * floor_h
		add_child(floor_node)
		_build_floor(fi, floor_node)
	_build_ground()
	_build_markers()
	_build_floor_links()


## World position of the centre of a cell on a floor (at floor height).
func cell_center(fi: int, c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell, bank.floors[fi].level * floor_h, (c.y + 0.5) * cell)


## Which floor index and cell a world position is in, or fi = -1 if outside.
func locate(p: Vector3) -> Dictionary:
	var fi := -1
	for i in bank.floors.size():
		if p.y >= bank.floors[i].level * floor_h - 0.5:
			fi = i
	var c := Vector2i(floori(p.x / cell), floori(p.z / cell))
	if fi < 0 or c.x < 0 or c.y < 0 or c.x >= bank.w or c.y >= bank.h:
		return {"floor": -1}
	return {"floor": fi, "cell": c, "room": bank.floors[fi].cells[c.y * bank.w + c.x]}


func _build_floor(fi: int, parent: Node3D) -> void:
	var f: Dictionary = bank.floors[fi]
	var outdoor_floor: bool = f.type == "roof"
	# Slabs, one per room
	for ri in f.rooms:
		var room: Dictionary = bank.rooms[ri]
		var r: Array = room.rect
		for c in room.cells:
			_box(parent, Vector3((c.x + 0.5) * cell, -SLAB_T / 2, (c.y + 0.5) * cell),
				Vector3(cell, SLAB_T, cell), _room_color(room), true)
		var label := Label3D.new()
		label.text = room.name
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.pixel_size = 0.01
		label.modulate = Color(1, 1, 1, 0.85)
		label.position = Vector3((r[0] + r[2] / 2.0) * cell, 2.6, (r[1] + r[3] / 2.0) * cell)
		parent.add_child(label)

	# Walls on every cell edge between two rooms, or between a room and outside.
	var door_at := {}
	for d in bank.doors:
		if d.floor == fi:
			door_at[_edge_key(Vector2i(d.cell[0], d.cell[1]), d.side)] = d
	for y in bank.h:
		for x in bank.w:
			var here := Vector2i(x, y)
			var ri: int = f.cells[y * bank.w + x]
			for side in ["n", "e", "s", "w"]:
				var n: Vector2i = here + BankGenerator.DIRS[side]
				var outside: bool = n.x < 0 or n.y < 0 or n.x >= bank.w or n.y >= bank.h
				var ni: int = -1 if outside else f.cells[n.y * bank.w + n.x]
				if ni == ri:
					continue
				# Each interior edge is visited twice; build it from the lower room index only.
				if not outside and ni < ri:
					continue
				var key := _edge_key(here, side)
				var door: Dictionary = door_at.get(key, door_at.get(_edge_key(n, BankGenerator.OPPOSITE[side]), {}))
				if outdoor_floor:
					if outside:
						_wall(parent, here, side, PARAPET_H, {}, true)
					continue
				_wall(parent, here, side, floor_h - SLAB_T, door, outside)


func _wall(parent: Node3D, c: Vector2i, side: String, height: float, door: Dictionary, exterior: bool) -> void:
	var color: Color = COLORS.wall_ext if exterior else COLORS.wall
	var horizontal := side == "n" or side == "s"
	var center := Vector3((c.x + 0.5) * cell, height / 2.0, (c.y + 0.5) * cell)
	var off: Vector2i = BankGenerator.DIRS[side]
	center += Vector3(off.x, 0, off.y) * (cell / 2.0)
	var along := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
	var thick := Vector3(0, 0, WALL_T) if horizontal else Vector3(WALL_T, 0, 0)
	if door.is_empty():
		_box(parent, center, along * cell + thick + Vector3(0, height, 0), color, true)
		return
	var side_len := (cell - DOOR_W) / 2.0
	for s in [-1, 1]:
		var p: Vector3 = center + along * s * (DOOR_W / 2.0 + side_len / 2.0)
		_box(parent, p, along * side_len + thick + Vector3(0, height, 0), color, true)
	var lintel_h := height - DOOR_H
	if lintel_h > 0.01:
		# Lintel spans DOOR_H..height; the wall centre sits at height / 2.
		_box(parent, center + Vector3(0, DOOR_H / 2.0, 0), along * DOOR_W + thick + Vector3(0, lintel_h, 0), color, true)
	var panel := BankDoor.new()
	panel.setup(door, along * DOOR_W + thick * 0.5 + Vector3(0, DOOR_H, 0), _door_color(door))
	panel.position = center + Vector3(0, DOOR_H / 2.0 - height / 2.0, 0)
	parent.add_child(panel)


func _build_ground() -> void:
	# Street level slab around the footprint, with a hole for the building.
	var w: float = bank.w * cell
	var d: float = bank.h * cell
	var pad := 60.0
	var g := Color(0.25, 0.26, 0.27)
	_box(self, Vector3(w / 2, -SLAB_T / 2, -pad / 2), Vector3(w + pad * 2, SLAB_T, pad), g, true)
	_box(self, Vector3(w / 2, -SLAB_T / 2, d + pad / 2), Vector3(w + pad * 2, SLAB_T, pad), g, true)
	_box(self, Vector3(-pad / 2, -SLAB_T / 2, d / 2), Vector3(pad, SLAB_T, d), g, true)
	_box(self, Vector3(w + pad / 2, -SLAB_T / 2, d / 2), Vector3(pad, SLAB_T, d), g, true)


func _build_markers() -> void:
	for cam in bank.security.cameras:
		var p := cell_center(cam.floor, Vector2i(cam.cell[0], cam.cell[1])) + Vector3(0, floor_h - 0.6, 0)
		var m := _box(self, p, Vector3(0.25, 0.25, 0.5), COLORS.camera, false)
		m.rotation_degrees.y = cam.yaw_deg
	var per_cell := {}
	for civ in bank.civilians:
		var key := "%d:%d:%d" % [civ.floor, civ.cell[0], civ.cell[1]]
		var k: int = per_cell.get(key, 0)
		per_cell[key] = k + 1
		var jitter := Vector3(((k % 3) - 1) * 1.2, 0, ((k / 3) % 3 - 1) * 1.2)
		var p := cell_center(civ.floor, Vector2i(civ.cell[0], civ.cell[1])) + jitter + Vector3(0, 0.9, 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = BankGenerator.mix_seed(bank.seed, 900 + civ.id)
		var person := CharacterModel.random_civilian(data, civ.type, rng)
		person.position = p - Vector3(0, 0.9, 0)
		person.rotation.y = rng.randf_range(-PI, PI)
		add_child(person)


func _build_floor_links() -> void:
	for link in bank.vertical_links:
		var lower: Dictionary = bank.rooms[link[0]]
		var upper: Dictionary = bank.rooms[link[1]]
		var c: Vector2i = lower.cells[0]
		var is_lift: bool = lower.id == "elevator"
		var word := "Elevator" if is_lift else "Stairs"
		var lower_p := cell_center(lower.floor, c)
		var upper_p := cell_center(upper.floor, c)
		var up := FloorLink.new()
		up.setup("%s up to %s" % [word, bank.floors[upper.floor].type], upper_p + Vector3(-1.5, 0.1, 0),
			Color(0.2, 0.7, 0.3))
		up.position = lower_p + Vector3(1.5, 1.0, 0)
		add_child(up)
		var down := FloorLink.new()
		down.setup("%s down to %s" % [word, bank.floors[lower.floor].type], lower_p + Vector3(1.5, 0.1, 1.5),
			Color(0.7, 0.4, 0.2))
		down.position = upper_p + Vector3(-1.5, 1.0, -1.5)
		add_child(down)


func _room_color(room: Dictionary) -> Color:
	for key in ["vault", "vertical", "route", "roof", "vehicles", "secure", "public", "staff_only", "staff"]:
		if key in room.tags:
			return COLORS[key]
	return COLORS.staff


func _door_color(door: Dictionary) -> Color:
	match door.lock:
		"none":
			return COLORS.door
		"vault":
			return COLORS.door_vault
	return COLORS.door_locked


func _edge_key(c: Vector2i, side: String) -> String:
	return "%d,%d,%s" % [c.x, c.y, side]


func _box(parent: Node, pos: Vector3, size: Vector3, color: Color, collide: bool) -> Node3D:
	size = size.abs()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mi)
	parent.add_child(body)
	return body


func _mat(color: Color) -> StandardMaterial3D:
	if not _mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_mats[color] = m
	return _mats[color]
