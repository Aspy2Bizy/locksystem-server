class_name DamageModel
extends RefCounted
## Realistic hit resolution (blueprint "Combat"): an unprotected headshot kills,
## armor tiers vs penetration, range falloff, bleeding wounds.

enum Zone { HEAD, TORSO, ARM, LEG }

const ZONE_MULT := {Zone.HEAD: 4.0, Zone.TORSO: 1.0, Zone.ARM: 0.6, Zone.LEG: 0.7}
const BLEED_THRESHOLD := 25.0       # a hit at or above this starts bleeding
const BLEED_PER_SECOND := 2.0       # per bleeding wound
const PENETRATED_ABSORB_FACTOR := 0.3


## weapon: weapons.json entry. armor: armor.json entry (torso). helmet: true if head is protected.
static func resolve_hit(weapon: Dictionary, zone: Zone, distance_m: float, armor: Dictionary, helmet: bool) -> Dictionary:
	var dmg: float = float(weapon.damage) * float(weapon.get("pellets", 1)) * ZONE_MULT[zone]
	var range_m := float(weapon.range_m)
	if distance_m > range_m:
		dmg *= maxf(0.25, 1.0 - (distance_m - range_m) / range_m)

	var instant_kill := false
	if zone == Zone.HEAD:
		instant_kill = not helmet or int(weapon.penetration) >= 3
		if helmet and not instant_kill:
			dmg *= 0.35
	elif zone == Zone.TORSO:
		var tier := int(armor.get("tier", 0))
		var absorb := float(armor.get("absorb", 0.0))
		if int(weapon.penetration) >= tier:
			dmg *= 1.0 - absorb * PENETRATED_ABSORB_FACTOR
		else:
			dmg *= 1.0 - absorb

	var stun := float(weapon.get("stun_seconds", 0.0))
	return {
		"damage": 1000.0 if instant_kill else dmg,
		"instant_kill": instant_kill,
		"bleeding": dmg >= BLEED_THRESHOLD and zone != Zone.HEAD,
		"slowed": zone == Zone.LEG,
		"stun_seconds": stun,
	}


## Health state for players, police and civilians. Server-side.
class Health:
	extends RefCounted
	var hp := 100.0
	var bleeding_wounds := 0
	var downed := false
	var dead := false
	var downed_time_left := 0.0
	var downed_window := 45.0

	func apply(hit: Dictionary) -> void:
		if dead:
			return
		if hit.instant_kill:
			hp = 0.0
			dead = true
			return
		hp -= hit.damage
		if hit.bleeding:
			bleeding_wounds += 1
		_check()

	func tick(dt: float) -> void:
		if dead:
			return
		if bleeding_wounds > 0:
			hp -= BLEED_PER_SECOND * bleeding_wounds * dt
			_check()
		if downed:
			downed_time_left -= dt
			if downed_time_left <= 0.0:
				dead = true

	func revive(hp_after: float = 35.0) -> void:
		if dead or not downed:
			return
		downed = false
		hp = hp_after
		bleeding_wounds = 0

	func treat() -> void:
		bleeding_wounds = 0

	func _check() -> void:
		if hp <= 0.0 and not downed:
			downed = true
			hp = 0.0
			downed_time_left = downed_window
