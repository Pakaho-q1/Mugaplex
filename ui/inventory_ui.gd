extends Control
class_name InventoryUI

const SLOT_UI_SCENE = preload("res://addons/universal_inventory/ui/slot_ui.tscn")
const InventoryAPI = preload("res://addons/universal_inventory/api/inventory_api.gd")

## The InventoryComponent node this UI represents. If left empty, it will auto-detect the player's inventory.
@export var inventory_component: InventoryComponent
## The Node that 'owns' this inventory (usually the Player). Used for passing Context when items are used.
@export var user: Node
@export_group("Auto-Spawn (Optional)")
## If assigned, the UI will automatically spawn SlotUI children inside this container to match the InventoryComponent's max_slots.
@export var auto_spawn_container: Control
## The scene to spawn for each slot if auto_spawn_container is used.
@export var auto_spawn_template: PackedScene = SLOT_UI_SCENE
var active_slots: Array[SlotUI] = []

func _ready():
	if not inventory_component:
		inventory_component = InventoryManager.get_player()
	if inventory_component:
		setup(inventory_component)

func setup(comp: InventoryComponent):
	# Disconnect old signal if exists
	if inventory_component and inventory_component.inventory_changed.is_connected(update_ui):
		inventory_component.inventory_changed.disconnect(update_ui)
		
	inventory_component = comp
	if inventory_component:
		inventory_component.inventory_changed.connect(update_ui)
		init_ui()

func init_ui():
	active_slots.clear()
	
	if not inventory_component:
		return
		
	# 1. Handle Auto-Spawn Mode
	if auto_spawn_container and auto_spawn_template:
		for child in auto_spawn_container.get_children():
			child.queue_free()
		for i in range(inventory_component.slots.size()):
			var slot_ui = auto_spawn_template.instantiate()
			auto_spawn_container.add_child(slot_ui)
			
	# 2. Gather all SlotUIs (Wait 1 frame for ready if needed, but we assume ready)
	var all_slot_nodes: Array[SlotUI] = []
	_find_slot_uis(self, all_slot_nodes)
	
	# 3. Separate explicit vs auto
	var explicit_slots = {}
	var auto_slots = []
	
	for slot in all_slot_nodes:
		if slot.slot_index >= 0:
			explicit_slots[slot.slot_index] = slot
		else:
			auto_slots.append(slot)
			
	# 4. Assign internal indices
	var current_auto_idx = 0
	for slot in all_slot_nodes:
		var target_index = -1
		if slot.slot_index >= 0:
			target_index = slot.slot_index
		else:
			# Find next available index that is not explicitly taken
			while explicit_slots.has(current_auto_idx):
				current_auto_idx += 1
			target_index = current_auto_idx
			current_auto_idx += 1
			
		active_slots.append(slot)
		slot.internal_index = target_index
		
	update_ui()

func _find_slot_uis(node: Node, result: Array[SlotUI]):
	if node is SlotUI:
		result.append(node)
	for child in node.get_children():
		_find_slot_uis(child, result)

# อัปเดตข้อมูลและวาดหน้าจอใหม่
func update_ui():
	if not inventory_component:
		return
		
	for slot in active_slots:
		var target_index = slot.internal_index
		var slot_data = null
		if target_index >= 0 and target_index < inventory_component.slots.size():
			slot_data = inventory_component.slots[target_index]
			
		slot.update_slot(slot_data, target_index, inventory_component, self)

# --- ส่งผ่านการร้องขอ (Pass-through Requests) ไปยัง Core ---

signal tooltip_requested(slot_index: int, item_data: ItemData, runtime_data: Dictionary)
signal split_popup_requested(slot_index: int, current_amount: int)
signal tooltip_canceled(slot_index: int)

func request_use(index: int) -> void:
	if inventory_component:
		InventoryAPI.use_item(inventory_component, index, {"user": user})

func request_move(source_index: int, target_index: int, amount: int = -1) -> void:
	if inventory_component:
		inventory_component.move_item(source_index, target_index, amount)
		
func request_split_popup(index: int, amount: int) -> void:
	split_popup_requested.emit(index, amount)

func request_show_tooltip(index: int) -> void:
	if inventory_component and index >= 0 and index < inventory_component.slots.size():
		var slot_data = inventory_component.slots[index]
		var owning_slot = slot_data.get_owning_slot()
		if owning_slot.item:
			tooltip_requested.emit(index, owning_slot.item, owning_slot.runtime_data)

func request_hide_tooltip(index: int) -> void:
	tooltip_canceled.emit(index)
