class_name InventoryAPI

## Toggles rotation state of the item at slot_index. Returns false if rotation is
## not possible (item cannot rotate, or rotated footprint doesn't fit).
static func rotate_item(inventory: InventoryComponent, slot_index: int) -> bool:
	if not inventory or slot_index < 0 or slot_index >= inventory.slots.size():
		return false
	var slot = inventory.get_owning_slot(slot_index)
	if not slot or not slot.item:
		return false
	if not slot.item.can_rotate:
		return false
	# Only meaningful for multi-cell items
	if slot.item.grid_size.x == slot.item.grid_size.y:
		return true # Square items: rotation is a no-op but not an error
	
	var real_idx = inventory.slots.find(slot)
	var current_rotated = slot.runtime_data.get("rotated", false)
	var new_rotated = not current_rotated
	
	# Build ignore list from current footprint
	var ignore: Array[int] = []
	var grid_w = inventory.grid_columns
	var old_w = slot.item.grid_size.y if current_rotated else slot.item.grid_size.x
	var old_h = slot.item.grid_size.x if current_rotated else slot.item.grid_size.y
	var sx = real_idx % grid_w
	var sy = real_idx / grid_w
	for y in range(old_h):
		for x in range(old_w):
			ignore.append((sy + y) * grid_w + (sx + x))
	
	# Check if rotated footprint fits
	if not inventory.can_place_item_at(slot.item, real_idx, ignore, new_rotated):
		return false
	
	# Apply: clear old occupancy, set new
	inventory._set_occupied(real_idx, slot.item, true, current_rotated)
	slot.runtime_data["rotated"] = new_rotated
	inventory._set_occupied(real_idx, slot.item, false, new_rotated)
	inventory.inventory_changed.emit()
	return true

## ย้ายไอเทมจากช่องหนึ่งไปอีกช่องหนึ่ง
static func move_item(inventory: InventoryComponent, source_idx: int, target_idx: int) -> void:
	if not inventory:
		return
		
	# สามารถเพิ่มเงื่อนไข High-level ตรงนี้ได้ เช่น
	# if PlayerManager.is_stunned(): return
	
	inventory.move_item(source_idx, target_idx)

## ใช้ไอเทมในช่องที่ระบุ
static func use_item(inventory: InventoryComponent, index: int, user_context: Dictionary = {}) -> void:
	if not inventory:
		return
	inventory.use_item(index, user_context)

## ทิ้งไอเทมลงพื้น (Emit signal ให้ตัวเกมเอาไปจัดการต่อ)
static func drop_item(inventory: InventoryComponent, index: int, amount: int = -1) -> bool:
	if not inventory or index < 0 or index >= inventory.slots.size():
		return false
		
	var slot = inventory.slots[index]
	var owning_slot = inventory.get_owning_slot(index)
	if not owning_slot or not owning_slot.item:
		return false
		
	var item = owning_slot.item
	var drop_amount = amount
	
	if amount <= 0 or amount > owning_slot.amount:
		drop_amount = owning_slot.amount
		
	# หักของออกจาก Inventory (ยืมใช้ add_item แบบติดลบ หรือหักตรงๆ)
	owning_slot.amount -= drop_amount
	var dropped_runtime_data = owning_slot.runtime_data.duplicate(true)
	
	if owning_slot.amount <= 0:
		var target_idx = inventory.slots.find(owning_slot)
		inventory._set_occupied(target_idx, item, true) # ยกเลิกจอง
		owning_slot.item = null
		owning_slot.runtime_data.clear()
		
	inventory.inventory_changed.emit()
	
	# ให้เกมเอาไป spawn โมเดลที่พื้น
	# InventoryManager.item_dropped.emit(item, drop_amount, dropped_runtime_data)
	return true

