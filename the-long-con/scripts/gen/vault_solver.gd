class_name VaultSolver
extends RefCounted
## Decides which vault lock and hazard solutions are possible in a generated bank.
## A solution is feasible when every required room exists and every required
## crafting part can be found in at least one room that exists.


static func room_ids(bank: Dictionary) -> Dictionary:
	var out := {}
	for r in bank.rooms:
		out[r.id] = true
	return out


static func requirements_met(requires: Dictionary, bank: Dictionary, data: GameData) -> bool:
	var present := room_ids(bank)
	for room_id in requires.get("rooms", []):
		if not present.has(room_id):
			return false
	for part_id in requires.get("parts", []):
		var part: Dictionary = data.parts.get(part_id, {})
		if not part.get("found_in", []).any(func(id): return present.has(id)):
			return false
	return true


static func feasible(solutions: Array, bank: Dictionary, data: GameData) -> Array:
	return solutions.filter(func(s): return requirements_met(s.requires, bank, data)).map(func(s): return s.id)
