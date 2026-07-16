extends TestSuite
class_name TestInventoryComponent

func _init() -> void:
	suite_name = "InventoryComponent"


## สร้าง InventoryComponent พร้อม slots ครบ โดยไม่ต้องเข้า SceneTree จริง
## (เรียก _ready() ตรงๆ เพื่อให้ slots ถูกสร้างตาม max_slots)
func _make_inventory(max_slots: int = 5) -> InventoryComponent:
	var inv = InventoryComponent.new()
	inv.max_slots = max_slots
	inv._ready()
	return inv


func test_ready_creates_slots_matching_max_slots() -> void:
	var inv = _make_inventory(5)
	assert_eq(inv.slots.size(), 5, "จำนวนช่องหลัง _ready() ต้องตรงกับ max_slots")


# --- add_item ---

func test_add_item_null_item_data_is_rejected() -> void:
	var inv = _make_inventory(3)
	var overflow = inv.add_item(null, 5)
	assert_eq(overflow, 5, "ส่ง item_data เป็น null ต้องไม่เพิ่มอะไรเลย และคืนจำนวนเดิมทั้งหมด")


func test_add_item_zero_or_negative_amount_does_nothing() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	assert_eq(inv.add_item(item, 0), 0, "amount = 0 ต้องไม่ทำอะไร")
	assert_eq(inv.add_item(item, -5), 0, "amount ติดลบ ต้องไม่ทำอะไร (ไม่ crash)")
	assert_false(inv.has_item(item), "ไม่ควรมีไอเทมถูกเพิ่มเข้ากระเป๋าเลย")


func test_add_item_fills_empty_slot_for_non_stackable() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = false

	var overflow = inv.add_item(item, 1)

	assert_eq(overflow, 0, "เพิ่มไอเทมชิ้นเดียวลงกระเป๋าที่มีที่ว่าง ต้องสำเร็จ (overflow = 0)")
	assert_eq(inv.slots[0].item, item)
	assert_eq(inv.slots[0].amount, 1)


func test_add_item_stacks_into_existing_slot() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10

	inv.add_item(item, 4)
	inv.add_item(item, 3)

	assert_eq(inv.slots[0].amount, 7, "ของชนิดเดียวกันต้อง stack รวมกันในช่องเดิม ไม่กระจายไปช่องใหม่")
	assert_null(inv.slots[1].item, "ช่องถัดไปต้องยังว่างอยู่ ไม่ถูกใช้โดยไม่จำเป็น")


func test_add_item_returns_overflow_when_exceeds_single_slot_and_bag_full() -> void:
	var inv = _make_inventory(1) # กระเป๋ามีช่องเดียว
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 5

	var overflow = inv.add_item(item, 8)

	assert_eq(overflow, 3, "max_stack=5 ช่องเดียว รับของ 8 ชิ้น ต้องล้นออกมา 3 ชิ้น")
	assert_eq(inv.slots[0].amount, 5, "ช่องเดียวที่มีต้องเต็ม max_stack")


func test_add_item_respects_slot_filter() -> void:
	var inv = _make_inventory(1)
	inv.slots[0].accepted_modules.assign([WeaponModule])

	var non_weapon_item = ItemData.new()
	non_weapon_item.stackable = false

	var overflow = inv.add_item(non_weapon_item, 1)

	assert_eq(overflow, 1, "ช่องที่กรองเฉพาะ WeaponModule ต้องปฏิเสธไอเทมที่ไม่มี WeaponModule (ของต้องล้นออกมาทั้งหมด)")
	assert_null(inv.slots[0].item, "ไอเทมที่ไม่ผ่านตัวกรอง ต้องไม่ถูกใส่เข้าช่องนั้น")


# --- move_item ---

func test_move_item_rejects_out_of_bounds_index_without_crashing() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = false
	inv.add_item(item, 1)

	inv.move_item(0, 99) # index เกินขอบ ต้องไม่ crash และไม่ทำอะไร

	assert_eq(inv.slots[0].item, item, "index ผิดขอบ ของต้องอยู่ที่เดิม ไม่หายไปไหน")


func test_move_item_does_nothing_when_source_is_empty() -> void:
	var inv = _make_inventory(2)
	inv.move_item(0, 1) # ทั้งคู่ว่างเปล่า

	assert_null(inv.slots[0].item)
	assert_null(inv.slots[1].item)


func test_move_item_does_nothing_when_source_equals_target() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = false
	inv.add_item(item, 1)

	inv.move_item(0, 0)

	assert_eq(inv.slots[0].item, item, "ย้ายช่องเดิมไปช่องเดิม ต้องไม่เกิดอะไรขึ้น")


