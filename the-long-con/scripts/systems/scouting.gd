class_name Scouting
extends RefCounted
## What the team learns in the Scout phase (blueprint: partial info, less at higher stars).
## The vault's type is always shown; the hazard is shown but not where its solutions are.


static func reveal(bank: Dictionary, data: GameData, scout_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = BankGenerator.mix_seed(scout_seed, 7777)
	var frac := float(data.tier(bank.stars).scouting_reveal_fraction)

	var rooms: Array = []
	for r in bank.rooms:
		# Public rooms are always known; the rest roll against the tier's fraction.
		if "public" in r.tags or "lobby" in r.tags or r.id in ["corridor", "stairwell", "elevator"] or rng.randf() < frac:
			rooms.append(r.idx)
	var cams: Array = []
	for i in bank.security.cameras.size():
		if rng.randf() < frac:
			cams.append(i)
	var guards_est: int = bank.security.guards
	if rng.randf() > frac:
		guards_est += rng.randi_range(-1, 2)
	return {
		"known_rooms": rooms,
		"known_cameras": cams,
		"guards_estimate": maxi(1, guards_est),
		"vault_layout": bank.vault.layout,
		"vault_lock_family": bank.vault.lock_family,
		"vault_lock": bank.vault.lock if rng.randf() < frac else "",
		"vault_hazard": bank.vault.hazard,
		"staff_dependency": bank.vault.staff_dependency if rng.randf() < frac else "",
		"civilians_estimate": int(round(bank.civilians.size() * rng.randf_range(0.8, 1.2))),
	}
