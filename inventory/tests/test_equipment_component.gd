extends TestSuite
class_name TestEquipmentComponent

func _init() -> void:
	suite_name = "EquipmentComponent"

func _make_inventory(size: int = 5) -> InventoryComponent:
	var inv = InventoryComponent.new()
	inv.max_slots = size
	inv.grid_columns = size
	inv._ready()
	return inv

func test_equip_from_inventory_success() -> void:
	var inv = _make_inventory(2)
	var equip = EquipmentComponent.new()
	equip._ready()
	
	var item = ItemData.new()
	var module = EquipmentModule.new()
	module.slot = EquipmentComponent.EquipSlot.HEAD
	item.modules.assign([module])
	
	inv.add_item(item, 1)
	
	# Attempt to equip
	var old_item = equip.equip_from_inventory(inv, 0, EquipmentComponent.EquipSlot.HEAD)
	
	assert_null(old_item, "ควบคืน null เมื่อสวมใส่ช่องว่าง")
	assert_eq(equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].item, item, "อุปกรณ์ต้องไปอยู่ในสล็อต HEAD ของ EquipmentComponent")
	assert_null(inv.slots[0].item, "ไอเทมต้องหายไปจาก Inventory")
	assert_eq(equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].amount, 1, "จำนวนต้องเป็น 1")

func test_equip_rejects_wrong_category() -> void:
	var inv = _make_inventory(2)
	var equip = EquipmentComponent.new()
	equip._ready()
	
	var item = ItemData.new()
	var module = EquipmentModule.new()
	# ตั้งเป็น BODY แต่พยายามใส่หัว
	module.slot = EquipmentComponent.EquipSlot.BODY
	item.modules.assign([module])
	
	inv.add_item(item, 1)
	
	# Attempt to equip to HEAD
	var old_item = equip.equip_from_inventory(inv, 0, EquipmentComponent.EquipSlot.HEAD)
	
	assert_null(old_item, "ต้องคืน null เมื่อสวมใส่ไม่ได้")
	assert_null(equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].item, "อุปกรณ์ต้องไม่ถูกสวม")
	assert_eq(inv.slots[0].item, item, "ไอเทมต้องยังอยู่ใน Inventory")

func test_unequip_to_inventory_success() -> void:
	var inv = _make_inventory(2)
	var equip = EquipmentComponent.new()
	equip._ready()
	
	var item = ItemData.new()
	var module = EquipmentModule.new()
	module.slot = EquipmentComponent.EquipSlot.HEAD
	item.modules.assign([module])
	
	equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].item = item
	equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].amount = 1
	
	var success = equip.unequip_to_inventory(inv, EquipmentComponent.EquipSlot.HEAD)
	
	assert_true(success, "unequip_to_inventory ควบคืน true เมื่อสำเร็จ")
	assert_null(equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].item, "ไอเทมต้องหายไปจากช่องสวมใส่")
	assert_eq(inv.slots[0].item, item, "ไอเทมต้องกลับมาอยู่ใน Inventory")
	
func test_stats_aggregation_works_with_inventory_slot() -> void:
	var equip = EquipmentComponent.new()
	equip._ready()
	
	var item = ItemData.new()
	var armor = ArmorModule.new()
	armor.physical_defense = 10.0
	var module = EquipmentModule.new()
	module.slot = EquipmentComponent.EquipSlot.BODY
	item.modules.assign([armor, module])
	
	equip.equip_slots[EquipmentComponent.EquipSlot.BODY].item = item
	equip.equip_slots[EquipmentComponent.EquipSlot.BODY].amount = 1
	
	# Mock applying stats (normally done in equip_from_inventory or deserialize)
	equip._apply_equip_stats(item, true)
	
	var stats = equip.get_total_stats()
	assert_eq(stats["physical_defense"], 10.0, "total_stats ต้องดึง physical_defense จากชุดเกราะได้")
	assert_eq(equip.get_physical_defense(), 10.0, "get_physical_defense() ต้องรวมค่าจากทุกสล็อตได้ถูกต้อง")

func test_serialize_deserialize_maintains_inventory_slot_structure() -> void:
	var equip = EquipmentComponent.new()
	equip._ready()
	
	var item = ItemData.new()
	item.item_id = &"test_helmet"
	var module = EquipmentModule.new()
	module.slot = EquipmentComponent.EquipSlot.HEAD
	item.modules.assign([module])
	
	equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].item = item
	equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].amount = 1
	equip.equip_slots[EquipmentComponent.EquipSlot.HEAD].runtime_data["durability"] = 50.0
	
	var data = equip.serialize()
	assert_eq(data["equipped"][EquipmentComponent.EquipSlot.HEAD], "test_helmet", "ข้อมูลการเซฟต้องเก็บ item_id ไว้ใน equipped")
	assert_eq(data["equipped_slot_data"][EquipmentComponent.EquipSlot.HEAD]["durability"], 50.0, "runtime_data ต้องถูกเซฟไว้ใน equipped_slot_data")
