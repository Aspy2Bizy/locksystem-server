class_name Economy
extends RefCounted
## Money rules from penalties.json and difficulty_tiers.json.


## Civilian killed. Returns {peer_id: penalty}. Shooter pays in full (growing with
## repeat kills); every other player on both teams pays a small share.
## teams: {"robbers": [peer ids], "police": [peer ids]}
static func civilian_death_penalties(data: GameData, shooter: int, shooter_team: String, teams: Dictionary,
		shooter_kills_this_round: int) -> Dictionary:
	var p: Dictionary = data.raw.penalties.civilian_death
	var base := float(p.base_penalty)
	var out := {}
	out[shooter] = int(round(base * float(p.shooter_share) * pow(float(p.repeat_offence_growth), maxi(0, shooter_kills_this_round - 1))))
	for team in teams:
		var share := float(p.own_team_share_each) if team == shooter_team else float(p.enemy_team_share_each)
		for peer in teams[team]:
			if peer != shooter:
				out[peer] = int(round(base * share))
	return out


## End of round. mistakes: {mistake_id: count}. Returns gross, deduction, net.
static func payout(data: GameData, extracted_cash: int, stars: int, mistakes: Dictionary) -> Dictionary:
	var tier := data.tier(stars)
	var m: Dictionary = data.raw.penalties.mistakes
	var gross := int(round(extracted_cash * float(tier.payout_multiplier)))
	var fraction := 0.0
	var failed := false
	var lines: Array = []
	for item in m.items:
		var n := int(mistakes.get(item.id, 0))
		if n <= 0:
			continue
		var f := float(item.fraction) * n * float(tier.mistake_penalty_multiplier)
		fraction += f
		lines.append({"id": item.id, "count": n, "fraction": f})
		if tier.mission_fail_on_minor_mistake and item.minor:
			failed = true
	fraction = minf(fraction, float(m.max_total_fraction))
	var deduction := int(round(gross * fraction))
	if failed:
		deduction = gross
	return {"gross": gross, "deduction": deduction, "net": gross - deduction, "lines": lines, "mission_failed": failed}


## PvPvE plea deal: what a robber keeps of their personal take.
static func robber_keeps(data: GameData, personal_take: int, outcome: String) -> int:
	var s: Dictionary = data.raw.penalties.surrender
	match outcome:
		"escaped":
			return personal_take
		"arrested":
			return int(round(personal_take * float(s.arrested_keeps_fraction)))
		_:
			return int(round(personal_take * float(s.killed_keeps_fraction)))
