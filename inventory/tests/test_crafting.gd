extends TestSuite
class_name TestInventoryCrafting

func _init() -> void:
	suite_name = "InventoryCrafting"

func test_craft_items_consumes_ingredients_and_adds_result() -> void:
	var inv = InventoryComponent.new()
	var slot1 = InventorySlot.new()
	var slot2 = InventorySlot.new()
	var item_a = ItemData.new()
	item_a.item_id = "wood"
	var item_b = ItemData.new()
	item_b.item_id = "stone"
	
	slot1.item = item_a
	slot1.amount = 1
	slot2.item = item_b
	slot2.amount = 1
	
	var typed_slots: Array[InventorySlot] = [slot1, slot2]
	inv.slots = typed_slots
	
	var registry = RecipeRegistry.new()
	var recipe = ItemRecipe.new()
	var ing_a = RecipeIngredient.new()
	ing_a.item_id = "wood"
	ing_a.amount = 1
	var ing_b = RecipeIngredient.new()
	ing_b.item_id = "stone"
	ing_b.amount = 1
	var ings: Array[RecipeIngredient] = [ing_a, ing_b]
	recipe.ingredients = ings
	var axe = ItemData.new()
	axe.item_id = "axe"
	recipe.result_item = axe
	recipe.result_amount = 1
	registry.recipes.append(recipe)
	
	var result = InventoryAPI.craft_items(inv, registry, [0, 1])
	assert_true(result, "Crafting should succeed")
	
	assert_null(inv.slots[1].item, "Slot 1 should be empty")
	
	# The axe should be placed in slot 0 (first available)
	assert_not_null(inv.slots[0].item, "Slot 0 should now hold the axe")
	if inv.slots[0].item != null:
		assert_eq(inv.slots[0].item.item_id, "axe")
