extends Control
## Title screen: pick a seed and difficulty, then open the planning table or walk the bank.

var _seed_edit: LineEdit
var _stars: OptionButton
var _status: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(460, 0)
	box.position = Vector2(-230, -220)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = "THE LONG CON"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "prototype build - bank generator sandbox"
	sub.modulate = Color(1, 1, 1, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = "Seed"
	l.custom_minimum_size.x = 80
	row.add_child(l)
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(Session.bank_seed)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_seed_edit)
	var dice := Button.new()
	dice.text = "Random"
	dice.pressed.connect(func(): _seed_edit.text = str(randi() % 1000000))
	row.add_child(dice)

	var row2 := HBoxContainer.new()
	box.add_child(row2)
	var l2 := Label.new()
	l2.text = "Difficulty"
	l2.custom_minimum_size.x = 80
	row2.add_child(l2)
	_stars = OptionButton.new()
	_stars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in range(1, 7):
		_stars.add_item("%s  %s" % ["*".repeat(s), DataDB.data.tier(s).name], s)
	_stars.select(Session.stars - 1)
	row2.add_child(_stars)

	_button(box, "Planning Table (floor plans + intel)", "res://scenes/planning_table.tscn")
	_button(box, "Walk the Bank (greybox sandbox)", "res://scenes/bank_sandbox.tscn")
	_button(box, "Character Lineup (models)", "res://scenes/character_lineup.tscn")
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	_status = Label.new()
	_status.modulate = Color(1, 0.5, 0.4)
	box.add_child(_status)
	if not DataDB.data.errors.is_empty():
		_status.text = "Data errors: " + ", ".join(DataDB.data.errors)


func _button(parent: Node, text: String, scene: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(func():
		Session.bank_seed = int(_seed_edit.text) if _seed_edit.text.is_valid_int() else _seed_edit.text.hash()
		Session.stars = _stars.get_selected_id()
		get_tree().change_scene_to_file(scene))
	parent.add_child(b)