## คราฟต์ไอเทมในกระเป๋า (Item Crafting)
## slot_indices: ช่องที่ผู้เล่นเลือกเป็นวัตถุดิบ (สามารถส่งช่องว่างมาได้ ระบบจะข้ามไปเอง)
## คืนค่า Dictionary: { "success": bool, "recipe": ItemRecipe, "message": String }
static func craft_items(inventory: InventoryComponent, registry: RecipeRegistry, slot_indices: Array[int]) -> Dictionary:
	var result = {"success": false, "recipe": null, "message": ""}
	
	if not inventory or not registry:
		result.message = "Missing inventory or registry"
		return result
		
	# 1. นับจำนวนไอเทมแต่ละชนิดจาก slots ที่เลือก (ข้าม null/ว่าง)
	var input_counts: Dictionary = {}
	var slot_item_map: Dictionary = {}  # item_id -> [slot_index, ...]
	
	for idx in slot_indices:
		if idx < 0 or idx >= inventory.slots.size():
			continue
		var slot = inventory.get_owning_slot(idx)
		if not slot or not slot.item:
			continue
		var id = slot.item.item_id
		input_counts[id] = input_counts.get(id, 0) + slot.amount
		if not slot_item_map.has(id):
			slot_item_map[id] = []
		slot_item_map[id].append(idx)
	
	if input_counts.is_empty():
		result.message = "No items selected"
		return result
		
	# 2. หาสูตรที่ตรง
	var recipe = registry.find_recipe(input_counts)
	if not recipe:
		result.message = "No matching recipe"
		return result
	
	result.recipe = recipe
	
	# 3. ตรวจสอบว่ามีของพอสำหรับสูตรนี้ (double-check)
	for ingredient in recipe.ingredients:
		if not ingredient or not ingredient.item:
			continue
		var id = ingredient.item.item_id
		var have = input_counts.get(id, 0)
		if have < ingredient.amount:
			result.message = "Not enough: %s (need %d, have %d)" % [ingredient.item.display_name, ingredient.amount, have]
			return result
	
	# 4. หักวัตถุดิบตามจำนวนที่สูตรระบุ (ฉลาด: หักจากหลายช่องถ้าจำเป็น)
	for ingredient in recipe.ingredients:
		if not ingredient or not ingredient.item:
			continue
		var id = ingredient.item.item_id
		var to_remove = ingredient.amount
		
		for idx in slot_item_map.get(id, []):
			if to_remove <= 0:
				break
			var slot = inventory.get_owning_slot(idx)
			if not slot or not slot.item or slot.item.item_id != id:
				continue
			var take = min(slot.amount, to_remove)
			slot.amount -= take
			to_remove -= take
			if slot.amount <= 0:
				var real_idx = inventory.slots.find(slot)
				if real_idx >= 0:
					inventory._set_occupied(real_idx, slot.item, true)
				slot.item = null
				slot.runtime_data.clear()
	
	# 5. ยัดไอเทมผลลัพธ์ลงกระเป๋า
	var remaining = inventory.add_item(recipe.result_item, recipe.result_amount)
	
	inventory.inventory_changed.emit()
	
	result.success = true
	result.message = "Crafted: %s x%d" % [recipe.result_item.display_name, recipe.result_amount - remaining]
	if remaining > 0:
		result.message += " (inventory full, %d dropped)" % remaining
	return result


## แบ่งกองไอเทม
static func split_stack(inventory: InventoryComponent, source_idx: int, target_idx: int, amount: int) -> bool:
	if not inventory:
		return false
		
	if source_idx == target_idx or amount <= 0:
		return false
		
	if source_idx < 0 or source_idx >= inventory.slots.size() or target_idx < 0 or target_idx >= inventory.slots.size():
		return false
		
	var source_slot = inventory.get_owning_slot(source_idx)
	var target_slot = inventory.slots[target_idx]
	
	if not source_slot.item or source_slot.amount <= amount:
		return false # ไม่มีของ หรือของไม่พอแบ่ง
		
	if not source_slot.item.stackable:
		return false # ไอเทมแบ่งกองไม่ได้
		
	# เช็คว่าเป้าหมายว่าง หรือเป็นไอเทมเดียวกัน
	if target_slot.item != null:
		var t_owning = inventory.get_owning_slot(target_idx)
		if t_owning.item != source_slot.item:
			return false # ไอเทมคนละประเภท
		var space_left = t_owning.get_max_stack(t_owning.item) - t_owning.amount
		if space_left < amount:
			return false # ช่องเป้าหมายรับไม่พอ
			
		t_owning.amount += amount
	else:
		# เป้าหมายว่าง เช็คพื้นที่จอง
		if not inventory.can_place_item_at(source_slot.item, target_idx):
			return false
			
		inventory._set_occupied(target_idx, source_slot.item, false)
		target_slot.item = source_slot.item
		target_slot.amount = amount
		target_slot.runtime_data = source_slot.runtime_data.duplicate(true)
		
	source_slot.amount -= amount
	inventory.inventory_changed.emit()
	return true

