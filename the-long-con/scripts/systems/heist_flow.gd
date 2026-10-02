class_name HeistFlow
extends RefCounted
## Phase state machine for a heist (PvE: 7 phases; PvPvE: starts at pre_round).
## Server-authoritative: only the host calls advance().

signal phase_changed(phase: String)

var phases: Array
var index := 0
var building_alert := 0          # 0 calm, 1 suspicious, 2 loud
var hidden_players := {}         # peer -> true while their cover holds


func _init(data: GameData, mode_id: String) -> void:
	for m in data.raw.modes.modes:
		if m.id == mode_id:
			phases = m.phases
	assert(not phases.is_empty(), "unknown mode " + mode_id)


func phase() -> String:
	return phases[index]


func can_advance() -> bool:
	return index < phases.size() - 1


func advance() -> void:
	if can_advance():
		index += 1
		if phase() == "takeover":
			building_alert = 2
		phase_changed.emit(phase())


## A player blows cover. Proposal from the blueprint: the building alert rises for
## everyone, but hidden teammates stay hidden. Going loud inside starts the takeover.
func player_exposed(peer: int, loud: bool) -> void:
	hidden_players.erase(peer)
	building_alert = maxi(building_alert, 2 if loud else 1)
	if loud and phase() == "infiltrate":
		advance()


func is_quiet_phase() -> bool:
	return phase() in ["scout", "plan", "infiltrate", "pre_round"]
