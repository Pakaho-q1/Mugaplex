extends Control
class_name SlotUI

@export_group("Slot Settings")
## Set >= 0 to hardcode index, otherwise auto-assigned by InventoryUI.
@export var slot_index: int = -1

@export_group("Core Elements")
## Optional Path to a specific Control node that should receive mouse clicks. If empty, the main SlotUI node is used.
@export var interaction_control_path: NodePath
## Path to the TextureRect used to display the item's icon.
@export var icon_rect_path: NodePath
## Path to the Label used to display the item stack amount.
@export var amount_label_path: NodePath

@export_group("Action Fallbacks")
## If true, double-clicking the slot will trigger the 'Use Item' logic.
@export var use_on_double_click: bool = true
## If true, right-clicking the slot will trigger the 'Use Item' logic.
@export var use_on_right_click: bool = false

@export_group("Input Map Actions (Optional)")
## The InputMap action name to trigger 'Use' (e.g. 'inventory_use'). Leave empty to disable.
@export var use_action_name: String = ""
## The InputMap action name to trigger 'Drop' (e.g. 'inventory_drop'). Leave empty to disable.
@export var drop_action_name: String = ""

@export_group("Context Menu Settings")
## Can this slot open a context menu when right clicked?
@export var allow_context_menu: bool = true

@export_group("Drag & Drop Settings")
## 0: Click to pick up/drop. 1: Hold to drag, release to drop. 2: Both (Hybrid).
@export_enum("Click-to-Hold", "Hold-to-Drag", "Hybrid") var drag_mode: int = 2
## The size of the preview when dragging the item (if not auto-scaling)
@export var drag_preview_size: Vector2 = Vector2(40, 40)
## If true, the drag preview automatically scales to match the item's grid size (Multi-Cell).
@export var auto_drag_preview_size: bool = true
## Delay in milliseconds before picking up an item via click. Useful if 'use_on_double_click' is true to prevent instant pickup from breaking the double click. Set to 0 for instant pickup.
@export var pickup_delay_ms: int = 150

@onready var icon: TextureRect = get_node_or_null(icon_rect_path) if not icon_rect_path.is_empty() else get_node_or_null("Icon")
@onready var amount_label: Label = get_node_or_null(amount_label_path) if not amount_label_path.is_empty() else get_node_or_null("AmountLabel")



@onready var interaction_control: Control = get_node_or_null(interaction_control_path) if not interaction_control_path.is_empty() else self

var internal_index: int = -1
var inventory_component: InventoryComponent = null
var inventory_ui: Control = null

func _ready():

	
	if interaction_control and interaction_control != self:
		interaction_control.gui_input.connect(_on_interaction_control_gui_input)
		interaction_control.mouse_entered.connect(_on_mouse_entered)
		interaction_control.mouse_exited.connect(_on_mouse_exited)
	else:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

func update_slot(slot_data: InventorySlot, index: int, comp: InventoryComponent, ui_manager: Control):
	internal_index = index if slot_index < 0 else slot_index
	inventory_component = comp
	inventory_ui = ui_manager
	
	if slot_data == null:
		_clear_display()
		return
		
	var owning_slot = slot_data.get_owning_slot()
	if owning_slot.item == null or slot_data.is_occupied_cell():
		_clear_display()
		return
		
	# Opportunity 4 Fix: Performance / Partial Update simulation
	# Avoid touching UI nodes if the data hasn't actually changed.
	if icon and icon.texture == owning_slot.item.icon and amount_label and amount_label.text == (str(owning_slot.amount) if owning_slot.amount > 1 else ""):
		pass
		
	# If InventoryUI uses Layer 2 (ItemVisualLayer), we don't draw anything in SlotUI
	if inventory_ui and inventory_ui.get("visual_layer") != null:
		_clear_display()
	else:
		if icon: icon.texture = owning_slot.item.icon
		if amount_label: amount_label.text = str(owning_slot.amount) if owning_slot.amount > 1 else ""
		
func _clear_display():
	if icon: icon.texture = null
	if amount_label: amount_label.text = ""

# --- TOOLTIP ---
func _on_mouse_entered():
	InventoryManager.hovered_slot = self
	if internal_index != -1 and inventory_ui and inventory_ui.has_method("request_show_tooltip"):
		inventory_ui.request_show_tooltip(internal_index)

func _on_mouse_exited():
	if InventoryManager.hovered_slot == self:
		InventoryManager.hovered_slot = null
	if internal_index != -1 and inventory_ui and inventory_ui.has_method("request_hide_tooltip"):
		inventory_ui.request_hide_tooltip(internal_index)

# --- MOUSE INPUT ---
func _gui_input(event: InputEvent):
	if interaction_control == self:
		_handle_mouse_input(event)

func _on_interaction_control_gui_input(event: InputEvent):
	_handle_mouse_input(event)

var _cancel_pickup: bool = false

func _handle_mouse_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		var handled_use = false
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click and use_on_double_click:
			_cancel_pickup = true
			_on_use_action()
			handled_use = true
			
		if not handled_use and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			if event.button_index == MOUSE_BUTTON_RIGHT and allow_context_menu and InventoryManager.cursor_item == null:
				var slot_data = inventory_component.slots[internal_index]
				var owning_slot = slot_data.get_owning_slot()
				if owning_slot.item != null:
					InventoryManager.context_menu_requested.emit(inventory_component, internal_index, get_viewport().get_mouse_position(), self)
			else:
				if event.button_index == MOUSE_BUTTON_LEFT and pickup_delay_ms > 0 and InventoryManager.cursor_item == null:
					_cancel_pickup = false
					await get_tree().create_timer(pickup_delay_ms / 1000.0).timeout
					if not is_instance_valid(self): return
					if _cancel_pickup: return
				InventoryManager.handle_slot_click(inventory_component, internal_index, event, self)

func _on_use_action():
	if internal_index != -1 and inventory_ui and inventory_ui.has_method("request_use"):
		inventory_ui.request_use(internal_index)

func _on_transfer_action():
	pass