## เรียงไอเทมในกระเป๋าอัตโนมัติ (ชิ้นใหญ่ลงก่อน, หมวดหมู่เดียวกัน, ซ้อนไอเทมถ้าเป็นไปได้)
static func sort_inventory(inventory: InventoryComponent) -> void:
	if not inventory:
		return
		
	# 1. รวบรวมและถอดไอเทมทั้งหมดออกจากกระเป๋า
	var collected_items: Array[Dictionary] = []
	for i in range(inventory.slots.size()):
		var slot = inventory.slots[i]
		var owning_slot = inventory.get_owning_slot(i)
		
		# ถ้ามันเป็นช่องหลักและมีของ
		if owning_slot == slot and slot.item != null:
			# พยายามรวมกอง (Merge Stacks) ถ้าเป็นไปได้
			var merged = false
			if slot.item.stackable:
				for ci in collected_items:
					if ci["item"] == slot.item:
						var max_s = slot.get_max_stack(slot.item)
						if ci["amount"] < max_s:
							var space = max_s - ci["amount"]
							var transfer = min(space, slot.amount)
							ci["amount"] += transfer
							slot.amount -= transfer
							if slot.amount <= 0:
								merged = true
								break
								
			if not merged and slot.amount > 0:
				collected_items.append({
					"item": slot.item,
					"amount": slot.amount,
					"runtime_data": slot.runtime_data.duplicate(true)
				})
				
			# ล้างช่อง
			inventory._set_occupied(i, slot.item, true)
			slot.item = null
			slot.amount = 0
			slot.runtime_data.clear()
			
	# 2. เรียงลำดับ Array 
	# กฎ: พื้นที่ (Area) ใหญ่สุดมาก่อน -> จากนั้นเรียงตามหมวดหมู่ -> จากนั้นเรียงตาม ID
	collected_items.sort_custom(func(a, b):
		var area_a = a["item"].grid_size.x * a["item"].grid_size.y
		var area_b = b["item"].grid_size.x * b["item"].grid_size.y
		
		if area_a != area_b:
			return area_a > area_b # ใหญ่กว่ามาก่อน
			
		var id_a = str(a["item"].item_id)
		var id_b = str(b["item"].item_id)
		
		return id_a < id_b
	)
	
	# 3. ยัดกลับเข้าไปในกระเป๋า
	for data in collected_items:
		var item = data["item"]
		var amount = data["amount"]
		var rt = data["runtime_data"]
		
		# หาช่องว่างแรกที่ใส่ได้
		for i in range(inventory.slots.size()):
			if inventory.can_place_item_at(item, i):
				var slot = inventory.slots[i]
				slot.item = item
				slot.amount = amount
				slot.runtime_data = rt
				inventory._set_occupied(i, item, false)
				break
				
	inventory.inventory_changed.emit()

## บันทึกข้อมูล
static func save_to_file(inventory: InventoryComponent, equipment: EquipmentComponent = null, file_path: String = "user://inventory_save.json") -> Error:
	var SaveSystem = load("res://addons/mugaplex/inventory/core/inventory_save_system.gd")
	return SaveSystem.save_to_file(file_path, inventory, equipment)

## โหลดข้อมูล
static func load_from_file(inventory: InventoryComponent, equipment: EquipmentComponent = null, file_path: String = "user://inventory_save.json") -> Error:
	var SaveSystem = load("res://addons/mugaplex/inventory/core/inventory_save_system.gd")
	return SaveSystem.load_from_file(file_path, inventory, equipment)

