extends Node
## Lobby networking on Godot's high-level multiplayer (ENet).
## Server-authoritative: the host owns the match settings and bank seed. Clients
## receive only the seed + stars and regenerate the identical bank locally
## (the generator is deterministic), so the bank never travels over the wire.
##
## This is the foundation only: lobby, roster, roles, start. Player sync, AI and
## voice come in later milestones (docs/ROADMAP.md).

signal roster_changed(players: Dictionary)
signal match_starting(bank_seed: int, stars: int, mode_id: String)
signal connection_failed(reason: String)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 15   # 8v8 PvPvE = 16 players including the host

## peer_id -> {"name": String, "team": "robbers"|"police", "role": String, "ready": bool}
var players: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit("could not reach host"))
	multiplayer.server_disconnected.connect(func():
		players.clear()
		connection_failed.emit("host left"))


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players[1] = {"name": Session.player_name, "team": "robbers", "role": Session.robber_role, "ready": false}
	roster_changed.emit(players)
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


# --- client -> server requests ------------------------------------------------

func request_role(team: String, role: String) -> void:
	_rpc_request_role.rpc_id(1, team, role)


func set_ready(ready: bool) -> void:
	_rpc_set_ready.rpc_id(1, ready)


@rpc("any_peer", "reliable")
func _rpc_register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": player_name.left(24), "team": "robbers", "role": "breacher", "ready": false}
	_broadcast_roster()


@rpc("any_peer", "call_local", "reliable")
func _rpc_request_role(team: String, role: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if not players.has(id) or team not in ["robbers", "police"]:
		return
	var table: Dictionary = DataDB.data.robber_roles if team == "robbers" else DataDB.data.police_roles
	if not table.has(role):
		return
	var taken := players.values().filter(func(p): return p.team == team and p.role == role).size()
	if taken >= int(table[role].max_per_team):
		return
	players[id].team = team
	players[id].role = role
	_broadcast_roster()


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	if players.has(id):
		players[id].ready = ready
		_broadcast_roster()


# --- server -> clients --------------------------------------------------------

func start_match() -> void:
	assert(is_host())
	_rpc_start.rpc(Session.bank_seed, Session.stars, Session.mode_id)


@rpc("authority", "call_local", "reliable")
func _rpc_start(bank_seed: int, stars: int, mode_id: String) -> void:
	Session.bank_seed = bank_seed
	Session.stars = stars
	Session.mode_id = mode_id
	match_starting.emit(bank_seed, stars, mode_id)


@rpc("authority", "reliable")
func _rpc_roster(roster: Dictionary) -> void:
	players = roster
	roster_changed.emit(players)


func _broadcast_roster() -> void:
	roster_changed.emit(players)
	_rpc_roster.rpc(players)


func _on_connected() -> void:
	_rpc_register.rpc_id(1, Session.player_name)


func _on_peer_connected(_id: int) -> void:
	if multiplayer.is_server():
		_broadcast_roster()


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		_broadcast_roster()
