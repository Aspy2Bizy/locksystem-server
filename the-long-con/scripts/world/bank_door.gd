class_name BankDoor
extends StaticBody3D
## Greybox door panel. Interact to open or close. Locked doors report their lock
## type; in the sandbox they can still be forced open so you can explore.

signal toggled(open: bool)

var door: Dictionary
var is_open := false
var _shape: CollisionShape3D
var _mesh: MeshInstance3D


func setup(d: Dictionary, size: Vector3, color: Color) -> void:
	door = d
	size = size.abs()
	_mesh = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mesh.material_override = mat
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	_shape.shape = b
	add_child(_shape)


func describe() -> String:
	var lock: String = door.get("lock", "none")
	var verb := "close" if is_open else "open"
	if lock == "none":
		return "[E] %s door" % verb
	return "[E] %s door (%s lock - forced in sandbox)" % [verb, lock]


func interact(_by: Node) -> void:
	is_open = not is_open
	_mesh.visible = not is_open
	_shape.disabled = is_open
	toggled.emit(is_open)
