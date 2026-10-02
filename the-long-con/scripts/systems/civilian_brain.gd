class_name CivilianBrain
extends RefCounted
## Simulated fear, compliance, panic and heroics (civilians.json). Pure logic: the
## 3D civilian node feeds stimuli in and reads `decide()` to pick an animation/goal.

enum Act { IDLE, COMPLY, FLEE, FREEZE, HERO }

var type_id: String
var fear := 0.0
var compliance := 0.0
var panic := 0.0
var heroics := 0.0
var zip_tied := false
var _dyn: Dictionary
var _thr: Dictionary


func _init(data: GameData, civilian_type: String) -> void:
	type_id = civilian_type
	var t: Dictionary = data.civilian_types[civilian_type]
	fear = t.base.fear
	compliance = t.base.compliance
	panic = t.base.panic
	heroics = t.base.heroics
	_dyn = data.raw.civilians.dynamics
	_thr = data.raw.civilians.thresholds


func stimulus(name: String, strength: float = 1.0) -> void:
	var s: Dictionary = _dyn.get(name, {})
	fear = clampf(fear + s.get("fear", 0.0) * strength, 0.0, 1.0)
	compliance = clampf(compliance + s.get("compliance", 0.0) * strength, 0.0, 1.0)
	panic = clampf(panic + s.get("panic", 0.0) * strength, 0.0, 1.0)
	heroics = clampf(heroics + s.get("heroics", 0.0) * strength, 0.0, 1.0)
	if name == "zip_tied":
		zip_tied = true


func tick(dt: float) -> void:
	var d: Dictionary = _dyn.decay_per_second
	fear = clampf(fear + d.fear * dt, 0.0, 1.0)
	compliance = clampf(compliance + d.compliance * dt, 0.0, 1.0)
	panic = clampf(panic + d.panic * dt, 0.0, 1.0)
	heroics = clampf(heroics + d.heroics * dt, 0.0, 1.0)


## Priority: tied up > hero > flee > freeze > comply > idle.
func decide() -> Act:
	if zip_tied:
		return Act.COMPLY
	if heroics > _thr.hero_if_heroics_above and fear < 0.9:
		return Act.HERO
	if panic > _thr.flee_if_panic_above and compliance < 0.8:
		return Act.FLEE
	if fear > _thr.freeze_if_fear_above:
		return Act.FREEZE
	if compliance > _thr.comply_if_compliance_above:
		return Act.COMPLY
	return Act.IDLE
