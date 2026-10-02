class_name PlayerController
extends CharacterBody3D
## First-person controller: walk, sprint, crouch, jump, mouse look, interact ray.
## Local-only for now. Networking will make the server own position (see docs/ARCHITECTURE.md).

signal interact_target_changed(text: String)

@export var walk_speed := 4.0
@export var sprint_speed := 6.5
@export var crouch_speed := 2.0
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.0025
@export var stand_height := 1.75
@export var crouch_height := 1.1

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var _capsule: CapsuleShape3D
var _last_prompt := ""


func _ready() -> void:
	var shape := CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = stand_height
	shape.shape = _capsule
	shape.position.y = stand_height / 2.0
	add_child(shape)

	head = Node3D.new()
	head.position.y = stand_height - 0.15
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 80
	camera.current = true
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.5)
	ray.add_exception(self)
	camera.add_child(ray)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		var target := _target()
		if target:
			target.interact(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var crouching := Input.is_action_pressed("crouch")
	var h := crouch_height if crouching else stand_height
	_capsule.height = move_toward(_capsule.height, h, delta * 4.0)
	head.position.y = _capsule.height - 0.15

	var speed := crouch_speed if crouching else (sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	var prompt := ""
	var t := _target()
	if t:
		prompt = t.describe()
	if prompt != _last_prompt:
		_last_prompt = prompt
		interact_target_changed.emit(prompt)


func _target() -> Node:
	if not ray.is_colliding():
		return null
	var n: Node = ray.get_collider()
	while n and not n.has_method("interact"):
		n = n.get_parent()
	return n
