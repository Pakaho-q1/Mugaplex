extends TestSuite
class_name TestContainerModule

const ContainerModule = preload("res://addons/mugaplex/inventory/modules/container_module.gd")

func _init() -> void:
	suite_name = "ContainerModule"

func _make_item(id: String, weight: float, stackable: bool = false, max_stack: int = 99) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.weight = weight
	item.stackable = stackable
	item.max_stack = max_stack
	return item

func _make_container(id: String, weight: float, c_slots: int, c_weight: float, fixed: bool = false) -> ItemData:
	var item = _make_item(id, weight)
	var mod = ContainerModule.new()
	mod.max_slots = c_slots
	mod.max_weight = c_weight
	mod.fixed_weight = fixed
	item.modules.append(mod)
	return item

func _make_inv(slots: int, weight: float) -> InventoryComponent:
	var inv = InventoryComponent.new()
	inv.max_slots = slots
	inv.max_weight = weight
	# We need a registry for recursive weight calculations (it uses get_registry().get_item)
	inv.registry_override = ItemDatabaseRegistry.new()
	inv.registry_override.items = {}
	inv._ready()
	return inv

func test_container_default_runtime_data() -> void:
	var c_item = _make_container("bag", 1.0, 5, 10.0)
	var mod = c_item.get_module(ContainerModule)
	var rt = mod.get_default_runtime_data()
	assert_true(rt.has("container_slots"), "Should have container_slots")
	assert_true(rt.has("instance_id"), "Should have instance_id")
	assert_true(rt["instance_id"] != -1, "Instance ID should be valid")

func test_container_recursive_weight() -> void:
	var inv = _make_inv(5, 50.0)
	var stone = _make_item("stone", 2.0)
	var bag = _make_container("bag", 1.0, 5, 10.0)
	
	inv.registry_override.items[StringName("stone")] = stone
	inv.registry_override.items[StringName("bag")] = bag
	
	inv.add_item(bag)
	var bag_slot = inv.slots[0]
	assert_eq(inv.get_total_weight(), 1.0, "Empty bag weighs 1.0")
	
	# Open container and put stones in it
	var bag_inv = InventoryAPI.open_container(bag_slot.runtime_data, 5, 10.0)
	# Important: mock registry so add_item works fully if needed, but not strictly required
	# if we don't deserialize. For the test, we can just put items in manually
	bag_inv.add_item(stone)
	bag_inv.add_item(stone)
	# Close container
	bag_slot.runtime_data["container_slots"] = InventoryAPI.close_container(bag_inv)
	
	# Total weight should now be 1.0 (bag) + 4.0 (2 stones)
	assert_eq(inv.get_total_weight(), 5.0, "Weight should include nested items")

func test_container_fixed_weight() -> void:
	var inv = _make_inv(5, 50.0)
	var stone = _make_item("stone", 2.0)
	var magic_bag = _make_container("magic_bag", 0.5, 5, 10.0, true) # fixed weight = true
	
	inv.registry_override.items[StringName("stone")] = stone
	inv.registry_override.items[StringName("magic_bag")] = magic_bag
	
	inv.add_item(magic_bag)
	var bag_slot = inv.slots[0]
	
	var bag_inv = InventoryAPI.open_container(bag_slot.runtime_data, 5, 10.0)
	bag_inv.add_item(stone)
	bag_inv.add_item(stone)
	bag_slot.runtime_data["container_slots"] = InventoryAPI.close_container(bag_inv)
	
	assert_eq(inv.get_total_weight(), 0.5, "Magic bag should weigh 0.5 regardless of contents")

func test_prevent_circular_containment() -> void:
	var inv = _make_inv(5, 50.0)
	var bag = _make_container("bag", 1.0, 5, 10.0)
	inv.registry_override.items[StringName("bag")] = bag
	
	inv.add_item(bag)
	var bag_slot = inv.slots[0]
	
	# Open bag
	var bag_inv = InventoryAPI.open_container(bag_slot.runtime_data, 5, 10.0)
	
	# Try to put the bag into ITSELF via API
	var leftover = InventoryAPI.transfer_item(inv, bag_inv, 0)
	assert_eq(leftover, 1, "Should reject putting bag into itself")
	assert_eq(inv.slots[0].item, bag, "Bag should remain in parent inventory")
	assert_null(bag_inv.slots[0].item, "Bag should not enter itself")

func test_prevent_circular_containment_place_amount() -> void:
	var inv = _make_inv(5, 50.0)
	var bag = _make_container("bag", 1.0, 5, 10.0)
	inv.registry_override.items[StringName("bag")] = bag
	
	inv.add_item(bag)
	var bag_slot = inv.slots[0]
	
	# Open bag
	var bag_inv = InventoryAPI.open_container(bag_slot.runtime_data, 5, 10.0)
	
	# Try to place it via place_item_amount
	var leftover = bag_inv.place_item_amount(0, bag, 1, bag_slot.runtime_data)
	assert_eq(leftover, 1, "place_item_amount should reject circular dependency")
	assert_null(bag_inv.slots[0].item, "Slot should remain empty")
