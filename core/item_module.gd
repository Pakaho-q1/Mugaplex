extends Resource
class_name ItemModule

# 1. คืนค่าเริ่มต้นสำหรับ runtime_data ในสล็อต
func get_default_runtime_data() -> Dictionary:
	return {}

# 2. เมื่อต้องการสืบค้นข้อมูล tooltip (อิสระจาก UI)
func get_runtime_tooltip(runtime_data: Dictionary) -> Array[String]:
	return []

# 3. ให้โมดูลทำงานทุกเฟรม (เช่น เน่าเสีย) คืนค่า {"runtime_data_update": Dictionary, "new_item": ItemData, "destroyed": bool}
func on_update(delta: float, runtime_data: Dictionary) -> Dictionary:
	return {}

# 4. เมื่อถูกตรวจสอบก่อนการใช้งาน (กันไม่ให้ใช้ เช่น ถ้าเน่าแล้ว)
func before_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	return {"prevented": false}

# 5. เมื่อถูกใช้งานไอเทม (คืนค่า payload และ flag ว่าไอเทมนี้ถูกใช้หมดไปหรือไม่)
func on_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	return {"consumed": false, "payload": {}}

# 6. คืนค่า Category ของโมดูลนี้ (ใช้สำหรับตรวจสอบ accepted_categories ในช่องกระเป๋า)
func get_item_categories() -> Array[StringName]:
	return []
