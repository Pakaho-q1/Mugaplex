@tool
extends Resource
class_name RecipeRegistry

@export var recipes: Array[ItemRecipe] = []

# จับคู่ส่วนผสมกับสูตร เรียงตาม priority สูงไปต่ำ
func find_recipe(input_items: Array[ItemData]) -> ItemRecipe:
	# คัดกรอง null
	var valid_inputs: Array[ItemData] = []
	for item in input_items:
		if item:
			valid_inputs.append(item)
			
	var best_recipe: ItemRecipe = null
	
	for recipe in recipes:
		if not recipe or not recipe.result_item:
			continue
			
		if _matches_ingredients(valid_inputs, recipe.ingredients):
			if best_recipe == null or recipe.priority > best_recipe.priority:
				best_recipe = recipe
				
	return best_recipe

func _matches_ingredients(inputs: Array[ItemData], recipe_ingredients: Array[ItemData]) -> bool:
	if inputs.size() != recipe_ingredients.size():
		return false
		
	# เช็คว่ามีของตรงกันทุกชิ้นหรือไม่ (นับจำนวนว่ามีครบไหม)
	var input_ids = []
	for it in inputs:
		input_ids.append(it.item_id)
		
	var required_ids = []
	for req in recipe_ingredients:
		if req:
			required_ids.append(req.item_id)
			
	input_ids.sort()
	required_ids.sort()
	
	return input_ids == required_ids