func test_move_item_swaps_two_different_items() -> void:
	var inv = _make_inventory(2)
	var item_a = ItemData.new()
	var item_b = ItemData.new()

	inv.slots[0].item = item_a
	inv.slots[0].amount = 1
	inv.slots[1].item = item_b
	inv.slots[1].amount = 1

	inv.move_item(0, 1)

	assert_eq(inv.slots[0].item, item_b, "หลังสลับ ช่อง 0 ต้องได้ item_b")
	assert_eq(inv.slots[1].item, item_a, "หลังสลับ ช่อง 1 ต้องได้ item_a")


func test_move_item_merges_same_stackable_item() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10

	inv.slots[0].item = item
	inv.slots[0].amount = 3
	inv.slots[1].item = item
	inv.slots[1].amount = 4

	inv.move_item(0, 1)

	assert_null(inv.slots[0].item, "ของ stack เดียวกันย้ายไปรวมกันหมดแล้ว ช่องต้นทางต้องว่าง")
	assert_eq(inv.slots[1].amount, 7, "จำนวนต้องรวมกันเป็น 3+4=7")


func test_move_item_respects_target_slot_filter() -> void:
	var inv = _make_inventory(2)
	inv.slots[1].accepted_modules.assign([WeaponModule])

	var non_weapon_item = ItemData.new()
	non_weapon_item.stackable = false
	inv.slots[0].item = non_weapon_item
	inv.slots[0].amount = 1

	inv.move_item(0, 1)

	assert_eq(inv.slots[0].item, non_weapon_item, "ช่องปลายทางไม่รับไอเทมประเภทนี้ ของต้องอยู่ที่เดิม ไม่ย้าย")
	assert_null(inv.slots[1].item)


# --- remove_item / has_item / count_item ---

func test_remove_item_reduces_amount_correctly() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10
	inv.add_item(item, 5)

	var removed = inv.remove_item(item, 3)

	assert_eq(removed, 3, "ลบ 3 จาก 5 ต้องลบสำเร็จ 3 ชิ้น")
	assert_eq(inv.count_item(item), 2, "เหลือ 2 ชิ้นในกระเป๋า")


func test_remove_item_clears_slot_when_amount_reaches_zero() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = false
	inv.add_item(item, 1)

	inv.remove_item(item, 1)

	assert_null(inv.slots[0].item, "ลบจนหมดแล้ว ช่องต้องกลับไปเป็นค่าว่าง (null) ไม่ใช่ amount=0 ค้างไว้")


func test_remove_item_null_or_zero_amount_returns_zero() -> void:
	var inv = _make_inventory(2)
	assert_eq(inv.remove_item(null, 1), 0)

	var item = ItemData.new()
	assert_eq(inv.remove_item(item, 0), 0)


func test_has_item_and_count_item_reflect_state() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10

	assert_false(inv.has_item(item), "ยังไม่เพิ่ม ต้องยังไม่มี")

	inv.add_item(item, 4)

	assert_true(inv.has_item(item))
	assert_eq(inv.count_item(item), 4)


func test_get_item_indices_finds_all_matching_slots() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = false

	inv.slots[0].item = item
	inv.slots[0].amount = 1
	inv.slots[2].item = item
	inv.slots[2].amount = 1

	var indices = inv.get_item_indices(item)

	assert_eq(indices.size(), 2, "ต้องเจอไอเทมชนิดนี้ 2 ช่อง")
	assert_true(0 in indices)
	assert_true(2 in indices)


# --- use_item (Mechanism vs Policy) ---

func test_use_item_out_of_bounds_returns_failure_without_crashing() -> void:
	var inv = _make_inventory(2)
	var result = inv.use_item(99)
	assert_false(result["success"], "index เกินขอบ ต้องคืน success=false ไม่ crash")


func test_use_item_on_empty_slot_returns_failure() -> void:
	var inv = _make_inventory(2)
	var result = inv.use_item(0)
	assert_false(result["success"], "ช่องว่างต้อง use ไม่สำเร็จ")


func test_use_item_consumable_reduces_amount_by_one() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10

	var consumable = ConsumableModule.new()
	consumable.consume_on_use = true
	item.modules.assign([consumable])

	inv.add_item(item, 3)
	var result = inv.use_item(0)

	assert_true(result["success"])
	assert_eq(inv.slots[0].amount, 2, "ใช้ของ consumable แล้วจำนวนต้องลดลง 1 (จาก 3 เหลือ 2)")


func test_use_item_only_emits_signal_does_not_apply_gameplay_effect_itself() -> void:
	# ทดสอบหัวใจของ Mechanism vs Policy:
	# use_item() ต้องแค่ emit signal ออกไป ไม่ใช่ไปแก้ HP/stat ของใครเอง
	# (framework ไม่รู้จักคำว่า "heal" เลย)
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = false

	var food = FoodModule.new()
	food.health_restore = 20.0
	item.modules.assign([food])

	inv.add_item(item, 1)

	var received_items: Array = []
	inv.item_used.connect(func(used_item, idx, user): received_items.append(used_item))

	inv.use_item(0)

	assert_eq(received_items.size(), 1, "use_item ต้อง emit signal item_used ออกไปให้ policy ฝั่งเกมจัดการต่อ")
	assert_eq(received_items[0], item)


