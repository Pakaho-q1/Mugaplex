extends ItemModule
class_name PerishableModule

## Total time in seconds before the item spoils (default 10 mins).
@export var freshness_duration: float = 600.0
## Chance per second for the item to spoil instantly (0 = disabled).
@export var spoil_chance_per_second: float = 0.0
## The ItemData to replace this item with when it spoils (e.g. Rotten Food).
@export var spoiled_item: ItemData = null
## If true, the item is completely destroyed upon spoiling.
@export var destroy_on_spoil: bool = false

# เช็คว่าเน่าแล้วหรือยัง
func is_spoiled(runtime_data: Dictionary) -> bool:
	var freshness = runtime_data.get("freshness", freshness_duration)
	return freshness <= 0.0

# คำนวณความสดใหม่ (Pure Calculation) — ไม่แก้ไข slot เอง แค่รับค่าปัจจุบันแล้วคืนค่าใหม่
# ผู้เรียก (InventoryComponent) เป็นคนนำค่าที่คืนมาไปเซ็ตใส่ slot.runtime_data เอง
# คืนค่า: {"freshness": float ค่าใหม่, "spoiled": bool เน่าแล้วหรือยัง}
func calculate_decay(current_freshness: float, delta: float) -> Dictionary:
	var freshness = current_freshness - delta

	# โอกาสเสียเพิ่ม (ถ้าตั้งค่าไว้)
	if spoil_chance_per_second > 0.0 and randf() < spoil_chance_per_second * delta:
		freshness = 0.0

	freshness = max(freshness, 0.0)
	return {"freshness": freshness, "spoiled": freshness <= 0.0}

# ให้ % ความสด (0.0 - 1.0)
func get_freshness_ratio(runtime_data: Dictionary) -> float:
	var freshness = runtime_data.get("freshness", freshness_duration)
	return clamp(freshness / freshness_duration, 0.0, 1.0)

func get_default_runtime_data() -> Dictionary:
	return {"freshness": freshness_duration}

func get_runtime_tooltip(runtime_data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if runtime_data.has("freshness"):
		var pct = clamp(runtime_data["freshness"] / freshness_duration, 0.0, 1.0) * 100.0
		lines.append("• Freshness: %.1f%%" % pct)
	return lines

func before_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	var result = {"prevented": false}
	if is_spoiled(runtime_data):
		result.prevented = true
		result.message = "Item is spoiled!"
		if spoiled_item:
			result.new_item = spoiled_item
		elif destroy_on_spoil:
			result.destroyed = true
	return result

func on_update(delta: float, runtime_data: Dictionary) -> Dictionary:
	var result = {"runtime_data_update": {}, "new_item": null, "destroyed": false}
	var current_freshness = runtime_data.get("freshness", freshness_duration)
	var calc = calculate_decay(current_freshness, delta)
	
	if calc["freshness"] != current_freshness:
		result.runtime_data_update["freshness"] = calc["freshness"]
		
	if calc["spoiled"]:
		if spoiled_item:
			result.new_item = spoiled_item
		elif destroy_on_spoil:
			result.destroyed = true
	return result
