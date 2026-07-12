extends TestSuite
class_name TestInventorySlot

func _init() -> void:
	suite_name = "InventorySlot"


func test_can_accept_returns_false_for_null_item() -> void:
	var slot = InventorySlot.new()
	assert_false(slot.can_accept(null), "can_accept(null) ต้องเป็น false เสมอ")


func test_can_accept_returns_true_when_no_filter_set() -> void:
	var slot = InventorySlot.new()
	var item = ItemData.new()
	assert_true(slot.can_accept(item), "slot ที่ไม่ตั้ง accepted_modules ควรรับไอเทมทุกชนิด")


func test_can_accept_rejects_item_without_matching_module() -> void:
	var slot = InventorySlot.new()
	slot.accepted_modules.assign([WeaponModule])

	var item = ItemData.new()
	item.modules.assign([ArmorModule.new()])

	assert_false(slot.can_accept(item), "slot ที่รับเฉพาะ WeaponModule ต้องปฏิเสธไอเทมที่มีแค่ ArmorModule")


func test_can_accept_accepts_item_with_matching_module() -> void:
	var slot = InventorySlot.new()
	slot.accepted_modules.assign([WeaponModule])

	var item = ItemData.new()
	item.modules.assign([WeaponModule.new()])

	assert_true(slot.can_accept(item), "slot ที่รับ WeaponModule ต้องยอมรับไอเทมที่มี WeaponModule ติดอยู่")


func test_can_accept_respects_categories() -> void:
	var slot = InventorySlot.new()
	slot.accepted_categories.assign([StringName("equip_0")])
	
	var item_head = ItemData.new()
	var equip_head = EquipmentModule.new()
	equip_head.slot = 0 # HEAD
	item_head.modules.assign([equip_head])
	
	var item_body = ItemData.new()
	var equip_body = EquipmentModule.new()
	equip_body.slot = 1 # BODY
	item_body.modules.assign([equip_body])
	
	assert_true(slot.can_accept(item_head), "slot ต้องรับไอเทมที่มี category ตรงกันได้")
	assert_false(slot.can_accept(item_body), "slot ต้องปฏิเสธไอเทมที่มี category ไม่ตรงกัน")


func test_can_accept_rejects_when_slot_is_occupied() -> void:
	var anchor = InventorySlot.new()
	var slot = InventorySlot.new()
	slot.occupied_by = anchor

	var item = ItemData.new()
	assert_false(slot.can_accept(item), "ช่องที่ถูกจองอยู่แล้ว (multi-cell) ต้องรับของใหม่ไม่ได้")


func test_get_owning_slot_returns_self_when_not_occupied() -> void:
	var slot = InventorySlot.new()
	assert_eq(slot.get_owning_slot(), slot, "ช่องที่ไม่ถูกจอง ต้องคืนตัวเองเป็นเจ้าของ")


func test_get_owning_slot_returns_anchor_when_occupied() -> void:
	var anchor = InventorySlot.new()
	var slot = InventorySlot.new()
	slot.occupied_by = anchor
	assert_eq(slot.get_owning_slot(), anchor, "ช่องที่ถูกจอง ต้องคืน anchor เป็นเจ้าของตัวจริง")


func test_is_occupied_cell() -> void:
	var slot = InventorySlot.new()
	assert_false(slot.is_occupied_cell(), "ช่องปกติที่ยังไม่ถูกจอง ต้องคืน false")

	slot.occupied_by = InventorySlot.new()
	assert_true(slot.is_occupied_cell(), "ช่องที่เซ็ต occupied_by แล้ว ต้องคืน true")


func test_init_runtime_sets_durability_from_equipment_module() -> void:
	var equip = EquipmentModule.new()
	equip.max_durability = 50.0

	var item = ItemData.new()
	item.modules.assign([equip])

	var slot = InventorySlot.new()
	slot.init_runtime(item)

	assert_eq(slot.runtime_data.get("durability"), 50.0, "init_runtime ต้องตั้ง durability เริ่มต้นตาม max_durability ของ module")


func test_init_runtime_clears_previous_data() -> void:
	var slot = InventorySlot.new()
	slot.runtime_data["leftover_key"] = 999
	slot.init_runtime(null)
	assert_true(slot.runtime_data.is_empty(), "init_runtime(null) ต้องเคลียร์ runtime_data เดิมทิ้ง")
