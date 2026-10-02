class_name CharacterPoses
extends RefCounted
## Static poses built by rotating bones about skeleton-space axes.
## The MakeHuman rig faces +Z with the character's left side on +X, and the
## rest pose is an A-pose (arms about 40 degrees from the body).
## Each step: [bone, axis, degrees]. Steps run in order, parents before children.
## Real animation will come from mocap later; these cover the states the game
## needs to show today (standing, surrender, kneeling hostage, aiming).

const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

const POSES := {
	"a_pose": [],
	"stand": [],
	"hands_up": [
		["upperarm01.L", Z, 52], ["upperarm01.R", Z, -52],
		["lowerarm01.L", Z, 80], ["lowerarm01.R", Z, -80],
		["lowerarm01.L", X, -15], ["lowerarm01.R", X, -15],
		["head", X, 8],
	],
	"kneel_hostage": [
		["upperleg01.L", X, -8], ["upperleg01.R", X, -8],
		["lowerleg01.L", X, 92], ["lowerleg01.R", X, 92],
		["foot.L", X, 40], ["foot.R", X, 40],
		["spine03", X, 6],
		["upperarm01.L", Z, 62], ["upperarm01.R", Z, -62],
		["upperarm01.L", Y, -12], ["upperarm01.R", Y, 12],
		["lowerarm01.L", Y, 150], ["lowerarm01.R", Y, -150],
		["lowerarm01.L", Z, 20], ["lowerarm01.R", Z, -20],
		["head", X, 22],
	],
	"aim_rifle": [
		["spine03", Y, 8],
		["head", X, 6], ["head", Y, -4],
	],
}

## Root drop for poses that lower the body (kneeling), in metres.
const DROP := {"kneel_hostage": 0.47}


static func apply(skel: Skeleton3D, pose_name: String) -> void:
	skel.reset_bone_poses()
	var root := skel.find_bone("root")
	if root >= 0:
		var p: Vector3 = skel.get_bone_rest(root).origin
		skel.set_bone_pose_position(root, p - Vector3(0, DROP.get(pose_name, 0.0), 0))
	for step in POSES.get(pose_name, []):
		rotate_global(skel, step[0], step[1], step[2])
	if pose_name in ["stand", "aim_rifle"]:
		_arms_down(skel, pose_name == "aim_rifle")
	if pose_name != "a_pose":
		relax_fingers(skel, 1.0 if pose_name != "hands_up" else 0.4)
	if pose_name == "kneel_hostage":
		# Fingers laced behind the head.
		var h := bone_pos(skel, "head")
		reach(skel, "L", h + Vector3(0.05, 0.10, -0.07), Vector3(1, -0.2, 0.4))
		reach(skel, "R", h + Vector3(-0.05, 0.10, -0.07), Vector3(-1, -0.2, 0.4))


## Arms hanging relaxed at the sides, elbows slightly back.
static func _arms_down(skel: Skeleton3D, _unused := false) -> void:
	for side in ["L", "R"]:
		var sgn := 1.0 if side == "L" else -1.0
		var s := bone_pos(skel, "upperarm01." + side)
		var e := bone_pos(skel, "lowerarm01." + side)
		var w := bone_pos(skel, "wrist." + side)
		var reach_len := (s.distance_to(e) + e.distance_to(w)) * 0.97
		reach(skel, side, s + Vector3(sgn * 0.07, -reach_len, 0.045), Vector3(0, 0, -1))
		align_hand(skel, side)


## Point the hand along the forearm (undoes the A-pose wrist flare).
static func align_hand(skel: Skeleton3D, side: String) -> void:
	var e := bone_pos(skel, "lowerarm01." + side)
	var w := bone_pos(skel, "wrist." + side)
	var f := bone_pos(skel, "finger3-1." + side)
	var sgn := 1.0 if side == "L" else -1.0
	# Hands hang slightly inward toward the thigh.
	var want := (w - e).normalized() + Vector3(-sgn * 0.12, 0, 0)
	rotate_from_to(skel, "wrist." + side, f - w, want)


## Gentle finger curl (bone-local flexion), 0 = flat, 1 = relaxed.
static func relax_fingers(skel: Skeleton3D, amount: float) -> void:
	for side in ["L", "R"]:
		for f in range(1, 6):
			for seg in range(1, 4):
				var i := skel.find_bone("finger%d-%d.%s" % [f, seg, side])
				if i < 0:
					continue
				var deg := (8.0 if f == 1 else 14.0 + seg * 6.0) * amount
				var q := skel.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, deg_to_rad(deg))
				skel.set_bone_pose_rotation(i, q)


static func bone_pos(skel: Skeleton3D, bone: String) -> Vector3:
	return global_pose(skel, skel.find_bone(bone)).origin


## Skeleton-space pose computed from the local poses right now. Skeleton3D's own
## global pose cache only refreshes once per frame, which breaks chained edits.
static func global_pose(skel: Skeleton3D, i: int) -> Transform3D:
	var t := Transform3D(Basis(skel.get_bone_pose_rotation(i)).scaled(skel.get_bone_pose_scale(i)),
		skel.get_bone_pose_position(i))
	var p := skel.get_bone_parent(i)
	return global_pose(skel, p) * t if p >= 0 else t


## Two-bone IK for an arm: put the wrist of side "L"/"R" at `target` (skeleton space),
## bending the elbow towards `pole`.
static func reach(skel: Skeleton3D, side: String, target: Vector3, pole: Vector3) -> void:
	var ua := "upperarm01." + side
	var la := "lowerarm01." + side
	var s := bone_pos(skel, ua)
	var e := bone_pos(skel, la)
	var w := bone_pos(skel, "wrist." + side)
	var a := s.distance_to(e)
	var b := e.distance_to(w)
	var to_t := target - s
	var d := clampf(to_t.length(), 0.05, a + b - 0.002)
	var dir := to_t.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var perp := (pole - dir * pole.dot(dir)).normalized()
	var elbow := s + a * (dir * cos_a + perp * sqrt(1.0 - cos_a * cos_a))
	rotate_from_to(skel, ua, e - s, elbow - s)
	e = bone_pos(skel, la)
	w = bone_pos(skel, "wrist." + side)
	rotate_from_to(skel, la, w - e, target - e)


static func rotate_from_to(skel: Skeleton3D, bone: String, from: Vector3, to: Vector3) -> void:
	var axis := from.cross(to)
	if axis.length() < 1e-6:
		return
	rotate_global(skel, bone, axis, rad_to_deg(from.angle_to(to)))


## Rotate a bone about an axis given in skeleton space (keeps children attached).
static func rotate_global(skel: Skeleton3D, bone: String, axis: Vector3, degrees: float) -> void:
	var i := skel.find_bone(bone)
	if i < 0:
		push_warning("CharacterPoses: no bone " + bone)
		return
	var g: Basis = global_pose(skel, i).basis
	var p := skel.get_bone_parent(i)
	var pg: Basis = global_pose(skel, p).basis if p >= 0 else Basis()
	var new_g := Basis(axis.normalized(), deg_to_rad(degrees)) * g
	skel.set_bone_pose_rotation(i, (pg.inverse() * new_g).get_rotation_quaternion())