# ==========================================
# ADVANCED FEATURES (Query & Transfer)
# ==========================================

## เพิ่มไอเทมเข้ากระเป๋า (Wrapper)
static func add_item(inventory: InventoryComponent, item: ItemData, amount: int = 1) -> Dictionary:
	if not inventory:
		return {"success": false, "message": "No inventory", "remaining": amount}
	var remaining = inventory.add_item(item, amount)
	return {"success": remaining < amount, "message": "Added", "remaining": remaining}

## เช็คว่ามีไอเทมนี้ในกระเป๋าครบตามจำนวนที่ระบุหรือไม่ (นับรวมทุกกอง)
static func has_item_amount(inventory: InventoryComponent, item: ItemData, amount: int) -> bool:
	if not inventory or not item or amount <= 0:
		return false
		
	var total = 0
	for i in range(inventory.slots.size()):
		var slot = inventory.slots[i]
		var owning_slot = inventory.get_owning_slot(i)
		if owning_slot == slot and slot.item == item:
			total += slot.amount
			if total >= amount:
				return true
				
	return total >= amount

## หักไอเทมตามจำนวนที่ระบุ (สำหรับการคราฟต์/ส่งเควสต์)
static func consume_item(inventory: InventoryComponent, item: ItemData, amount: int) -> bool:
	if not inventory or not item or amount <= 0:
		return false
		
	# 1. เช็คก่อนว่ามีของพอไหม ป้องกันการหักฟรี
	if not has_item_amount(inventory, item, amount):
		return false
		
	# 2. หักของ
	var remaining = amount
	for i in range(inventory.slots.size()):
		var slot = inventory.slots[i]
		var owning_slot = inventory.get_owning_slot(i)
		if owning_slot == slot and slot.item == item:
			if slot.amount <= remaining:
				remaining -= slot.amount
				# หักจนหมดกอง
				inventory._set_occupied(i, slot.item, true)
				slot.item = null
				slot.amount = 0
				slot.runtime_data.clear()
			else:
				# หักแค่บางส่วน
				slot.amount -= remaining
				remaining = 0
				
			if remaining <= 0:
				break
				
	inventory.inventory_changed.emit()
	return true

