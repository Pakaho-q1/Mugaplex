extends Node
class_name EquipmentComponent

signal equipment_changed

enum EquipSlot { HEAD, BODY, MAIN_HAND, OFF_HAND, ACCESSORY }

# Map slot -> InventorySlot
var equip_slots: Dictionary = {
	EquipSlot.HEAD: null,
	EquipSlot.BODY: null,
	EquipSlot.MAIN_HAND: null,
	EquipSlot.OFF_HAND: null,
	EquipSlot.ACCESSORY: null
}

# Total stats from all equipped items
var total_stats: Dictionary = {
	"physical_damage": 0.0,
	"attack_speed": 1.0,
	"physical_defense": 0.0,
	"magic_resistance": 0.0,
	"durability": 0.0
}

func _ready():
	# Ensure all slots initialized and configured
	for slot in EquipSlot.values():
		var inv_slot = InventorySlot.new()
		inv_slot.max_amount_override = 1
		# Config categories depending on the slot type
		# The categories should match EquipmentModule slot types.
		var cat_name = "equip_%d" % slot
		inv_slot.accepted_categories.assign([StringName(cat_name)])
		equip_slots[slot] = inv_slot

# สวมของจาก InventoryComponent -> Equipment slot
# คืน ItemData ที่ถูกแทนที่ (ถ้ามี) หรือ null ถ้าสวมใหม่
func equip_from_inventory(inventory: InventoryComponent, inv_index: int, slot: EquipSlot) -> ItemData:
	var inv_slot = inventory.get_slot(inv_index)
	if not inv_slot or inv_slot.item == null:
		push_error("equip_from_inventory: ช่อง inventory ว่างหรือ index ผิด")
		return null
	
	var item = inv_slot.item
	var eq_slot = equip_slots[slot]
	
	if not eq_slot.can_accept(item):
		push_error("equip_from_inventory: ไอเทมชิ้นนี้ไม่มีหมวดหมู่ที่ตรงกับสล็อต %d" % slot)
		return null
	
	# ถอดของเก่าก่อน (ถ้ามี)
	var old_item = eq_slot.item
	if old_item:
		var unequip_success = unequip_to_inventory(inventory, slot)
		if not unequip_success:
			push_error("equip_from_inventory: กระเป๋าเต็ม ไม่สามารถถอดชิ้นเดิมเพื่อสวมชิ้นใหม่ได้")
			return null
	
	# สวมของใหม่
	eq_slot.item = item
	eq_slot.amount = 1
	
	# ใช้ runtime_data จาก inventory
	eq_slot.runtime_data = inv_slot.runtime_data.duplicate(true)
	
	# ลดจำนวนใน inventory
	if inv_slot.is_occupied_cell():
		# ถ้าคลิกช่องลูก ต้องลดจากช่องหลักแทน
		inv_slot = inv_slot.get_owning_slot()
		inv_index = inventory.slots.find(inv_slot)
		
	inv_slot.amount -= 1
	if inv_slot.amount <= 0:
		inventory._set_occupied(inv_index, inv_slot.item, true)
		inv_slot.item = null
		inv_slot.runtime_data.clear()
	
	_apply_equip_stats(item, true)
	equipment_changed.emit()
	inventory.inventory_changed.emit()
	return old_item

# ถอดของจาก Equipment slot -> กลับ Inventory
func unequip_to_inventory(inventory: InventoryComponent, slot: EquipSlot) -> bool:
	var eq_slot = equip_slots[slot]
	var item = eq_slot.item
	if not item:
		return false
	
	# ค้นหาช่องว่างใน Inventory เพื่อเอาอุปกรณ์ไปใส่
	var target_index = -1
	for i in range(inventory.slots.size()):
		if inventory.can_place_item_at(item, i):
			target_index = i
			break
			
	if target_index == -1:
		push_error("unequip_to_inventory: กระเป๋าเต็ม หรือไม่มีที่ว่างพอ")
		return false
	
	var target_slot = inventory.slots[target_index]
	inventory._set_occupied(target_index, item, false)
	
	# ย้ายไอเทมไปยังช่องว่าง
	target_slot.item = item
	target_slot.amount = 1
	target_slot.runtime_data = eq_slot.runtime_data.duplicate(true)
	
	_apply_equip_stats(item, false)
	eq_slot.item = null
	eq_slot.amount = 0
	eq_slot.runtime_data.clear()
	
	inventory.inventory_changed.emit()
	equipment_changed.emit()
	return true

# ใช้ durability (เรียกตอนโจมตี/โดนตี/ใช้เครื่องมือ)
func use_durability(slot: EquipSlot, amount: float = 1.0) -> bool:
	var eq_slot = equip_slots[slot]
	if not eq_slot.runtime_data.has("durability"):
		return false
	
	eq_slot.runtime_data["durability"] -= amount
	if eq_slot.runtime_data["durability"] <= 0:
		eq_slot.runtime_data["durability"] = 0
		equipment_changed.emit() # สามารถเพิ่ม event broken ได้
		return true # แตกแล้ว
	return false

