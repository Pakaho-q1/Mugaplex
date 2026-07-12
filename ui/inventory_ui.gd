extends Panel

const SLOT_UI_SCENE = preload("res://addons/universal_inventory/ui/slot_ui.tscn")
const InventoryAPI = preload("res://addons/universal_inventory/api/inventory_api.gd")

@export var inventory_component: InventoryComponent
@export var user: Node
@onready var grid = $GridContainer

func _ready():
	if not inventory_component:
		inventory_component = InventoryManager.get_player()
	if inventory_component:
		inventory_component.inventory_changed.connect(update_ui)
		init_ui()

# จัดเตรียมและสร้าง UI สล็อตให้เท่ากับขนาดของสล็อตใน Data Core
func init_ui():
	for child in grid.get_children():
		child.queue_free()
		
	if not inventory_component:
		return
		
	for i in range(inventory_component.slots.size()):
		var slot_ui = SLOT_UI_SCENE.instantiate()
		grid.add_child(slot_ui)
		
	update_ui()

# กวาดข้อมูลสล็อตเพื่อสั่งให้สล็อตย่อยวาดหน้าจอใหม่
func update_ui():
	if not inventory_component:
		return
		
	for i in range(inventory_component.slots.size()):
		var slot_ui = grid.get_child(i)
		var data_slot = inventory_component.slots[i]
		slot_ui.update_slot(data_slot, i, inventory_component, self)

# --- ส่งผ่านการร้องขอ (Pass-through Requests) ไปยัง Core ---

signal tooltip_requested(slot_index: int, item_data: ItemData, runtime_data: Dictionary)
signal tooltip_canceled(slot_index: int)

func request_use(index: int) -> void:
	if inventory_component:
		InventoryAPI.use_item(inventory_component, index, user)

func request_move(source_index: int, target_index: int) -> void:
	if inventory_component:
		InventoryAPI.move_item(inventory_component, source_index, target_index)

func request_show_tooltip(index: int) -> void:
	if inventory_component and index >= 0 and index < inventory_component.slots.size():
		var slot_data = inventory_component.slots[index]
		var owning_slot = slot_data.get_owning_slot()
		if owning_slot.item:
			tooltip_requested.emit(index, owning_slot.item, owning_slot.runtime_data)

func request_hide_tooltip(index: int) -> void:
	tooltip_canceled.emit(index)