## ย้ายไอเทมข้ามกระเป๋า (เช่น หยิบของจากหีบสมบัติ ใส่ตัวผู้เล่น)
## Returns: leftover amount that could not be transferred (0 = fully transferred).
static func transfer_item(source_inv: InventoryComponent, target_inv: InventoryComponent, source_idx: int, target_idx: int = -1, amount: int = -1) -> int:
	if not source_inv or not target_inv or source_idx < 0 or source_idx >= source_inv.slots.size():
		return amount if amount > 0 else 0
		
	var source_slot = source_inv.get_owning_slot(source_idx)
	if not source_slot or not source_slot.item:
		return amount if amount > 0 else 0
		
	var item = source_slot.item
	var transfer_amount = amount
	if transfer_amount <= 0 or transfer_amount > source_slot.amount:
		transfer_amount = source_slot.amount
	var original_amount = transfer_amount
	
	# Circular containment guard
	if source_slot.runtime_data.has("instance_id") and target_inv._would_create_cycle(source_slot.runtime_data["instance_id"]):
		return original_amount
	
	# Weight constraint: clamp to what destination can hold
	var allowed = target_inv._max_addable_by_weight(item, transfer_amount)
	if allowed <= 0:
		return transfer_amount
	var rejected_by_weight = transfer_amount - allowed
	transfer_amount = allowed
		
	# Auto-place (no target slot specified)
	if target_idx == -1:
		var remaining = target_inv.add_item(item, transfer_amount)
		var actually_transferred = transfer_amount - remaining
		if actually_transferred > 0:
			source_slot.amount -= actually_transferred
			if source_slot.amount <= 0:
				var origin_idx = source_inv.slots.find(source_slot)
				source_inv._set_occupied(origin_idx, source_slot.item, true)
				source_slot.item = null
				source_slot.amount = 0
				source_slot.runtime_data.clear()
			source_inv.inventory_changed.emit()
		return remaining + rejected_by_weight
		
	# Targeted placement
	if target_idx < 0 or target_idx >= target_inv.slots.size():
		return transfer_amount
		
	var target_slot = target_inv.slots[target_idx]
	if target_slot.item != null:
		# Merge into existing stack
		var t_owning = target_inv.get_owning_slot(target_idx)
		if t_owning.item != item or not item.stackable:
			return transfer_amount
		var space = t_owning.get_max_stack(item) - t_owning.amount
		if space <= 0:
			return transfer_amount
		var actual = min(transfer_amount, space)
		t_owning.amount += actual
		var leftover = transfer_amount - actual
		
		# Deduct from source
		source_slot.amount -= actual
		if source_slot.amount <= 0:
			var origin_idx = source_inv.slots.find(source_slot)
			source_inv._set_occupied(origin_idx, source_slot.item, true)
			source_slot.item = null
			source_slot.amount = 0
			source_slot.runtime_data.clear()
			
		source_inv.inventory_changed.emit()
		target_inv.inventory_changed.emit()
		return leftover + rejected_by_weight
	else:
		# Empty target slot
		if not target_inv.can_place_item_at(item, target_idx):
			return transfer_amount
		target_inv._set_occupied(target_idx, item, false)
		target_slot.item = item
		target_slot.amount = transfer_amount
		target_slot.runtime_data = source_slot.runtime_data.duplicate(true)
		
	# Deduct from source
	source_slot.amount -= transfer_amount
	if source_slot.amount <= 0:
		var origin_idx = source_inv.slots.find(source_slot)
		source_inv._set_occupied(origin_idx, source_slot.item, true)
		source_slot.item = null
		source_slot.amount = 0
		source_slot.runtime_data.clear()
		
	source_inv.inventory_changed.emit()
	target_inv.inventory_changed.emit()
	return 0 + rejected_by_weight

# ==========================================
# Feature 2: Container API
# ==========================================

## Materializes an InventoryComponent from a container item's runtime_data.
## Returns the instantiated and populated InventoryComponent.
static func open_container(runtime_data: Dictionary, max_slots: int, max_weight: float = 0.0) -> InventoryComponent:
	var inv = InventoryComponent.new()
	inv.max_slots = max_slots
	inv.max_weight = max_weight
	inv.owner_instance_id = runtime_data.get("instance_id", -1)
	inv._ready() # Initialize empty slots
	
	var slots_data = runtime_data.get("container_slots", [])
	if slots_data.is_empty():
		return inv
		
	# Deserialize the contents into the inventory
	var registry = inv.get_registry()
	for i in range(min(slots_data.size(), inv.slots.size())):
		var s_data = slots_data[i]
		if s_data == null or not s_data.has("item_id"):
			continue
			
		var item_id = s_data["item_id"]
		if item_id == "": continue
		
		var item_data = registry.get_item(StringName(item_id))
		if item_data == null:
			continue
			
		var slot = inv.slots[i]
		slot.item = item_data
		slot.amount = s_data.get("amount", 1)
		slot.runtime_data = s_data.get("runtime_data", {})
		
		# Set occupancy for multi-cell items
		inv._set_occupied(i, item_data, false, slot.runtime_data.get("rotated", false))
		
	return inv

## Serializes a materialized container InventoryComponent back into its runtime_data.
## Returns the serialized container_slots array.
static func close_container(inv: InventoryComponent) -> Array:
	var slots_data = []
	for slot in inv.slots:
		# Only serialize the top-left cell of an item
		if slot.item != null and slot.occupied_by_index == -1:
			slots_data.append({
				"item_id": slot.item.item_id,
				"amount": slot.amount,
				"runtime_data": slot.runtime_data
			})
		else:
			slots_data.append(null)
			
	# Strip trailing nulls to save space
	while slots_data.size() > 0 and slots_data.back() == null:
		slots_data.pop_back()
		
	return slots_data