# ใช้เครื่องมือ (ToolModule) - คืน tool_power
func use_tool(slot: EquipSlot, tool_type: ToolModule.ToolType) -> int:
	var item = equip_slots[slot].item
	if not item:
		return 0
	var tool_module = item.get_module(ToolModule) as ToolModule
	if not tool_module or tool_module.tool_type != tool_type:
		return 0
	
	# ใช้ durability
	use_durability(slot, 1.0)
	return tool_module.tool_power

# ดึง weapon damage
func get_weapon_damage() -> float:
	var item = equip_slots[EquipSlot.MAIN_HAND].item
	if item:
		var weapon = item.get_module(WeaponModule) as WeaponModule
		if weapon:
			return weapon.physical_damage
	return 0.0

# ดึง attack speed
func get_attack_speed() -> float:
	var item = equip_slots[EquipSlot.MAIN_HAND].item
	if item:
		var weapon = item.get_module(WeaponModule) as WeaponModule
		if weapon:
			return weapon.attack_speed
	return 1.0

# ดึง defense
func get_physical_defense() -> float:
	var total = 0.0
	for slot in EquipSlot.values():
		var item = equip_slots[slot].item
		if item:
			var armor = item.get_module(ArmorModule) as ArmorModule
			if armor:
				total += armor.physical_defense
	return total

func get_magic_resistance() -> float:
	var total = 0.0
	for slot in EquipSlot.values():
		var item = equip_slots[slot].item
		if item:
			var armor = item.get_module(ArmorModule) as ArmorModule
			if armor:
				total += armor.magic_resistance
	return total

# เรียกตอนสวม/ถอด เพื่ออัปเดต total_stats
func _apply_equip_stats(item: ItemData, adding: bool):
	var sign = 1.0 if adding else -1.0
	
	var weapon = item.get_module(WeaponModule) as WeaponModule
	if weapon:
		total_stats["physical_damage"] += weapon.physical_damage * sign
		total_stats["attack_speed"] += (weapon.attack_speed - 1.0) * sign
	
	var armor = item.get_module(ArmorModule) as ArmorModule
	if armor:
		total_stats["physical_defense"] += armor.physical_defense * sign
		total_stats["magic_resistance"] += armor.magic_resistance * sign
	
	# durability stats
	for slot in EquipSlot.values():
		if equip_slots[slot].item == item:
			if equip_slots[slot].runtime_data.has("durability"):
				total_stats["durability"] = equip_slots[slot].runtime_data["durability"]
			break
	
	equipment_changed.emit()

func get_total_stats() -> Dictionary:
	return total_stats.duplicate(true)

func get_equipped(slot: EquipSlot) -> ItemData:
	return equip_slots[slot].item

func is_slot_empty(slot: EquipSlot) -> bool:
	return equip_slots[slot].item == null

func get_equipped_slot_data(slot: EquipSlot) -> Dictionary:
	return equip_slots[slot].runtime_data

func set_equipped_slot_data(slot: EquipSlot, data: Dictionary):
	equip_slots[slot].runtime_data = data

# --- SERIALIZATION (SAVE / LOAD) ---

const REGISTRY_PATH = "res://addons/universal_inventory/item_database_registry.tres"
var _registry: ItemDatabaseRegistry = null

func get_registry() -> ItemDatabaseRegistry:
	if _registry == null:
		if ResourceLoader.exists(REGISTRY_PATH):
			_registry = load(REGISTRY_PATH)
		else:
			_registry = ItemDatabaseRegistry.new()
	return _registry

# Serializes equipped items and slot data
func serialize() -> Dictionary:
	var serialized_equipped = {}
	var serialized_slot_data = {}
	
	for slot in equip_slots.keys():
		var eq_slot = equip_slots[slot]
		if eq_slot.item:
			serialized_equipped[int(slot)] = String(eq_slot.item.item_id)
		else:
			serialized_equipped[int(slot)] = ""
			
		serialized_slot_data[int(slot)] = eq_slot.runtime_data.duplicate(true)
		
	return {
		"equipped": serialized_equipped,
		"equipped_slot_data": serialized_slot_data
	}

# Restores equipped items and slot data from serialized Dictionary
func deserialize(data: Dictionary) -> void:
	var reg = get_registry()
	
	# Clear current stats
	total_stats = {
		"physical_damage": 0.0,
		"attack_speed": 1.0,
		"physical_defense": 0.0,
		"magic_resistance": 0.0,
		"durability": 0.0
	}
	
	var serialized_equipped = data.get("equipped", {})
	var serialized_slot_data = data.get("equipped_slot_data", {})
	
	for slot_str in serialized_equipped.keys():
		var slot = int(slot_str) as EquipSlot
		var item_id = StringName(serialized_equipped[slot_str])
		var item = reg.get_item(item_id)
		
		var eq_slot = equip_slots[slot]
		eq_slot.item = item
		eq_slot.amount = 1 if item else 0
		eq_slot.runtime_data = serialized_slot_data.get(slot_str, {}).duplicate(true)
		
		if item:
			_apply_equip_stats(item, true)
			
	equipment_changed.emit()
