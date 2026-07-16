class_name InventoryAPI

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
	var owning_slot = slot.get_owning_slot()
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
	InventoryManager.item_dropped.emit(item, drop_amount, dropped_runtime_data)
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
		var slot = inventory.slots[idx].get_owning_slot()
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
			var slot = inventory.slots[idx].get_owning_slot()
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
		
	var source_slot = inventory.slots[source_idx].get_owning_slot()
	var target_slot = inventory.slots[target_idx]
	
	if not source_slot.item or source_slot.amount <= amount:
		return false # ไม่มีของ หรือของไม่พอแบ่ง
		
	if not source_slot.item.stackable:
		return false # ไอเทมแบ่งกองไม่ได้
		
	# เช็คว่าเป้าหมายว่าง หรือเป็นไอเทมเดียวกัน
	if target_slot.item != null:
		var t_owning = target_slot.get_owning_slot()
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
		var owning_slot = slot.get_owning_slot()
		
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
	for slot in inventory.slots:
		var owning_slot = slot.get_owning_slot()
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
		var owning_slot = slot.get_owning_slot()
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
static func transfer_item(source_inv: InventoryComponent, target_inv: InventoryComponent, source_idx: int, target_idx: int = -1, amount: int = -1) -> bool:
	if not source_inv or not target_inv or source_idx < 0 or source_idx >= source_inv.slots.size():
		return false
		
	var source_slot = source_inv.slots[source_idx].get_owning_slot()
	if not source_slot or not source_slot.item:
		return false
		
	var item = source_slot.item
	var transfer_amount = amount
	if transfer_amount <= 0 or transfer_amount > source_slot.amount:
		transfer_amount = source_slot.amount
		
	# ถ้าย้ายแบบไม่ระบุช่องเป้าหมาย (ให้ระบบหาให้)
	if target_idx == -1:
		var remaining_to_transfer = target_inv.add_item(item, transfer_amount)
		if remaining_to_transfer < transfer_amount:
			var actually_transferred = transfer_amount - remaining_to_transfer
			source_slot.amount -= actually_transferred
			if source_slot.amount <= 0:
				var origin_idx = source_inv.slots.find(source_slot)
				source_inv._set_occupied(origin_idx, source_slot.item, true)
				source_slot.item = null
				source_slot.amount = 0
				source_slot.runtime_data.clear()
			source_inv.inventory_changed.emit()
			return true
		return false
		
	# ถ้าย้ายแบบระบุช่องเป้าหมาย
	if target_idx < 0 or target_idx >= target_inv.slots.size():
		return false
		
	var target_slot = target_inv.slots[target_idx]
	if target_slot.item != null:
		# ถ้าเป้าหมายมีของอยู่ ต้องเป็นของชนิดเดียวกันและรวมกองได้
		var t_owning = target_slot.get_owning_slot()
		if t_owning.item != item or not item.stackable:
			return false
		var space = t_owning.get_max_stack(item) - t_owning.amount
		if space < transfer_amount:
			return false
		t_owning.amount += transfer_amount
	else:
		# ช่องว่าง เช็คพื้นที่
		if not target_inv.can_place_item_at(item, target_idx):
			return false
		target_inv._set_occupied(target_idx, item, false)
		target_slot.item = item
		target_slot.amount = transfer_amount
		target_slot.runtime_data = source_slot.runtime_data.duplicate(true)
		
	# หักจากต้นทาง
	source_slot.amount -= transfer_amount
	if source_slot.amount <= 0:
		var origin_idx = source_inv.slots.find(source_slot)
		source_inv._set_occupied(origin_idx, source_slot.item, true)
		source_slot.item = null
		source_slot.amount = 0
		source_slot.runtime_data.clear()
		
	source_inv.inventory_changed.emit()
	target_inv.inventory_changed.emit()
	return true
