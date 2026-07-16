extends TestSuite
class_name TestInventoryAPI

const InventoryAPI = preload("res://addons/mugaplex/inventory/api/inventory_api.gd")

func _init() -> void:
	suite_name = "InventoryAPI"

func _make_inventory(size: int = 5) -> InventoryComponent:
	var inv = InventoryComponent.new()
	inv.max_slots = size
	inv.grid_columns = size
	inv._ready()
	return inv

func test_drop_item_success() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 5
	inv.add_item(item, 5)
	
	var state = {"emitted": false, "amount": 0}
	
	var on_dropped = func(i: ItemData, a: int, r: Dictionary):
		state["emitted"] = true
		state["amount"] = a
		
	InventoryManager.item_dropped.connect(on_dropped)
	
	var success = InventoryAPI.drop_item(inv, 0, 2)
	assert_true(success, "drop_item ควบคืน true")
	assert_eq(inv.slots[0].amount, 3, "จำนวนของในสล็อตต้องเหลือ 3")
	assert_true(state["emitted"], "signal item_dropped ต้องถูกส่งออกไป")
	assert_eq(state["amount"], 2, "จำนวนของที่ตกพื้นต้องเท่ากับ 2")
	
	InventoryManager.item_dropped.disconnect(on_dropped)

func test_split_stack_success() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10
	inv.add_item(item, 5)
	
	# Split 2 items to an empty slot
	var success = InventoryAPI.split_stack(inv, 0, 1, 2)
	assert_true(success, "split_stack ไปช่องว่าง ควบคืน true")
	assert_eq(inv.slots[0].amount, 3, "ช่องต้นทางเหลือ 3")
	assert_eq(inv.slots[1].item, item, "ช่องปลายทางมีไอเทม")
	assert_eq(inv.slots[1].amount, 2, "ช่องปลายทางมีจำนวน 2")
	
	# Split 1 item to the same item slot
	success = InventoryAPI.split_stack(inv, 1, 0, 1)
	assert_true(success, "split_stack ไปรวมกับกองเดิม ควบคืน true")
	assert_eq(inv.slots[1].amount, 1, "ช่องต้นทางเหลือ 1")
	assert_eq(inv.slots[0].amount, 4, "ช่องปลายทางมีจำนวน 4")

func test_sort_inventory() -> void:
	var inv = _make_inventory(6) # Grid 6x1
	
	# สร้างไอเทม 3 แบบ
	var item_small = ItemData.new()
	item_small.item_id = "apple"
	item_small.grid_size = Vector2i(1, 1)
	item_small.stackable = true
	item_small.max_stack = 10
	
	var item_big = ItemData.new()
	item_big.item_id = "rifle"
	item_big.grid_size = Vector2i(3, 1)
	
	var item_medium = ItemData.new()
	item_medium.item_id = "medkit"
	item_medium.grid_size = Vector2i(2, 1)
	
	# ยัดของแบบสลับตำแหน่ง (จงใจให้ไม่เป็นระเบียบ)
	# ใส่เล็กช่อง 0
	inv.add_item(item_small, 2)
	# ใส่กลางช่อง 1-2
	inv.slots[1].item = item_medium
	inv.slots[1].amount = 1
	inv._set_occupied(1, item_medium, false)
	# ใส่ใหญ่ช่อง 3-5
	inv.slots[3].item = item_big
	inv.slots[3].amount = 1
	inv._set_occupied(3, item_big, false)
	
	# กดเรียง
	InventoryAPI.sort_inventory(inv)
	
	# ตรวจสอบการเรียง (ใหญ่สุด (3) > กลาง (2) > เล็ก (1))
	# ควรจะอยู่ที่: ช่อง 0=ใหญ่, ช่อง 3=กลาง, ช่อง 5=เล็ก
	assert_eq(inv.slots[0].item, item_big, "ปืนใหญ่สุดต้องมาอยู่ช่องแรก")
	assert_eq(inv.slots[3].item, item_medium, "กล่องพยาบาลต้องมาอยู่ถัดไป")
	assert_eq(inv.slots[5].item, item_small, "แอปเปิ้ลต้องอยู่ท้ายสุด")

func test_sort_inventory_merge_stacks() -> void:
	var inv = _make_inventory(4)
	var item = ItemData.new()
	item.item_id = "wood"
	item.grid_size = Vector2i(1, 1)
	item.stackable = true
	item.max_stack = 5
	
	# กระจายไม้ 2 กอง (3 กับ 4) ซึ่งรวมกันได้ 5 + 2
	inv.slots[0].item = item
	inv.slots[0].amount = 3
	inv._set_occupied(0, item, false)
	
	inv.slots[2].item = item
	inv.slots[2].amount = 4
	inv._set_occupied(2, item, false)
	
	InventoryAPI.sort_inventory(inv)
	
	# ควรจะรวมเป็น กองละ 5 และ กองละ 2
	assert_eq(inv.slots[0].amount, 5, "กองแรกต้องถูกเติมจนเต็ม (5)")
	assert_eq(inv.slots[1].amount, 2, "กองที่สองคือส่วนที่เหลือ (2)")
	assert_null(inv.slots[2].item, "ช่องเดิมต้องว่าง")

