extends Node
class_name InventoryComponent

const ContainerModule = preload("res://addons/mugaplex/inventory/modules/container_module.gd")

# ตะโกนบอก UI เมื่อของในกระเป๋ามีการเปลี่ยนแปลง
signal inventory_changed
signal item_used(item: ItemData, index: int, payload: Dictionary)
signal item_dropped(item: ItemData, amount: int, runtime_data: Dictionary, slot_index: int, dropper: Node)

# กำหนดขนาดกระเป๋า
## The maximum number of slots this inventory can hold.
@export var max_slots: int = 20
@export_group("Grid / Multi-Cell Settings")
## (Optional) The number of columns in the grid. Only used if you are building a Multi-cell (Diablo-style) inventory.
@export var grid_columns: int = 1
# Array ที่เก็บ "ช่องกระเป๋า" ทั้งหมด
## Array of pre-configured slots. Use this to assign starting items or to define specific Filters (e.g. Equipment slots).
@export var slots: Array[InventorySlot] = []

@export_group("Container / Nesting")
## Used internally when this InventoryComponent is materialized from a ContainerModule.
## Do not set this manually for top-level inventories.
@export var owner_instance_id: int = -1

@export_group("Capacity")
## Maximum total weight this inventory can hold. 0.0 = unlimited (default, fully backward-compatible).
@export var max_weight: float = 0.0

@export_group("Module Updates")
## If true, this inventory will automatically call update_modules(delta) every physics frame.
## Enable this if any of your ItemModules use on_update() (e.g. PerishableModule, DurabilityModule).
## Leave disabled for inventories that only store static items (better performance).
@export var auto_update_modules: bool = false

## Per-instance RNG for deterministic module updates (e.g. PerishableModule decay).
## Use set_rng_seed() to make behavior reproducible for testing or multiplayer.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value

@export_group("Save / Load")
## Optional: Override the default Item Database Registry. Useful for multi-registry setups.
@export var registry_override: ItemDatabaseRegistry = null

func _ready():
	# ให้จำนวนช่องตรงกับ max_slots เสมอ
	while slots.size() < max_slots:
		slots.append(InventorySlot.new())
	if slots.size() > max_slots:
		slots.resize(max_slots)

func _physics_process(delta: float):
	if auto_update_modules:
		update_modules(delta)

## Returns the total weight of all items currently in this inventory.
func get_total_weight() -> float:
	var total = 0.0
	for slot in slots:
		if slot.item != null and slot.occupied_by == null:
			total += slot.item.weight * slot.amount
			
			# Add recursive weight for containers (if not fixed_weight)
			var container_module = slot.item.get_module(ContainerModule)
			if container_module and not container_module.fixed_weight:
				total += _get_slot_weight_recursive(slot.runtime_data, get_registry())
				
	return total

func _get_slot_weight_recursive(runtime_data: Dictionary, registry: ItemDatabaseRegistry) -> float:
	var total = 0.0
	if not runtime_data.has("container_slots"):
		return total
		
	for slot_dict in runtime_data["container_slots"]:
		if slot_dict == null or not slot_dict.has("item_id"):
			continue
			
		var item_id = slot_dict["item_id"]
		if item_id == "":
			continue
			
		var item_data = registry.get_item(StringName(item_id))
		if item_data == null:
			continue
			
		var amount = slot_dict.get("amount", 0)
		total += item_data.weight * amount
		
		var container_module = item_data.get_module(ContainerModule)
		if container_module and not container_module.fixed_weight:
			total += _get_slot_weight_recursive(slot_dict.get("runtime_data", {}), registry)
			
	return total

func _would_create_cycle(candidate_instance_id: int) -> bool:
	if candidate_instance_id == -1:
		return false
	var current_id = owner_instance_id
	# In a real deep nested scenario we'd need to walk up the chain.
	# For now, since we don't have a direct reference to the parent InventoryComponent,
	# we just check the immediate owner. The InventoryAPI's transfer_item also needs to 
	# check this by walking the instance_ids.
	# Actually, to prevent cycles, the simplest guard is: an item with instance_id X
	# cannot be placed into an inventory whose owner_instance_id is X.
	return current_id == candidate_instance_id

