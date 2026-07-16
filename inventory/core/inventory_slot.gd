@tool
extends Resource
class_name InventorySlot

# ช่องนี้เก็บไอเทมอะไร? (ถ้าเป็น null คือช่องว่าง)
## The ItemData resource currently occupying this slot.
@export var item: ItemData
# มีไอเทมกี่ชิ้น?
## The number of items in this slot.
@export var amount: int = 0
# โมดูลไอเทมที่ช่องนี้ยินยอมให้ใส่ (หากว่างไว้ จะใส่ไอเทมประเภทใดก็ได้)
## If defined, this slot will only accept items that contain AT LEAST ONE of these modules. Leave empty to accept any module.
@export var accepted_modules: Array[Script] = []
# หมวดหมู่ไอเทมที่รับได้ (เช่น ["equip_0"] สำหรับหมวก) ถ้าปล่อยว่างจะรับได้ทุกหมวด
## If defined, this slot will only accept items whose ID contains these categories (e.g. 'equip_', 'weapon_'). Leave empty to accept any category.
@export var accepted_categories: Array[StringName] = []
# ใช้แทนที่ max_stack ของไอเทม (ถ้ามากกว่า 0) เช่น บังคับให้ช่องอุปกรณ์มีได้แค่ 1 ชิ้น
## Overrides the item's max stack limit for this specific slot (e.g. set to 1 for equipment slots). Set to 0 to use the item's default limit.
@export var max_amount_override: int = 0
# คืนค่าจำนวนสูงสุดที่ช่องนี้จะเก็บไอเทมชนิดนั้นๆ ได้
func get_max_stack(item_data: ItemData) -> int:
	if item_data == null: return 0
	if max_amount_override > 0:
		return min(max_amount_override, item_data.max_stack)
	return item_data.max_stack

# ตัวแปรระบุว่าช่องนี้ถูกช่องหลักอื่นจองไว้ (สล๊อตไอเทมขนาดใหญ่)
var occupied_by: InventorySlot = null

# ค่าสถานะที่ "เปลี่ยนแปลงได้เฉพาะชิ้นนี้" (เช่น durability ปัจจุบัน, ความสด)
var runtime_data: Dictionary = {}

# เตรียมค่า runtime เริ่มต้นจาก module ของไอเทม
func init_runtime(item_data: ItemData) -> void:
	runtime_data.clear()
	if item_data == null:
		return
	for module in item_data.modules:
		if module.has_method("get_default_runtime_data"):
			var defaults = module.get_default_runtime_data()
			for key in defaults:
				runtime_data[key] = defaults[key]

# ดึงช่องเจ้าของข้อมูลจริง (หากตัวเองเป็นช่องที่ถูกจอง จะชี้ไปยังสล็อตหลัก)
func get_owning_slot() -> InventorySlot:
	if occupied_by != null:
		return occupied_by
	return self

# เช็คว่าตัวเองเป็นช่องที่ถูกจองไว้หรือไม่
func is_occupied_cell() -> bool:
	return occupied_by != null

# เช็คสิทธิ์ตามกฎความเข้ากันได้ว่าสล็อตนี้สามารถรับไอเทมได้หรือไม่ (Pure Calculation)
func can_accept(item_data: ItemData) -> bool:
	if item_data == null:
		return false
		
	# หากช่องนี้ถูกจองไว้โดยไอเทมชิ้นอื่นแล้ว จะไม่สามารถรับของใหม่ได้
	if occupied_by != null:
		return false
		
	# ตรวจสอบว่าไอเทมมี Category ตรงกับที่สล็อตอนุญาตหรือไม่ (ถ้ามีการตั้งค่าไว้)
	if not accepted_categories.is_empty():
		var has_valid_category = false
		for module in item_data.modules:
			if module.has_method("get_item_categories"):
				var cats = module.get_item_categories()
				for cat in cats:
					if cat in accepted_categories:
						has_valid_category = true
						break
			if has_valid_category:
				break
		if not has_valid_category:
			return false
			
	# หากสล็อตจำกัดประเภทโมดูลที่รับได้ ให้ตรวจสอบว่าไอเทมมีโมดูลนั้นๆ หรือไม่
	if not accepted_modules.is_empty():
		var has_valid_module = false
		for mod_class in accepted_modules:
			if item_data.get_module(mod_class) != null:
				has_valid_module = true
				break
		if not has_valid_module:
			return false
			
	return true


