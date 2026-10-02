extends TestCase
## Rule systems: damage, money, detectability, civilians, crafting, breakouts, flow.


func test_unprotected_headshot_kills() -> void:
	var pistol: Dictionary = data.weapons.pistol_compact
	var hit := DamageModel.resolve_hit(pistol, DamageModel.Zone.HEAD, 10.0, data.armor.none, false)
	check(hit.instant_kill, "pistol headshot without helmet kills")
	var helmeted := DamageModel.resolve_hit(pistol, DamageModel.Zone.HEAD, 10.0, data.armor.none, true)
	check(not helmeted.instant_kill, "helmet stops a pistol headshot kill")
	var rifle := DamageModel.resolve_hit(data.weapons.rifle_carbine, DamageModel.Zone.HEAD, 10.0, data.armor.none, true)
	check(rifle.instant_kill, "rifle penetrates helmet")


func test_armor_tiers() -> void:
	var pistol: Dictionary = data.weapons.pistol_compact
	var bare := DamageModel.resolve_hit(pistol, DamageModel.Zone.TORSO, 5.0, data.armor.none, false)
	var heavy := DamageModel.resolve_hit(pistol, DamageModel.Zone.TORSO, 5.0, data.armor.heavy_plate, false)
	var rifle_heavy := DamageModel.resolve_hit(data.weapons.rifle_carbine, DamageModel.Zone.TORSO, 5.0, data.armor.heavy_plate, false)
	check(heavy.damage < bare.damage * 0.5, "heavy plate stops most pistol damage")
	check(rifle_heavy.damage > data.weapons.rifle_carbine.damage * 0.7, "rifle penetrates heavy plate")


func test_bleed_down_and_revive() -> void:
	var h := DamageModel.Health.new()
	h.apply(DamageModel.resolve_hit(data.weapons.rifle_carbine, DamageModel.Zone.TORSO, 5.0, data.armor.none, false))
	check(h.bleeding_wounds == 1, "rifle torso hit bleeds")
	for i in 120:
		h.tick(0.5)
	check(h.downed, "bleeding out leads to downed")
	h.revive()
	check(not h.downed and h.hp > 0, "revive works")
	h.apply({"damage": 500.0, "instant_kill": false, "bleeding": false})
	for i in 100:
		h.tick(1.0)
	check(h.dead, "downed window running out is death")


func test_civilian_penalty_split() -> void:
	var teams := {"robbers": [1, 2, 3], "police": [4, 5]}
	var p := Economy.civilian_death_penalties(data, 1, "robbers", teams, 1)
	check_eq(p[1], 4000, "shooter pays full")
	check_eq(p[2], 400, "own team pays small share")
	check_eq(p[4], 400, "enemy team pays small share")
	var p3 := Economy.civilian_death_penalties(data, 1, "robbers", teams, 3)
	check_eq(p3[1], 9000, "third kill grows 1.5^2")


func test_payout() -> void:
	var clean := Economy.payout(data, 100000, 3, {})
	check_eq(clean.net, 180000, "3-star clean payout")
	var messy := Economy.payout(data, 100000, 3, {"civilian_killed": 2, "camera_spotted": 3})
	check_eq(messy.deduction, int(round(180000 * (0.1 + 0.03))), "deductions add up")
	var six := Economy.payout(data, 100000, 6, {"camera_spotted": 1})
	check(six.mission_failed and six.net == 0, "a minor slip fails the mission at 6 stars")
	var capped := Economy.payout(data, 100000, 5, {"civilian_killed": 50})
	check_eq(capped.deduction, int(round(capped.gross * 0.8)), "deductions capped")
	check_eq(Economy.robber_keeps(data, 10000, "arrested"), 3500, "plea deal")
	check_eq(Economy.robber_keeps(data, 10000, "killed"), 0, "killed keeps nothing")


func test_detectability() -> void:
	var light := Detectability.score(data, {"role": "breacher", "weapons": ["pistol_compact"], "armor": "none", "gadgets": ["lockpick_set"]})
	var heavy := Detectability.score(data, {"role": "breacher", "weapons": ["rifle_carbine"], "armor": "heavy_plate", "gadgets": ["drill"]})
	check(light < 15, "concealed pistol loadout is low (%d)" % light)
	check(heavy == 100, "drill bag + rifle + plate is maxed (%d)" % heavy)
	check(Detectability.suspicion_rate(heavy, 5.0, false, 0) > Detectability.suspicion_rate(light, 5.0, false, 0), "heavier is noticed faster")
	check_eq(Detectability.suspicion_rate(heavy, 40.0, false, 0), 0.0, "out of sight range")
	var forged := Detectability.score(data, {"role": "medic_forger", "weapons": ["pistol_compact"], "armor": "none", "gadgets": ["staff_uniform", "fake_id"]})
	check_eq(forged, 0, "disguise lowers detectability")


func test_civilian_brain() -> void:
	var c := CivilianBrain.new(data, "customer")
	check_eq(c.decide(), CivilianBrain.Act.COMPLY, "calm customer complies by default")
	c.stimulus("gunshot_heard", 3.0)
	check_eq(c.decide(), CivilianBrain.Act.FLEE, "panics after gunshots")
	c.stimulus("zip_tied")
	check_eq(c.decide(), CivilianBrain.Act.COMPLY, "zip-tied complies")
	var cop := CivilianBrain.new(data, "off_duty_cop")
	check_eq(cop.decide(), CivilianBrain.Act.HERO, "off-duty cop plays hero")
	var guard := CivilianBrain.new(data, "guard")
	guard.stimulus("gun_pointed_at", 3.0)
	check(guard.decide() != CivilianBrain.Act.HERO, "gun in face suppresses heroics")


func test_crafting() -> void:
	var inv := {"aluminum_powder": 1, "iron_oxide": 1, "magnesium_strip": 1, "sugar": 1}
	check("craft_thermite" in Crafting.available(data, inv), "thermite craftable")
	check(not Crafting.craft(data, "craft_smoke", inv), "smoke needs potassium nitrate")
	check(Crafting.craft(data, "craft_thermite", inv), "craft thermite")
	check_eq(inv.get("thermite", 0), 1, "thermite added")
	check(not inv.has("iron_oxide"), "inputs consumed")


func test_breakout() -> void:
	var b := Breakout.new(data)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	check(not b.attempt(3, rng).ok, "can't afford at 0 leverage")
	b.earn("intel_found", 10)
	check(b.can_afford(), "earned leverage")
	check(not b.attempt(6, rng).ok, "no breakouts at 6 stars")
	var r := b.attempt(3, rng)
	check(r.ok and r.duration >= 180 and r.duration <= 300, "breakout rolls a 3-5 minute set piece")
	check_eq(b.leverage, 50, "cost spent")


func test_heist_flow() -> void:
	var f := HeistFlow.new(data, "pve")
	check_eq(f.phase(), "scout", "starts with scouting")
	f.advance()
	f.advance()
	check_eq(f.phase(), "infiltrate", "third phase")
	f.hidden_players = {1: true, 2: true}
	f.player_exposed(1, true)
	check_eq(f.phase(), "takeover", "going loud starts the takeover")
	check(f.hidden_players.has(2), "hidden teammate stays hidden")
	var pvp := HeistFlow.new(data, "pvpve")
	check_eq(pvp.phase(), "pre_round", "PvPvE skips quiet phases")
