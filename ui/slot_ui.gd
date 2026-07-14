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

@export_group("Details Display (Optional)")
## Path to the Label used to display the item name.
@export var name_label_path: NodePath
## Path to the Label used to display the item description.
@export var description_label_path: NodePath
## Path to the RichTextLabel used to display the item details/tooltips.
@export var details_richtext_path: NodePath

@export_group("Action Buttons (Optional)")
## Optional Path to a Button node that triggers the 'Use Item' logic when clicked.
@export var use_button_path: NodePath
## Optional Path to a Button node that triggers the 'Drop Item' logic when clicked.
@export var drop_button_path: NodePath
## Optional Path to a Button node that triggers splitting.
@export var split_button_path: NodePath
## Optional Path to a Button node for transferring.
@export var transfer_button_path: NodePath

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
## The InputMap action name to trigger 'Split' (e.g. 'inventory_split'). Leave empty to disable.
@export var split_action_name: String = ""

@export_group("Drag & Drop Settings")
## The size (in pixels) of the item icon while dragging it with the mouse.
@export var drag_preview_size: Vector2 = Vector2(64, 64)

@export_group("Split Behavior")
## Delay in milliseconds before picking up an item via click. Useful if 'use_on_double_click' is true to prevent instant pickup from breaking the double click. Set to 0 for instant pickup.
@export var pickup_delay_ms: int = 150
## If true, pressing the split button triggers the 'split_popup_requested' signal in InventoryUI instead of dragging half the stack.
@export var use_custom_split_ui: bool = false
## The math formula evaluated when splitting via drag (e.g. 'amount / 2' or 'amount - 1'). Ignored if use_custom_split_ui is true.
@export var split_formula: String = "amount / 2"

@onready var icon: TextureRect = get_node_or_null(icon_rect_path) if not icon_rect_path.is_empty() else get_node_or_null("Icon")
@onready var amount_label: Label = get_node_or_null(amount_label_path) if not amount_label_path.is_empty() else get_node_or_null("AmountLabel")

@onready var name_label: Label = get_node_or_null(name_label_path) if not name_label_path.is_empty() else null
@onready var description_label: Label = get_node_or_null(description_label_path) if not description_label_path.is_empty() else null
@onready var details_richtext: RichTextLabel = get_node_or_null(details_richtext_path) if not details_richtext_path.is_empty() else null

@onready var use_button: BaseButton = get_node_or_null(use_button_path) if not use_button_path.is_empty() else null
@onready var drop_button: BaseButton = get_node_or_null(drop_button_path) if not drop_button_path.is_empty() else null
@onready var split_button: BaseButton = get_node_or_null(split_button_path) if not split_button_path.is_empty() else null
@onready var transfer_button: BaseButton = get_node_or_null(transfer_button_path) if not transfer_button_path.is_empty() else null

@onready var interaction_control: Control = get_node_or_null(interaction_control_path) if not interaction_control_path.is_empty() else self

var internal_index: int = -1
var inventory_component: InventoryComponent = null
var inventory_ui: Control = null

func _ready():
	if use_button: use_button.pressed.connect(_on_use_action)
	if drop_button: drop_button.pressed.connect(_on_drop_action)
	if split_button: split_button.pressed.connect(_on_split_action)
	if transfer_button: transfer_button.pressed.connect(_on_transfer_action)
	
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
		
	if icon: icon.texture = owning_slot.item.icon
	if amount_label: amount_label.text = str(owning_slot.amount) if owning_slot.amount > 1 else ""
	if name_label: name_label.text = owning_slot.item.display_name
	if description_label: description_label.text = owning_slot.item.description
		
func _clear_display():
	if icon: icon.texture = null
	if amount_label: amount_label.text = ""
	if name_label: name_label.text = ""
	if description_label: description_label.text = ""
	if details_richtext: details_richtext.text = ""

# --- TOOLTIP ---
func _on_mouse_entered():
	if internal_index != -1 and inventory_ui and inventory_ui.has_method("request_show_tooltip"):
		inventory_ui.request_show_tooltip(internal_index)

func _on_mouse_exited():
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
		if event.button_index == MOUSE_BUTTON_RIGHT and use_on_right_click:
			_on_use_action()
			handled_use = true
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click and use_on_double_click:
			_cancel_pickup = true
			_on_use_action()
			handled_use = true
			
		if not handled_use and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			if event.button_index == MOUSE_BUTTON_LEFT and pickup_delay_ms > 0:
				_cancel_pickup = false
				await get_tree().create_timer(pickup_delay_ms / 1000.0).timeout
				if _cancel_pickup:
					return
			InventoryManager.handle_slot_click(inventory_component, internal_index, event, split_action_name, split_formula)
			
	if use_action_name != "" and InputMap.has_action(use_action_name) and event.is_action_pressed(use_action_name):
		_on_use_action()
	elif split_action_name != "" and InputMap.has_action(split_action_name) and event.is_action_pressed(split_action_name):
		_on_split_action()
	elif drop_action_name != "" and InputMap.has_action(drop_action_name) and event.is_action_pressed(drop_action_name):
		_on_drop_action()

func _on_use_action():
	if internal_index != -1 and inventory_ui and inventory_ui.has_method("request_use"):
		inventory_ui.request_use(internal_index)

func _on_drop_action():
	pass

func _on_split_action():
	if use_custom_split_ui and internal_index != -1 and inventory_ui and inventory_ui.has_method("request_split_popup"):
		var slot_data = inventory_component.slots[internal_index]
		var owning_slot = slot_data.get_owning_slot()
		if owning_slot.item != null:
			inventory_ui.request_split_popup(internal_index, owning_slot.amount)

func _on_transfer_action():
	pass
