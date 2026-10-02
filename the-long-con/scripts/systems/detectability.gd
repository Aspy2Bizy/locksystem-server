class_name Detectability
extends RefCounted
## Loadout visibility (blueprint "Detectability"). Cover is per player, not per team.

enum Cover { HIDDEN, SUSPICIOUS, EXPOSED }

const SUSPICIOUS_AT := 0.5   # suspicion meter, 0..1
const EXPOSED_AT := 1.0


## loadout: {"role": id, "weapons": [ids], "armor": id, "gadgets": [ids]}
static func score(data: GameData, loadout: Dictionary) -> int:
	var total := 0
	var role: Dictionary = data.robber_roles.get(loadout.get("role", ""), {})
	total += int(role.get("undercover", {}).get("detectability_base", 0))
	for w in loadout.get("weapons", []):
		total += int(data.weapons[w].detectability)
	total += int(data.armor.get(loadout.get("armor", "none"), {}).get("detectability", 0))
	for g in loadout.get("gadgets", []):
		total += int(data.gadgets[g].detectability)
	return clampi(total, 0, 100)


## Suspicion gained per second by one observer who can see the player.
static func suspicion_rate(score: int, distance_m: float, restricted_area: bool, building_alert: int) -> float:
	var base := 0.05 + float(score) / 100.0 * 0.6
	var dist := clampf(1.0 - distance_m / 25.0, 0.0, 1.0)
	var area := 2.5 if restricted_area else 1.0
	var alert := 1.0 + 0.5 * building_alert
	return base * dist * area * alert


static func cover_for(suspicion: float) -> Cover:
	if suspicion >= EXPOSED_AT:
		return Cover.EXPOSED
	if suspicion >= SUSPICIOUS_AT:
		return Cover.SUSPICIOUS
	return Cover.HIDDEN
