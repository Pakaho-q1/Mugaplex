extends PanelContainer

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel

var slot_index: int = -1
var inventory_component: InventoryComponent = null
var inventory_ui: Control = null # Parent layout manager

# --- อัปเดตการแสดงผล (ตามข้อมูลที่ได้รับจาก Data) ---
func update_slot(slot_data: InventorySlot, index: int, comp: InventoryComponent, ui_manager: Control):
	slot_index = index
	inventory_component = comp
	inventory_ui = ui_manager
	
	if slot_data == null:
		_clear_display()
		return
		
	# วาดหน้าจอโดยอ้างอิงจากข้อมูลช่องหลักจริง (กรณีโดนจอง)
	var owning_slot = slot_data.get_owning_slot()
	if owning_slot.item == null or slot_data.is_occupied_cell():
		_clear_display()
	else:
		icon.texture = owning_slot.item.icon
		if owning_slot.amount > 1:
			amount_label.text = str(owning_slot.amount)
		else:
			amount_label.text = ""

func _clear_display():
	icon.texture = null
	amount_label.text = ""

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	if slot_index != -1 and inventory_ui and inventory_ui.has_method("request_show_tooltip"):
		inventory_ui.request_show_tooltip(slot_index)

func _on_mouse_exited():
	if slot_index != -1 and inventory_ui and inventory_ui.has_method("request_hide_tooltip"):
		inventory_ui.request_hide_tooltip(slot_index)

# --- การคลิกเพื่อขอใช้งานไอเทม (ส่งต่อคำขอ) ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_request_use()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_request_use()

func _request_use() -> void:
	if slot_index != -1 and inventory_ui and inventory_ui.has_method("request_use"):
		inventory_ui.request_use(slot_index)

# --- ระบบ DRAG & DROP (ถามสิทธิ์จาก Data และส่งต่อผลลัพธ์) ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_index == -1 or not inventory_component:
		return null
		
	var slot_data = inventory_component.slots[slot_index]
	var owning_slot = slot_data.get_owning_slot()
	
	if owning_slot.item == null:
		return null
		
	# สร้างรูปพรีวิวติดตามเมาส์
	var preview_texture = TextureRect.new()
	preview_texture.texture = owning_slot.item.icon
	preview_texture.custom_minimum_size = Vector2(64, 64)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var preview_control = Control.new()
	preview_texture.position = -preview_texture.custom_minimum_size / 2
	preview_control.add_child(preview_texture)
	set_drag_preview(preview_control)
	
	# หา Index ของสล็อตหลักตัวจริงเพื่อส่งเป็นข้อมูลลาก
	var owning_index = inventory_component.slots.find(owning_slot)
	return {"source_index": owning_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("source_index"):
		return false
		
	var source_idx = data["source_index"]
	if source_idx == slot_index:
		return false
		
	if not inventory_component or slot_index >= inventory_component.slots.size():
		return false
		
	# ยืมถามสิทธิ์ (can_accept) จากข้อมูลสล็อตจริงฝั่ง Data
	var source_item = inventory_component.slots[source_idx].item
	var target_slot_data = inventory_component.slots[slot_index]
	
	return target_slot_data.can_accept(source_item)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_idx = data["source_index"]
	if inventory_ui and inventory_ui.has_method("request_move"):
		inventory_ui.request_move(source_idx, slot_index)