func test_save_and_load_api() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.item_id = "test_item"
	inv.add_item(item, 1)
	
	# จำลองใส่ Registry
	var reg = inv.get_registry()
	reg.items[StringName(item.item_id)] = item
	
	var save_path = "user://test_api_save.json"
	var err = InventoryAPI.save_to_file(inv, null, save_path)
	assert_eq(err, OK, "save_to_file ต้องคืนค่า OK")
	
	var inv2 = _make_inventory(2)
	inv2._registry = reg # แชร์ Registry ตัวเดียวกันใน Test
	err = InventoryAPI.load_from_file(inv2, null, save_path)
	assert_eq(err, OK, "load_from_file ต้องคืนค่า OK")
	
	assert_not_null(inv2.slots[0].item, "ต้องโหลดไอเทมกลับมาได้")
	if inv2.slots[0].item:
		assert_eq(inv2.slots[0].item.item_id, StringName("test_item"), "ข้อมูลต้องถูกโหลดกลับมาถูกต้อง")
	
	# Cleanup
	reg.items.erase(StringName(item.item_id))
	var dir = DirAccess.open("user://")
	if dir.file_exists("test_api_save.json"):
		dir.remove("test_api_save.json")

func test_query_and_consume_api() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.item_id = "iron_ore"
	item.stackable = true
	item.max_stack = 10
	
	# ใส่แร่เหล็ก 2 กอง (กองละ 3 และ 4) รวมเป็น 7
	inv.slots[0].item = item
	inv.slots[0].amount = 3
	inv._set_occupied(0, item, false)
	
	inv.slots[2].item = item
	inv.slots[2].amount = 4
	inv._set_occupied(2, item, false)
	
	assert_true(InventoryAPI.has_item_amount(inv, item, 5), "ต้องเช็คเจอว่ามีของครบ 5")
	assert_true(InventoryAPI.has_item_amount(inv, item, 7), "ต้องเช็คเจอว่ามีของครบ 7")
	assert_false(InventoryAPI.has_item_amount(inv, item, 8), "ต้องเช็คว่าของไม่พอ 8")
	
	# หักของ 5 ชิ้น (จะหักกอง 3 จนหมด และหักกอง 4 ไป 2 เหลือ 2)
	var success = InventoryAPI.consume_item(inv, item, 5)
	assert_true(success, "ต้องหักของได้สำเร็จ")
	assert_null(inv.slots[0].item, "กองแรกต้องว่างเปล่า")
	assert_eq(inv.slots[2].amount, 2, "กองสองต้องเหลือ 2")
	
	# เช็คอีกรอบ
	assert_false(InventoryAPI.has_item_amount(inv, item, 3), "ตอนนี้ต้องเหลือแค่ 2 ห้ามมี 3")

func test_transfer_item_api() -> void:
	var player_inv = _make_inventory(2)
	var chest_inv = _make_inventory(2)
	
	var item = ItemData.new()
	item.item_id = "potion"
	item.stackable = true
	item.max_stack = 5
	
	# ยัดยาใส่กระเป๋าผู้เล่น
	player_inv.slots[0].item = item
	player_inv.slots[0].amount = 3
	player_inv._set_occupied(0, item, false)
	
	# ย้ายยา 2 ขวด ไปกล่องสมบัติ แบบไม่ระบุช่อง
	var success = InventoryAPI.transfer_item(player_inv, chest_inv, 0, -1, 2)
	assert_true(success, "ต้องย้ายของสำเร็จ")
	
	assert_eq(player_inv.slots[0].amount, 1, "ผู้เล่นต้องเหลือยา 1 ขวด")
	assert_eq(chest_inv.slots[0].item, item, "กล่องต้องมียา 1 ช่อง")
	assert_eq(chest_inv.slots[0].amount, 2, "กล่องต้องมียา 2 ขวด")
	
	# ย้ายส่วนที่เหลือทั้งหมดไปกล่องสมบัติ
	success = InventoryAPI.transfer_item(player_inv, chest_inv, 0, -1, 1)
	assert_true(success, "ต้องย้ายส่วนที่เหลือสำเร็จ")
	assert_null(player_inv.slots[0].item, "ผู้เล่นต้องไม่มียาแล้ว")
	assert_eq(chest_inv.slots[0].amount, 3, "กล่องสมบัติต้องมียารวม 3 ขวด (รวมกองให้)")