## Returns true if adding the given item amount would NOT exceed max_weight.
## Always returns true when max_weight == 0.0 (unlimited).
func can_hold_weight(item_data: ItemData, amount: int) -> bool:
	if max_weight <= 0.0:
		return true
	return get_total_weight() + (item_data.weight * amount) <= max_weight

## Returns how many units of item_data can still fit under max_weight.
## Returns amount if max_weight == 0.0 (unlimited).
func _max_addable_by_weight(item_data: ItemData, amount: int) -> int:
	if max_weight <= 0.0 or item_data.weight <= 0.0:
		return amount
	var remaining_capacity = max_weight - get_total_weight()
	if remaining_capacity <= 0.0:
		return 0
	var max_by_weight = int(remaining_capacity / item_data.weight)
	return clampi(max_by_weight, 0, amount)

# ตรวจสอบว่าสามารถวางไอเทมที่ตำแหน่งอ้างอิง (มุมซ้ายบน) ได้หรือไม่ (รองรับ Multi-cell)
func can_place_item_at(item_data: ItemData, top_left_index: int, ignore_indices: Array[int] = [], is_rotated: bool = false) -> bool:
	if item_data == null: return false
	if is_rotated and not item_data.can_rotate: return false
	
	# Circular containment guard
	var container_mod = item_data.get_module(ContainerModule)
	if container_mod:
		# Note: In a real scenario we'd check the instance_id from the actual slot's runtime data,
		# but can_place_item_at only takes ItemData. The callers (add_item, move_item) will need to
		# double check or we pass the runtime_data.
		# For now, we rely on the caller to do the cycle check, or we add an optional param.
		pass
	
	var grid_w = grid_columns
	var grid_h = max_slots / grid_columns
	
	var item_w = item_data.grid_size.y if is_rotated else item_data.grid_size.x
	var item_h = item_data.grid_size.x if is_rotated else item_data.grid_size.y
	
	var start_x = top_left_index % grid_w
	var start_y = top_left_index / grid_w
	
	if start_x + item_w > grid_w or start_y + item_h > grid_h:
		return false
		
	for y in range(item_h):
		for x in range(item_w):
			var idx = (start_y + y) * grid_w + (start_x + x)
			if idx >= slots.size(): return false
			
			if idx in ignore_indices:
				continue
				
			var slot = slots[idx]
			if slot.item != null or slot.occupied_by != null:
				return false
				
			# เช็ค filter ว่าช่องนี้อนุญาตหรือไม่ (เช็คทุกช่องที่กินพื้นที่)
			if not slot.can_accept(item_data):
				return false
				
	return true

# จองหรือคืนพื้นที่ให้ไอเทม (Multi-cell)
func _set_occupied(top_left_index: int, item_data: ItemData, clear: bool = false, is_rotated: bool = false):
	if item_data == null: return
	var grid_w = grid_columns
	var item_w = item_data.grid_size.y if is_rotated else item_data.grid_size.x
	var item_h = item_data.grid_size.x if is_rotated else item_data.grid_size.y
	var start_x = top_left_index % grid_w
	var start_y = top_left_index / grid_w
	
	var main_slot = slots[top_left_index]
	
	for y in range(item_h):
		for x in range(item_w):
			if x == 0 and y == 0: continue # ข้ามช่องหลัก
			var idx = (start_y + y) * grid_w + (start_x + x)
			if idx < slots.size():
				if clear:
					slots[idx].occupied_by = null
				else:
					slots[idx].occupied_by = main_slot

