extends Node
## Global signal bus. Systems emit here so UI and audio can listen without hard references.

signal bank_generated(bank: Dictionary)
signal phase_changed(phase: String)
signal alert_level_changed(level: int)
signal civilian_killed(civilian_id: int, killer_peer: int)
signal player_downed(peer_id: int)
signal player_arrested(peer_id: int)
signal money_changed(team: String, amount: int)
signal lockdown_triggered(hazard_id: String, warning_seconds: float)
