extends Node
## Two-process network smoke test (run by tools/net_smoke.sh, not by run_tests.gd).
## Host waits for a client, assigns it a role request, starts the match; the client
## must regenerate the identical bank from the seed and exit 0.

var role := ""
var _deadline := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net="):
			role = a.trim_prefix("--net=")
	_deadline = Time.get_ticks_msec() + 20000
	Session.bank_seed = 98765
	Session.stars = 4
	if role == "host":
		Session.player_name = "Host"
		Net.host(24681)
		Net.roster_changed.connect(_on_roster)
	else:
		Session.player_name = "Client"
		Session.bank_seed = 0
		Net.join("127.0.0.1", 24681)
		Net.roster_changed.connect(func(p):
			var me: Dictionary = p.get(multiplayer.get_unique_id(), {})
			if me and me.role != "tech":
				Net.request_role("robbers", "tech"))
		Net.match_starting.connect(_on_start)


func _on_roster(p: Dictionary) -> void:
	print("[host] roster: ", p.values().map(func(x): return "%s/%s" % [x.name, x.role]))
	var client := p.keys().filter(func(id): return id != 1)
	if client.size() == 1 and p[client[0]].role == "tech":
		Net.start_match()
		await get_tree().create_timer(1.0).timeout
		print("[host] OK")
		get_tree().quit(0)


func _on_start(bank_seed: int, stars: int, mode_id: String) -> void:
	if role == "host":
		return
	var bank := BankGenerator.new(DataDB.data).generate(bank_seed, stars)
	var reference := BankGenerator.new(DataDB.data).generate(98765, 4)
	var same := JSON.stringify(BankDebug.to_json_safe(bank)) == JSON.stringify(BankDebug.to_json_safe(reference))
	print("[client] got seed %d stars %d mode %s, bank identical: %s" % [bank_seed, stars, mode_id, same])
	get_tree().quit(0 if same else 1)


func _process(_dt: float) -> void:
	if Time.get_ticks_msec() > _deadline:
		print("[%s] TIMEOUT" % role)
		get_tree().quit(2)
