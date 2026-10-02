extends Node
## Command-line hooks for automated checks (used by CI and by Claude Code without a screen).
##   godot -- --scene=res://scenes/bank_sandbox.tscn --frames=120 --shot=user://shot.png --seed=42 --stars=3
## --frames=N quits after N frames. --shot saves a screenshot right before quitting.
## --pose=x,y,z,yaw_deg,pitch_deg places the sandbox player (and camera) for the shot.
## --map shows the map overlay in the sandbox.

var _frames_left := -1
var _shot := ""
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if _args.has("seed"):
		Session.bank_seed = int(_args.seed)
	if _args.has("stars"):
		Session.stars = int(_args.stars)
	_shot = _args.get("shot", "")
	_frames_left = int(_args.get("frames", "-1"))
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(_args.scene)


func _process(_dt: float) -> void:
	if _frames_left < 0:
		return
	if _frames_left == 60:
		_apply_pose()
	_frames_left -= 1
	if _frames_left == 0:
		if _shot != "":
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot)
			print("screenshot saved: ", ProjectSettings.globalize_path(_shot))
		get_tree().quit()


func _apply_pose() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if _args.has("map") and scene.get("_map_panel"):
		scene._map_panel.visible = true
	if not _args.has("pose") or scene.get("player") == null:
		return
	var p: PackedFloat64Array = PackedFloat64Array(Array(_args.pose.split(",")).map(func(s): return float(s)))
	var player: Node3D = scene.player
	player.global_position = Vector3(p[0], p[1], p[2])
	player.rotation_degrees.y = p[3]
	player.head.rotation_degrees.x = p[4]
	player.set_physics_process(false)