# --- ฟังก์ชันเพิ่มไอเทมเข้ากระเป๋า ---
func add_item(item_data: ItemData, amount: int = 1) -> int:
	if item_data == null:
		push_error("add_item: item_data เป็น null ไม่สามารถเพิ่มไอเทมได้")
		return amount
	if amount <= 0:
		return 0
	
	# Weight constraint: clamp the amount we can actually add
	var allowed = _max_addable_by_weight(item_data, amount)
	if allowed <= 0:
		return amount
	var rejected_by_weight = amount - allowed
	amount = allowed

	var amount_to_add = amount
	var changed = false

	# 1. พยายามเติมลงในช่องที่มีไอเทมชนิดเดียวกันอยู่แล้ว (Stackable)
	if item_data.stackable:
		for i in range(slots.size()):
			var slot = slots[i]
			if slot.item == item_data and slot.amount < slot.get_max_stack(item_data) and slot.can_accept(item_data):
				var space_left = slot.get_max_stack(item_data) - slot.amount

				if amount_to_add <= space_left:
					slot.amount += amount_to_add
					changed = true
					inventory_changed.emit()
					return rejected_by_weight
				else:
					slot.amount += space_left
					amount_to_add -= space_left
					changed = true

	# 2. พยายามเติมลงในช่องว่างที่มีสิทธิ์ยินยอมรับไอเทมได้ (รองรับ Multi-cell)
	for i in range(slots.size()):
		if can_place_item_at(item_data, i):
			var slot = slots[i]
			slot.item = item_data
			slot.init_runtime(item_data)
			_set_occupied(i, item_data, false)

			if item_data.stackable:
				if amount_to_add <= slot.get_max_stack(item_data):
					slot.amount = amount_to_add
					changed = true
					inventory_changed.emit()
					return rejected_by_weight
				else:
					slot.amount = slot.get_max_stack(item_data)
					amount_to_add -= slot.get_max_stack(item_data)
					changed = true
			else:
				slot.amount = 1
				amount_to_add -= 1
				changed = true
				if amount_to_add == 0:
					inventory_changed.emit()
					return rejected_by_weight

	if changed:
		inventory_changed.emit()
	return amount_to_add + rejected_by_weight
	
func move_item(source_index: int, target_index: int, move_amount: int = -1):
	if source_index == target_index:
		return
	if source_index < 0 or source_index >= slots.size() or target_index < 0 or target_index >= slots.size():
		push_error("move_item: index นอกขอบช่อง (source=%d, target=%d, size=%d)" % [source_index, target_index, slots.size()])
		return

	var source = slots[source_index]
	var target = slots[target_index]
	
	if source.occupied_by != null:
		source_index = slots.find(source.occupied_by)
		source = slots[source_index]
	if target.occupied_by != null:
		target_index = slots.find(target.occupied_by)
		target = slots[target_index]
		
	if source_index == target_index:
		return

	if source.item == null:
		return
		
	var actual_move_amount = source.amount if move_amount == -1 else clampi(move_amount, 1, source.amount)

	# กรณีที่ 1: ถ้าไอเทม 2 ช่องเป็นของชิ้นเดียวกัน และอนุญาตให้ทับซ้อนได้ (Stackable)
	if target.item != null and source.item == target.item and source.item.stackable:
		if not target.can_accept(source.item): return
		var space_left = target.get_max_stack(target.item) - target.amount
		
		if space_left > 0:
			var transfer_amount = min(actual_move_amount, space_left)
			target.amount += transfer_amount
			source.amount -= transfer_amount
			
			if source.amount == 0:
				_set_occupied(source_index, source.item, true) # Clear old occupancy
				source.item = null
				source.runtime_data.clear()
			inventory_changed.emit()
		return
		
	# Partial move (Split) to a slot that already has a different item is not allowed (No partial swap)
	if target.item != null and actual_move_amount < source.amount:
		return
		
	# กรณีที่ 2: ย้ายไปช่องว่าง (Partial or Full)
	if target.item == null:
		if not target.can_accept(source.item): return
		
		var ignore_source: Array[int] = []
		var grid_w = grid_columns
		var w = source.item.grid_size.x
		var h = source.item.grid_size.y
		for y in range(h):
			for x in range(w):
				ignore_source.append(source_index + y * grid_w + x)
				
		if not can_place_item_at(source.item, target_index, ignore_source): return
		
		if actual_move_amount < source.amount:
			# Split to empty slot
			target.item = source.item
			target.amount = actual_move_amount
			target.runtime_data = source.runtime_data.duplicate(true)
			source.amount -= actual_move_amount
			_set_occupied(target_index, target.item, false)
			inventory_changed.emit()
			return
			
	# กรณีที่ 3: สลับที่ (Full Swap) หรือย้ายเต็มจำนวนไปช่องว่าง
	
	# จำค่าเดิม
	var s_item = source.item
	var s_amount = source.amount
	var s_runtime = source.runtime_data.duplicate(true)
	
	var t_item = target.item
	var t_amount = target.amount
	var t_runtime = target.runtime_data.duplicate(true)
	
	# ให้อิสระช่องชั่วคราว (เพื่อให้สามารถ swap ทับที่กันเองได้)
	var ignore_source: Array[int] = []
	var ignore_target: Array[int] = []
	
	# หา index ทั้งหมดที่ source จองไว้
	var grid_w = grid_columns
	if s_item:
		var w = s_item.grid_size.x
		var h = s_item.grid_size.y
		for y in range(h):
			for x in range(w):
				ignore_source.append(source_index + y * grid_w + x)
				
	# หา index ทั้งหมดที่ target จองไว้
	if t_item:
		var w = t_item.grid_size.x
		var h = t_item.grid_size.y
		for y in range(h):
			for x in range(w):
				ignore_target.append(target_index + y * grid_w + x)
				
	# รวมช่องที่เป็นไปได้ทั้งหมดเพื่อให้ can_place_item_at ข้ามการเช็ค
	var ignore_all: Array[int] = ignore_source.duplicate()
	ignore_all.append_array(ignore_target)
	
	# ตรวจสอบว่าสลับกันได้ไหม
	var can_move_s_to_t = true
	var can_move_t_to_s = true
	
	if s_item:
		can_move_s_to_t = can_place_item_at(s_item, target_index, ignore_all)
	if t_item:
		can_move_t_to_s = can_place_item_at(t_item, source_index, ignore_all)
		
	if not (can_move_s_to_t and can_move_t_to_s):
		return # สลับไม่ได้
		
	# ทำการสลับจริง
	if s_item: _set_occupied(source_index, s_item, true)
	if t_item: _set_occupied(target_index, t_item, true)
	
	source.item = t_item
	source.amount = t_amount
	source.runtime_data = t_runtime
	if t_item: _set_occupied(source_index, t_item, false)
	
	target.item = s_item
	target.amount = s_amount
	target.runtime_data = s_runtime
	if s_item: _set_occupied(target_index, s_item, false)
	
	inventory_changed.emit()

