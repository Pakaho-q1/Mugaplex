@tool
extends Resource
class_name RecipeRegistry

@export var recipes: Array[ItemRecipe] = []

## Find a matching recipe from the given item counts.
## input_counts: Dictionary of { item_id (StringName): total_amount (int) }
## Example: { &"wood": 3, &"stone": 1 }
## Returns the highest-priority matching recipe, or null if none found.
func find_recipe(input_counts: Dictionary) -> ItemRecipe:
	var best_recipe: ItemRecipe = null
	
	for recipe in recipes:
		if not recipe or not recipe.result_item:
			continue
		if _matches(input_counts, recipe):
			if best_recipe == null or recipe.priority > best_recipe.priority:
				best_recipe = recipe
				
	return best_recipe

## Helper: build an input_counts dict from an Array[ItemData] (legacy convenience)
func find_recipe_from_items(input_items: Array[ItemData]) -> ItemRecipe:
	var counts: Dictionary = {}
	for item in input_items:
		if item:
			var id = item.item_id
			counts[id] = counts.get(id, 0) + 1
	return find_recipe(counts)

func _matches(input_counts: Dictionary, recipe: ItemRecipe) -> bool:
	# Build required counts from recipe ingredients
	var required: Dictionary = {}
	for ingredient in recipe.ingredients:
		if ingredient and ingredient.item:
			var id = ingredient.item.item_id
			required[id] = required.get(id, 0) + ingredient.amount
	
	# Must have same number of distinct item types
	if input_counts.size() != required.size():
		return false
	
	# Every required item must be present with at least the required amount
	for id in required:
		if not input_counts.has(id):
			return false
		if input_counts[id] < required[id]:
			return false
	
	# Input must not have extra item types beyond what recipe needs
	for id in input_counts:
		if not required.has(id):
			return false
	
	return true
