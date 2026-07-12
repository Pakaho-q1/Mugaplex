extends ItemModule
class_name EquipmentModule

enum EquipSlot { HEAD, BODY, MAIN_HAND, OFF_HAND, ACCESSORY }

@export var slot: EquipSlot = EquipSlot.MAIN_HAND
@export var max_durability: float = 100.0

func get_default_runtime_data() -> Dictionary:
	return {"durability": max_durability}

func get_runtime_tooltip(runtime_data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if runtime_data.has("durability"):
		lines.append("• Durability: %.1f / %.1f" % [runtime_data["durability"], max_durability])
	return lines

func get_item_categories() -> Array[StringName]:
	# แปลง EquipSlot (enum) เป็น string เช่น "EQUIP_HEAD" หรือ "0", "1", "2"
	# เพื่อความปลอดภัย ให้ใช้เป็น StringName("equip_" + str(slot))
	return [StringName("equip_" + str(slot))]