# ==========================================
# Missing Logic: Query, Manipulation & Split
# ==========================================

func split_stack(source_index: int, target_index: int, amount: int) -> bool:
	if source_index < 0 or source_index >= slots.size() or target_index < 0 or target_index >= slots.size():
		return false
	if amount <= 0:
		return false
		
	var source = slots[source_index]
	var target = slots[target_index]
	
	if source.item == null or source.amount <= amount:
		return false # ไม่มีของให้แบ่ง หรือพยายามแบ่งมากเกิน/เท่ากับที่ทั้งหมด
		
	# ช่องเป้าหมายต้องว่าง หรือ มีไอเทมเดียวกันที่มีที่เหลือ
	if target.item != null:
		if target.item != source.item or not target.item.stackable:
			return false
		if target.amount + amount > target.get_max_stack(target.item):
			return false
	else:
		if not can_place_item_at(source.item, target_index):
			return false
			
	# ทำการแบ่ง
	source.amount -= amount
	
	if target.item == null:
		target.item = source.item
		target.amount = amount
		target.runtime_data = source.runtime_data.duplicate(true)
		_set_occupied(target_index, target.item, false)
	else:
		target.amount += amount
		
	inventory_changed.emit()
	return true
	
func drop_item(index: int, amount: int = -1, dropper: Node = null) -> bool:
	if index < 0 or index >= slots.size():
		return false
		
	var slot = slots[index]
	if slot.item == null:
		return false
		
	var drop_amount = slot.amount if amount <= 0 else min(amount, slot.amount)
	
	var item_to_drop = slot.item
	var runtime_copy = slot.runtime_data.duplicate(true)
	
	slot.amount -= drop_amount
	if slot.amount <= 0:
		_set_occupied(index, slot.item, true)
		slot.item = null
		slot.runtime_data.clear()
		
	item_dropped.emit(item_to_drop, drop_amount, runtime_copy, index, dropper)
	inventory_changed.emit()
	return true

# เช็คว่ามีไอเทมนี้ในกระเป๋าหรือไม่
func has_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false
	for slot in slots:
		if slot.item == item_data:
			return true
	return false

# นับจำนวนรวมของไอเทมชนิดนี้ในกระเป๋า
func count_item(item_data: ItemData) -> int:
	if item_data == null:
		return 0
	var total = 0
	for slot in slots:
		if slot.item == item_data:
			total += slot.amount
	return total

