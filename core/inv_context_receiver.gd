@tool
extends Node
class_name InvContextReceiver

@export_group("Menu UI")
## The main container of your context menu (e.g. PanelContainer). We will show/hide this and move it to the mouse position.
@export var menu_container_path: NodePath

@export_group("Item Details Display")
@export var name_label_path: NodePath
@export var description_label_path: NodePath
@export var icon_rect_path: NodePath

@export_group("Action Buttons")
@export var use_button_path: NodePath
@export var drop_button_path: NodePath
@export var split_button_path: NodePath

@export_group("Split UI (Optional)")
## Path to a Slider (e.g. HSlider) for selecting split amount.
@export var split_slider_path: NodePath
## Path to a Label that shows the current number selected on the slider.
@export var split_amount_label_path: NodePath

## Emitted when the menu is opened, in case you want to run custom animations.
signal menu_opened(inventory: InventoryComponent, slot_index: int)
## Emitted when the menu is closed.
signal menu_closed()

var current_inventory: InventoryComponent
var current_slot_index: int = -1
var current_slot_ui: Control = null

@onready var menu_container: Control = get_node_or_null(menu_container_path)
@onready var name_label: Label = get_node_or_null(name_label_path)
@onready var description_label: Label = get_node_or_null(description_label_path)
@onready var icon_rect: TextureRect = get_node_or_null(icon_rect_path)

@onready var use_button: BaseButton = get_node_or_null(use_button_path)
@onready var drop_button: BaseButton = get_node_or_null(drop_button_path)
@onready var split_button: BaseButton = get_node_or_null(split_button_path)

@onready var split_slider: Range = get_node_or_null(split_slider_path)
@onready var split_amount_label: Label = get_node_or_null(split_amount_label_path)

func _ready():
	if Engine.is_editor_hint(): return
	
	if menu_container:
		menu_container.hide()
		
		# --- AUTO-FIX Z-INDEX & POSITIONING ---
		# Create a CanvasLayer to guarantee the menu is drawn on top of the screen (Layer 100)
		var canvas = CanvasLayer.new()
		canvas.layer = 100
		add_child(canvas)
		
		var parent = menu_container.get_parent()
		if parent:
			parent.remove_child(menu_container)
		canvas.add_child(menu_container)
	
	if use_button: use_button.pressed.connect(_on_use_pressed)
	if drop_button: drop_button.pressed.connect(_on_drop_pressed)
	if split_button: split_button.pressed.connect(_on_split_pressed)
	
	if split_slider:
		split_slider.value_changed.connect(_on_split_slider_changed)
		
	InventoryManager.context_menu_requested.connect(_on_context_menu_requested)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if menu_container and menu_container.visible:
			# Close menu if clicked outside
			var local_pos = menu_container.get_local_mouse_position()
			if not Rect2(Vector2.ZERO, menu_container.size).has_point(local_pos):
				close_menu()

func _on_context_menu_requested(inv: InventoryComponent, idx: int, pos: Vector2, source_ui: Control = null):
	current_inventory = inv
	current_slot_index = idx
	current_slot_ui = source_ui
	
	var slot = inv.slots[idx]
	var owning_slot = slot.get_owning_slot()
	if owning_slot.item == null: return
	
	var item = owning_slot.item
	var amount = owning_slot.amount
	
	if name_label: name_label.text = item.display_name
	if description_label: description_label.text = item.description
	if icon_rect: icon_rect.texture = item.icon
	
	if use_button:
		use_button.disabled = item.get("disable_use") == true
		
	if split_button:
		split_button.disabled = amount <= 1
		
	if split_slider:
		if amount > 1:
			split_slider.min_value = 1
			split_slider.max_value = amount - 1
			split_slider.value = 1
			split_slider.editable = true
		else:
			split_slider.min_value = 0
			split_slider.max_value = 0
			split_slider.value = 0
			split_slider.editable = false
		_on_split_slider_changed(split_slider.value)
		
	if menu_container:
		menu_container.global_position = pos
		menu_container.show()
		
	menu_opened.emit(inv, idx)

func close_menu():
	if menu_container:
		menu_container.hide()
		
		# --- AUTO-FIX Z-INDEX & POSITIONING ---
		# Create a CanvasLayer to guarantee the menu is drawn on top of the screen (Layer 100)
		var canvas = CanvasLayer.new()
		canvas.layer = 100
		add_child(canvas)
		
		var parent = menu_container.get_parent()
		if parent:
			parent.remove_child(menu_container)
		canvas.add_child(menu_container)
	current_inventory = null
	current_slot_index = -1
	current_slot_ui = null
	menu_closed.emit()

func _on_use_pressed():
	if current_inventory and current_slot_index != -1:
		InventoryAPI.use_item(current_inventory, current_slot_index)
		close_menu()

func _on_drop_pressed():
	if current_inventory and current_slot_index != -1:
		InventoryAPI.drop_item(current_inventory, current_slot_index)
		close_menu()

func _on_split_pressed():
	if current_inventory and current_slot_index != -1:
		var amount_to_take = 1
		if split_slider:
			amount_to_take = int(split_slider.value)
		
		InventoryManager.grab_item_to_cursor(current_inventory, current_slot_index, amount_to_take, current_slot_ui)
		close_menu()

func _on_split_slider_changed(value: float):
	if split_amount_label:
		split_amount_label.text = str(int(value))
