extends Panel

const SLOT_UI_SCENE = preload("res://addons/universal_inventory/ui/slot_ui.tscn")

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

func request_use(index: int) -> void:
	if inventory_component:
		inventory_component.use_item(index, user)

func request_move(source_index: int, target_index: int) -> void:
	if inventory_component:
		inventory_component.move_item(source_index, target_index)
