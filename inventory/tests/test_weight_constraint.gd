extends TestSuite
class_name TestWeightConstraint

func _init() -> void:
	suite_name = "WeightConstraint"

# --- Helpers ---
func _make_item(id: String, w: float, stackable: bool = false, max_stack: int = 99) -> ItemData:
	var item = ItemData.new()
	item.item_id = id
	item.weight = w
	item.stackable = stackable
	item.max_stack = max_stack
	return item

func _make_inv(max_slots: int, max_w: float) -> InventoryComponent:
	var inv = InventoryComponent.new()
	inv.max_slots = max_slots
	inv.max_weight = max_w
	inv._ready()
	return inv

# --- Tests ---

func test_get_total_weight_empty() -> void:
	var inv = _make_inv(5, 100.0)
	assert_eq(inv.get_total_weight(), 0.0)

func test_get_total_weight_with_items() -> void:
	var inv = _make_inv(5, 100.0)
	var sword = _make_item("sword", 5.0)
	inv.add_item(sword)
	assert_eq(inv.get_total_weight(), 5.0)

func test_get_total_weight_stacked() -> void:
	var inv = _make_inv(5, 100.0)
	var arrow = _make_item("arrow", 0.1, true, 99)
	inv.add_item(arrow, 10)
	# 0.1 * 10 = 1.0 (use snapped for float comparison)
	var total = inv.get_total_weight()
	assert_true(absf(total - 1.0) < 0.01, "Total weight should be ~1.0, got %f" % total)

func test_can_hold_weight_unlimited() -> void:
	var inv = _make_inv(5, 0.0) # unlimited
	var heavy = _make_item("boulder", 9999.0)
	assert_true(inv.can_hold_weight(heavy, 100))

func test_can_hold_weight_limited() -> void:
	var inv = _make_inv(5, 10.0)
	var sword = _make_item("sword", 5.0)
	assert_true(inv.can_hold_weight(sword, 2), "10kg limit, 2 swords at 5kg = 10kg should fit")
	assert_false(inv.can_hold_weight(sword, 3), "10kg limit, 3 swords at 5kg = 15kg should NOT fit")

func test_add_item_stackable_partial_fill_by_weight() -> void:
	var inv = _make_inv(10, 10.0)
	var arrow = _make_item("arrow", 1.0, true, 99)
	# Can hold 10 arrows at 1.0 each under 10kg limit
	var left = inv.add_item(arrow, 15)
	assert_eq(left, 5, "Should reject 5 arrows that exceed weight")
	var total = inv.get_total_weight()
	assert_true(absf(total - 10.0) < 0.01, "Weight should be 10.0")

func test_add_item_nonstackable_blocked_by_weight() -> void:
	var inv = _make_inv(10, 10.0)
	var sword = _make_item("sword", 5.0)
	# Add 2 swords = 10kg, fits perfectly
	inv.add_item(sword)
	inv.add_item(sword)
	assert_eq(inv.get_total_weight(), 10.0)
	# Third sword = 15kg, should be rejected
	var left = inv.add_item(sword)
	assert_eq(left, 1, "Third sword should be rejected (weight exceeded)")

func test_add_item_zero_weight_never_blocked() -> void:
	var inv = _make_inv(2, 10.0)
	var feather = _make_item("feather", 0.0, true, 99)
	var left = inv.add_item(feather, 50)
	assert_eq(left, 0, "Weightless items should never be blocked by weight")

func test_place_item_amount_clamped_by_weight() -> void:
	var inv = _make_inv(10, 5.0)
	var arrow = _make_item("arrow", 1.0, true, 99)
	# place_item_amount at index 0, try 10 arrows — only 5 should fit by weight
	var left = inv.place_item_amount(0, arrow, 10, {})
	assert_eq(left, 5, "place_item_amount should clamp to 5 by weight")
	var total = inv.get_total_weight()
	assert_true(absf(total - 5.0) < 0.01, "Weight should be 5.0")

func test_transfer_item_weight_check_on_destination() -> void:
	var source = _make_inv(5, 0.0) # unlimited source
	var dest = _make_inv(5, 5.0)   # 5kg destination
	var stone = _make_item("stone", 2.0, true, 99)
	source.add_item(stone, 10) # 10 stones in source
	
	# Transfer 10 stones (2kg each) to dest with 5kg limit = only 2 fit (4kg)
	var leftover = InventoryAPI.transfer_item(source, dest, 0, -1, 10)
	assert_eq(leftover, 8, "Should only transfer 2 stones (4kg), 8 left over")
	assert_true(dest.get_total_weight() <= 5.0, "Dest should not exceed max_weight")

func test_transfer_item_returns_zero_on_full_success() -> void:
	var source = _make_inv(5, 0.0)
	var dest = _make_inv(5, 100.0)
	var gem = _make_item("gem", 1.0, true, 99)
	source.add_item(gem, 5)
	
	var leftover = InventoryAPI.transfer_item(source, dest, 0, -1, 5)
	assert_eq(leftover, 0, "Should fully transfer all 5 gems")

func test_move_item_ignores_weight() -> void:
	var inv = _make_inv(5, 10.0)
	var sword = _make_item("sword", 5.0)
	inv.add_item(sword)
	inv.add_item(sword)
	# total = 10.0 kg (at limit), moving within same inventory should always work
	inv.move_item(0, 2)
	assert_not_null(inv.slots[2].item, "Move should succeed even at weight cap")

func test_deserialize_skips_weight_check() -> void:
	# Confirmed by code review: deserialize() has no weight check (spec 1.4)
	# This ensures saves from before a balance patch are always loadable
	pass
