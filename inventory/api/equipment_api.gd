class_name EquipmentAPI

static func equip_from_inventory(equipment: EquipmentComponent, inventory: InventoryComponent, inv_index: int, slot: EquipmentComponent.EquipSlot) -> ItemData:
	if not equipment or not inventory:
		return null
	
	# เราสามารถวางกฎ (Rules / Business Logic) ไว้ตรงนี้ได้ เช่น
	# if PlayerManager.is_in_combat(): return null # ห้ามเปลี่ยนของตอนสู้
	
	return equipment.equip_from_inventory(inventory, inv_index, slot)

static func unequip_to_inventory(equipment: EquipmentComponent, inventory: InventoryComponent, slot: EquipmentComponent.EquipSlot) -> bool:
	if not equipment or not inventory:
		return false
		
	return equipment.unequip_to_inventory(inventory, slot)
