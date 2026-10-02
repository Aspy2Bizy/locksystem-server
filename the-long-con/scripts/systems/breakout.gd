class_name Breakout
extends RefCounted
## Leverage (in-round currency, never saved) and breakout rolls (escape_routes.json).

var leverage := 0
var _cfg: Dictionary


func _init(data: GameData) -> void:
	_cfg = data.raw.escape_routes.breakouts


func earn(source: String, amount: int = 1) -> void:
	leverage += int(_cfg.leverage_sources.get(source, 0)) * amount


func allowed(stars: int) -> bool:
	return stars <= int(_cfg.allowed_max_stars)


func can_afford() -> bool:
	return leverage >= int(_cfg.cost_leverage)


## Spends leverage and rolls. Extra leverage spent above the cost raises the odds.
func attempt(stars: int, rng: RandomNumberGenerator, extra: int = 0) -> Dictionary:
	if not allowed(stars):
		return {"ok": false, "reason": "no breakouts at this difficulty"}
	extra = clampi(extra, 0, maxi(0, leverage - int(_cfg.cost_leverage)))
	if not can_afford():
		return {"ok": false, "reason": "not enough leverage"}
	leverage -= int(_cfg.cost_leverage) + extra
	var chance := minf(0.95, float(_cfg.success_chance_base) + extra * float(_cfg.success_chance_per_extra_leverage))
	var variant: Dictionary = _cfg.variants[rng.randi_range(0, _cfg.variants.size() - 1)]
	return {"ok": true, "success": rng.randf() < chance, "chance": chance, "variant": variant.id,
		"duration": rng.randi_range(int(_cfg.duration_seconds[0]), int(_cfg.duration_seconds[1]))}
