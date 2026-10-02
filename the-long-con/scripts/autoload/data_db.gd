extends Node
## Global access to game data. Use DataDB.data.<table>.

var data: GameData


func _ready() -> void:
	data = GameData.load_default()
	for e in data.errors:
		push_error("DataDB: " + e)
