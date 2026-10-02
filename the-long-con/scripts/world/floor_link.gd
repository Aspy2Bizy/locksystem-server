class_name FloorLink
extends StaticBody3D
## Greybox stand-in for stairs and elevators: a panel you interact with to move
## one floor up or down. Real stair geometry comes with the art pass.

var label := ""
var target := Vector3.ZERO


func setup(text: String, to: Vector3, color: Color) -> void:
	label = text
	target = to
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.6, 0.8, 0.6)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.4
	mi.material_override = mat
	add_child(mi)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = m.size
	cs.shape = b
	add_child(cs)


func describe() -> String:
	return "[E] " + label


func interact(by: Node) -> void:
	if by is Node3D:
		by.global_position = target
