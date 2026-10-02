class_name Crafting
extends RefCounted
## On-site crafting ("MacGyvering") from weapons_gadgets.json recipes.


## inventory: {item_id: count}. Returns recipe ids craftable right now.
static func available(data: GameData, inventory: Dictionary) -> Array:
	return data.recipes.values().filter(func(r): return can_craft(r, inventory)).map(func(r): return r.id)


static func can_craft(recipe: Dictionary, inventory: Dictionary) -> bool:
	for part in recipe.inputs:
		if int(inventory.get(part, 0)) < int(recipe.inputs[part]):
			return false
	return true


## Consumes inputs and adds the output. Returns false and changes nothing if short.
static func craft(data: GameData, recipe_id: String, inventory: Dictionary) -> bool:
	var recipe: Dictionary = data.recipes[recipe_id]
	if not can_craft(recipe, inventory):
		return false
	for part in recipe.inputs:
		inventory[part] = int(inventory[part]) - int(recipe.inputs[part])
		if inventory[part] == 0:
			inventory.erase(part)
	inventory[recipe.output] = int(inventory.get(recipe.output, 0)) + 1
	return true