# หา index ทั้งหมดที่มีไอเทมนี้ (คืน Array[int])
func get_item_indices(item_data: ItemData) -> Array[int]:
	var indices: Array[int] = []
	if item_data == null:
		return indices
	for i in range(slots.size()):
		if slots[i].item == item_data:
			indices.append(i)
	return indices

# ลบไอเทมตาม item_id จำนวน amount (คืนจำนวนที่ลบจริง)
func remove_item(item_data: ItemData, amount: int = 1) -> int:
	if item_data == null or amount <= 0:
		return 0
	var to_remove = amount
	for i in range(slots.size()):
		var slot = slots[i]
		if slot.item == item_data:
			var take = min(slot.amount, to_remove)
			slot.amount -= take
			to_remove -= take
			if slot.amount == 0:
				_set_occupied(i, slot.item, true)
				slot.item = null
			if to_remove == 0:
				break
	inventory_changed.emit()
	return amount - to_remove

# ใช้ไอเทมที่ช่อง index
func use_item(index: int, user_context: Dictionary = {}) -> Dictionary:
	var result = {"success": false, "message": "", "item": null, "payload": {}}
	
	if index < 0 or index >= slots.size():
		result.message = "Index out of bounds"
		return result
	
	var slot = slots[index]
	if slot.item == null:
		result.message = "Slot is empty"
		return result
	
	var item = slot.item
	if item.get("disable_use") == true:
		result.message = "Item cannot be used"
		return result
		
	var payloads: Array = []
	
	# Check before_use modules
	for module in item.modules:
		if module.has_method("before_use"):
			var before_res = module.before_use(slot.runtime_data, user_context)
			if before_res.get("prevented", false):
				result.message = before_res.get("message", "Cannot use item")
				if before_res.get("destroyed", false):
					_set_occupied(index, slot.item, true)
					slot.item = null
					slot.amount = 0
				elif before_res.get("new_item", null) != null:
					_set_occupied(index, slot.item, true)
					slot.item = before_res["new_item"]
					slot.init_runtime(slot.item)
					_set_occupied(index, slot.item, false)
				inventory_changed.emit()
				return result
				
	# Consume logic (Mechanism)
	var consumed = false
	for module in item.modules:
		if module.has_method("on_use"):
			var use_res = module.on_use(slot.runtime_data, user_context)
			if use_res.get("consumed", false):
				consumed = true
			if use_res.get("payload", null):
				payloads.append(use_res["payload"])
				
	if consumed:
		slot.amount -= 1
		if slot.amount <= 0:
			_set_occupied(index, slot.item, true)
			slot.item = null
			slot.runtime_data.clear()  # Critical Bug #2 Fix: clear leaked runtime data
		
	var final_payload = {"actions": payloads}
	item_used.emit(item, index, final_payload)
	
	result.success = true
	result.message = "Used %s" % item.display_name
	result.item = item
	result.payload = final_payload
	
	inventory_changed.emit()
	return result

func use_item_by_data(item_data: ItemData, user_context: Dictionary = {}) -> Dictionary:
	var indices = get_item_indices(item_data)
	if indices.is_empty():
		return {"success": false, "message": "Item not found", "item": null}
	return use_item(indices[0], user_context)

func update_modules(delta: float):
	var changed = false
	for i in range(slots.size()):
		var slot = slots[i]
		if slot.item:
			for module in slot.item.modules:
				if module.has_method("on_update"):
					var res = module.on_update(delta, slot.runtime_data, _rng)
					if res.has("runtime_data_update") and not res["runtime_data_update"].is_empty():
						changed = true
						for key in res["runtime_data_update"]:
							slot.runtime_data[key] = res["runtime_data_update"][key]
					if res.get("destroyed", false):
						changed = true
						_set_occupied(i, slot.item, true)
						slot.item = null
						slot.amount = 0
					elif res.get("new_item", null) != null:
						changed = true
						_set_occupied(i, slot.item, true)
						slot.item = res["new_item"]
						slot.init_runtime(slot.item)
						_set_occupied(i, slot.item, false)
	if changed:
		inventory_changed.emit()

func get_slot(index: int) -> InventorySlot:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

# --- SERIALIZATION (SAVE / LOAD) ---