func test_use_item_on_spoiled_perishable_fails_and_destroys_item() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = false

	var perishable = PerishableModule.new()
	perishable.freshness_duration = 100.0
	perishable.destroy_on_spoil = true
	item.modules.assign([perishable])

	inv.add_item(item, 1)
	inv.slots[0].runtime_data["freshness"] = 0.0 # บังคับให้เน่าแล้ว

	var result = inv.use_item(0)

	assert_false(result["success"], "ไอเทมที่เน่าแล้วต้องใช้ไม่สำเร็จ")
	assert_null(inv.slots[0].item, "destroy_on_spoil=true ต้องทำให้ของหายไปเมื่อพบว่าเน่า")


# --- update_modules ---

func test_update_modules_decays_freshness_over_time() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.stackable = false

	var perishable = PerishableModule.new()
	perishable.freshness_duration = 10.0
	item.modules.assign([perishable])

	inv.add_item(item, 1) # init_runtime ตั้ง freshness เริ่มต้น = 10.0
	inv.update_modules(4.0)

	assert_eq(inv.slots[0].runtime_data["freshness"], 6.0, "ผ่านไป 4 วินาที ความสดต้องลดจาก 10 เหลือ 6")


# --- serialize (ไม่ทดสอบ deserialize เพราะต้องพึ่งไฟล์ .tres จริงจาก registry — เป็น integration test แยกต่างหาก) ---

func test_serialize_returns_array_matching_slot_count() -> void:
	var inv = _make_inventory(2)
	var item = ItemData.new()
	item.item_id = &"test_sword"
	item.stackable = false
	inv.add_item(item, 1)

	var data = inv.serialize()

	assert_eq(data.size(), 2, "serialize ต้องคืน array ยาวเท่าจำนวนช่องเสมอ (รวมช่องว่างด้วย)")
	assert_eq(data[0]["item_id"], "test_sword")
	assert_eq(data[0]["amount"], 1)
	assert_null(data[1], "ช่องว่างต้อง serialize เป็น null")

# --- split_stack ---

func test_split_stack_success() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10
	inv.add_item(item, 8)
	
	assert_true(inv.split_stack(0, 1, 3), "split_stack should return true")
	assert_eq(inv.slots[0].amount, 5)
	assert_eq(inv.slots[1].amount, 3)
	assert_eq(inv.slots[1].item, item)

func test_split_stack_fails_if_target_full() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 5
	inv.add_item(item, 5)
	inv.slots[1].item = item
	inv.slots[1].amount = 5
	
	assert_false(inv.split_stack(0, 1, 2))
	assert_eq(inv.slots[0].amount, 5)

# --- drop_item ---

func test_drop_item_emits_signal_and_reduces_amount() -> void:
	var inv = _make_inventory(3)
	var item = ItemData.new()
	item.stackable = true
	item.max_stack = 10
	inv.add_item(item, 5)
	
	var emitted = [false]
	inv.item_dropped.connect(func(i, amt, rd, idx, dropper):
		emitted[0] = true
		assert_eq(amt, 2)
	)
	
	assert_true(inv.drop_item(0, 2), "drop_item should return true")
	assert_true(emitted[0], "item_dropped signal should be emitted")
	assert_eq(inv.slots[0].amount, 3)

# --- can_place_item_at (Multi-cell) ---

func test_can_place_item_at_checks_grid_bounds_and_occupied_cells() -> void:
	var inv = _make_inventory(9)
	inv.grid_columns = 3
	
	var item_1x1 = ItemData.new()
	item_1x1.grid_size = Vector2i(1, 1)
	
	var item_2x2 = ItemData.new()
	item_2x2.grid_size = Vector2i(2, 2)
	
	assert_true(inv.can_place_item_at(item_2x2, 0), "ไอเทม 2x2 สามารถวางที่มุมซ้ายบน 0 ได้")
	assert_false(inv.can_place_item_at(item_2x2, 2), "ไอเทม 2x2 วางที่ index 2 จะล้นขอบขวา")
	
	# จำลองวางไอเทม 2x2 ไปที่ index 0
	inv.add_item(item_2x2, 1)
	
	assert_false(inv.can_place_item_at(item_1x1, 0), "วางทับช่อง 0 ไม่ได้")
	assert_false(inv.can_place_item_at(item_1x1, 1), "วางทับช่อง 1 (ถูกจองโดย 2x2) ไม่ได้")
	assert_false(inv.can_place_item_at(item_1x1, 3), "วางทับช่อง 3 (ถูกจองโดย 2x2) ไม่ได้")
	assert_false(inv.can_place_item_at(item_1x1, 4), "วางทับช่อง 4 (ถูกจองโดย 2x2) ไม่ได้")
	assert_true(inv.can_place_item_at(item_1x1, 2), "วางช่อง 2 (ว่าง) ได้")
