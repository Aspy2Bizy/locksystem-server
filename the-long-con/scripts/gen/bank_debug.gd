class_name BankDebug
extends RefCounted
## Text views of a bank for tests, tools and bug reports.

const LEGEND := {
	"corridor": ".", "stairwell": "S", "elevator": "E", "lobby_hall": "L", "vault": "V",
	"vault_antechamber": "A", "teller_counter": "T", "security_office": "G", "manager_office": "M",
	"server_room": "N", "electrical_room": "P", "hvac_room": "H", "pump_room": "U",
	"safe_deposit": "D", "counting_room": "C", "loading_dock": "K", "staff_entrance": "Z",
	"roof_access": "R", "helipad": "@", "bathroom": "b", "break_room": "k", "maintenance": "m",
	"cafe": "f", "meeting_room": "g", "open_office": "o", "archive": "a", "locker_room": "l",
	"parking_bay": "p", "roof_deck": "d", "it_closet": "i", "storage": "s", "office_small": "e",
	"utility_closet": "u", "janitor": "j", "roof_unit": "r", "parking_spot": "q",
}


static func ascii(bank: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("seed %d  stars %d  attempt %d  grid %dx%d  floors %d" % [
		bank.seed, bank.stars, bank.attempt, bank.w, bank.h, bank.floors.size()])
	for fi in range(bank.floors.size() - 1, -1, -1):
		var f: Dictionary = bank.floors[fi]
		lines.append("")
		lines.append("floor %d  level %+d  %s" % [fi, f.level, f.type])
		for y in bank.h:
			var row := ""
			for x in bank.w:
				var ri: int = f.cells[y * bank.w + x]
				row += "?" if ri < 0 else LEGEND.get(bank.rooms[ri].id, "#")
				row += " "
			lines.append("  " + row)
	if bank.has("vault"):
		var v: Dictionary = bank.vault
		lines.append("")
		lines.append("vault: %s / %s / %s / %s" % [v.layout, v.lock, v.hazard, v.staff_dependency])
		lines.append("  lock solutions:   %s" % ", ".join(v.lock_solutions))
		lines.append("  hazard solutions: %s" % ", ".join(v.hazard_solutions))
		lines.append("security: %d cameras, %d guards   civilians: %d   escape: %s" % [
			bank.security.cameras.size(), bank.security.guards, bank.civilians.size(), ", ".join(bank.escape_routes)])
	return "\n".join(lines)


## JSON-safe copy (Vector2i -> [x, y], PackedInt32Array -> Array).
static func to_json_safe(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_PACKED_INT32_ARRAY:
			return Array(v)
		TYPE_ARRAY:
			return v.map(func(e): return to_json_safe(e))
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = to_json_safe(v[k])
			return out
	return v