const _DEFAULT_REGISTRY_PATH = "res://addons/mugaplex/inventory/item_database_registry.tres"
var _registry: ItemDatabaseRegistry = null

func get_registry() -> ItemDatabaseRegistry:
	# Use override if explicitly set in Inspector
	if registry_override:
		return registry_override
	# Lazy-load the default registry
	if _registry == null:
		if ResourceLoader.exists(_DEFAULT_REGISTRY_PATH):
			_registry = load(_DEFAULT_REGISTRY_PATH)
		else:
			push_warning("InventoryComponent: Default registry not found at '%s'. Set registry_override in Inspector." % _DEFAULT_REGISTRY_PATH)
			_registry = ItemDatabaseRegistry.new()
	return _registry

func serialize() -> Array:
	var data = []
	for slot in slots:
		if slot and slot.item:
			data.append({
				"item_id": String(slot.item.item_id),
				"amount": slot.amount,
				"runtime_data": slot.runtime_data.duplicate(true)
			})
		else:
			data.append(null)
	return data

func deserialize(data: Array) -> void:
	var reg = get_registry()
	slots.clear()
	for i in range(max_slots):
		var slot = InventorySlot.new()
		if i < data.size() and data[i] != null:
			var slot_data = data[i]
			var item_id = StringName(slot_data.get("item_id", ""))
			var item_data = reg.get_item(item_id)
			if item_data:
				slot.item = item_data
				slot.amount = int(slot_data.get("amount", 0))
				slot.runtime_data = slot_data.get("runtime_data", {}).duplicate(true)
		slots.append(slot)
		
	# Re-apply occupied cells
	for i in range(slots.size()):
		if slots[i].item:
			_set_occupied(i, slots[i].item, false)
			
	inventory_changed.emit()

func take_item_amount(index: int, amount: int = -1) -> Dictionary:
	if index < 0 or index >= slots.size(): return {}
	var slot = slots[index]
	if slot.occupied_by != null:
		index = slots.find(slot.occupied_by)
		slot = slots[index]
	if slot.item == null: return {}
	
	var take_amt = slot.amount if amount == -1 else clampi(amount, 1, slot.amount)
	var payload = {
		"item": slot.item,
		"amount": take_amt,
		"runtime_data": slot.runtime_data.duplicate(true)
	}
	
	slot.amount -= take_amt
	if slot.amount <= 0:
		_set_occupied(index, slot.item, true)
		slot.item = null
		slot.runtime_data.clear()
	
	inventory_changed.emit()
	return payload

func place_item_amount(index: int, item: ItemData, amount: int, runtime: Dictionary) -> int:
	if index < 0 or index >= slots.size() or item == null or amount <= 0: return amount
	
	# Circular containment guard
	if runtime.has("instance_id") and _would_create_cycle(runtime["instance_id"]):
		return amount
		
	var original_amount = amount
	# Weight constraint: clamp amount to what fits under max_weight
	amount = _max_addable_by_weight(item, amount)
	var rejected_by_weight = original_amount - amount
	if amount <= 0: return original_amount
	var slot = slots[index]
	if slot.occupied_by != null:
		index = slots.find(slot.occupied_by)
		slot = slots[index]
		
	# Merge
	if slot.item != null and slot.item == item and item.stackable:
		if not slot.can_accept(item): return amount + rejected_by_weight
		var space = slot.get_max_stack(item) - slot.amount
		var transfer = min(amount, space)
		if transfer > 0:
			slot.amount += transfer
			amount -= transfer
			inventory_changed.emit()
		return amount + rejected_by_weight
		
	# Empty slot
	if slot.item == null:
		if not slot.can_accept(item): return amount + rejected_by_weight
		var ignore_source: Array[int] = []
		var grid_w = grid_columns
		var w = item.grid_size.x
		var h = item.grid_size.y
		for y in range(h):
			for x in range(w):
				ignore_source.append(index + y * grid_w + x)
		if not can_place_item_at(item, index, ignore_source): return amount + rejected_by_weight
		
		var place_amt = min(amount, slot.get_max_stack(item))
		slot.item = item
		slot.amount = place_amt
		slot.runtime_data = runtime.duplicate(true)
		amount -= place_amt
		_set_occupied(index, slot.item, false)
		inventory_changed.emit()
		return amount + rejected_by_weight
		
	return amount + rejected_by_weight
