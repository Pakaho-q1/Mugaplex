extends Resource
class_name ItemModule

# 1. คืนค่าเริ่มต้นสำหรับ runtime_data ในสล็อต
func get_default_runtime_data() -> Dictionary:
	return {}

# 2. เมื่อต้องการสืบค้นข้อมูล tooltip (อิสระจาก UI)
func get_runtime_tooltip(runtime_data: Dictionary) -> Array[String]:
	return []

# 3. ให้โมดูลทำงานทุกเฟรม (เช่น เน่าเสีย) คืนค่า {"changed": bool, "new_item": ItemData, "destroyed": bool}
func on_update(delta: float, slot: InventorySlot) -> Dictionary:
	return {"changed": false}

# 4. เมื่อถูกตรวจสอบก่อนการใช้งาน (กันไม่ให้ใช้ เช่น ถ้าเน่าแล้ว)
func before_use(slot: InventorySlot, user: Node) -> Dictionary:
	return {"prevented": false}

# 5. เมื่อถูกใช้งานไอเทม (คืนค่า true หากถูกบริโภค)
func on_use(slot: InventorySlot, user: Node) -> bool:
	return false

# 6. คืนค่า Category ของโมดูลนี้ (ใช้สำหรับตรวจสอบ accepted_categories ในช่องกระเป๋า)
func get_item_categories() -> Array[StringName]:
	return []
