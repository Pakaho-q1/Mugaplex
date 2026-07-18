extends Node
class_name InventoryGridConstraint

## (Optional) The number of columns in the grid.
@export var grid_columns: int = 1

var _inventory: InventoryComponent

func _ready():
	_inventory = get_parent() as InventoryComponent
	if not _inventory:
		push_warning("InventoryGridConstraint must be a child of InventoryComponent")

func get_grid_dimensions() -> Vector2i:
	if not _inventory: return Vector2i.ONE
	return Vector2i(grid_columns, _inventory.max_slots / grid_columns)

func get_grid_columns() -> int:
	return grid_columns

func can_add_item(inventory: InventoryComponent, item_data: ItemData, top_left_index: int = -1, ignore_indices: Array[int] = []) -> bool:
	if item_data == null: return false
	if top_left_index == -1: return false # For grid, we usually need an exact index.
	
	# We need to know if it's rotated. This requires runtime_data, but our interface passes item_data.
	# For simplicity in this basic constraint, we assume not rotated, 
	# OR we get rotation from runtime_data if we have it in ignore_indices? No, rotation is an issue.
	# We can just check the item dimensions directly.
	var is_rotated = false # In a more complex system, we'd pass rotation to this constraint
	
	var grid_w = grid_columns
	var grid_h = inventory.max_slots / grid_columns
	
	var item_w = item_data.grid_size.y if is_rotated else item_data.grid_size.x
	var item_h = item_data.grid_size.x if is_rotated else item_data.grid_size.y
	
	var start_x = top_left_index % grid_w
	var start_y = top_left_index / grid_w
	
	if start_x + item_w > grid_w or start_y + item_h > grid_h:
		return false
		
	# Check overlaps using the 1D slots array
	for y in range(item_h):
		for x in range(item_w):
			var idx = (start_y + y) * grid_w + (start_x + x)
			if idx >= inventory.slots.size(): return false
			
			if idx in ignore_indices:
				continue
				
			# Check if there is an item here in the 1D array
			var slot = inventory.slots[idx]
			if slot.item != null:
				return false
				
			# Check if this cell is occupied by ANOTHER item's multi-cell footprint
			if _is_cell_occupied_by_other(inventory, idx, ignore_indices):
				return false
				
	return true

# Helper to check if a specific cell index is covered by any existing item in the inventory
func _is_cell_occupied_by_other(inventory: InventoryComponent, target_idx: int, ignore_indices: Array[int]) -> bool:
	var target_x = target_idx % grid_columns
	var target_y = target_idx / grid_columns
	
	for i in range(inventory.slots.size()):
		if i in ignore_indices: continue
		var slot = inventory.slots[i]
		if slot.item != null:
			var item = slot.item
			var is_rot = slot.runtime_data.get("rotated", false)
			var item_w = item.grid_size.y if is_rot else item.grid_size.x
			var item_h = item.grid_size.x if is_rot else item.grid_size.y
			
			var start_x = i % grid_columns
			var start_y = i / grid_columns
			
			# Check AABB intersection
			if target_x >= start_x and target_x < start_x + item_w:
				if target_y >= start_y and target_y < start_y + item_h:
					return true
					
	return false

# UI Helper: Get all overlapping items at a specific drop location
func get_overlapping_items(inventory: InventoryComponent, item_data: ItemData, top_left_index: int, is_rotated: bool = false) -> Array[InventorySlot]:
	var overlaps: Array[InventorySlot] = []
	if item_data == null: return overlaps
	
	var grid_w = grid_columns
	var grid_h = inventory.max_slots / grid_columns
	var item_w = item_data.grid_size.y if is_rotated else item_data.grid_size.x
	var item_h = item_data.grid_size.x if is_rotated else item_data.grid_size.y
	var start_x = top_left_index % grid_w
	var start_y = top_left_index / grid_w
	if start_x + item_w > grid_w or start_y + item_h > grid_h:
		return overlaps
		
	# Find which existing items occupy the target cells
	for y in range(item_h):
		for x in range(item_w):
			var idx = (start_y + y) * grid_w + (start_x + x)
			if idx >= inventory.slots.size(): continue
			
			var target_x = idx % grid_w
			var target_y = idx / grid_w
			
			# Scan inventory for who owns this cell
			for i in range(inventory.slots.size()):
				var slot = inventory.slots[i]
				if slot.item != null:
					var slot_rot = slot.runtime_data.get("rotated", false)
					var slot_w = slot.item.grid_size.y if slot_rot else slot.item.grid_size.x
					var slot_h = slot.item.grid_size.x if slot_rot else slot.item.grid_size.y
					var slot_sx = i % grid_w
					var slot_sy = i / grid_w
					
					if target_x >= slot_sx and target_x < slot_sx + slot_w:
						if target_y >= slot_sy and target_y < slot_sy + slot_h:
							if not overlaps.has(slot):
								overlaps.append(slot)
	return overlaps

func get_owning_slot_index(inventory: InventoryComponent, target_idx: int) -> int:
	var target_x = target_idx % grid_columns
	var target_y = target_idx / grid_columns
	for i in range(inventory.slots.size()):
		var slot = inventory.slots[i]
		if slot.item != null:
			var is_rot = slot.runtime_data.get("rotated", false)
			var item_w = slot.item.grid_size.y if is_rot else slot.item.grid_size.x
			var item_h = slot.item.grid_size.x if is_rot else slot.item.grid_size.y
			var start_x = i % grid_columns
			var start_y = i / grid_columns
			if target_x >= start_x and target_x < start_x + item_w:
				if target_y >= start_y and target_y < start_y + item_h:
					return i
	return -1
