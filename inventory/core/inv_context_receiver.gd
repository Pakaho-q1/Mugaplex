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

@export_group("Input Map Actions")
## An action name from the Input Map (e.g. 'ui_shift'). If held while clicking, triggers quick split.
@export var split_action_name: String = ""
## A valid GDScript math expression to determine how many items are taken on split. Variables available: 'amount' (total stack).
@export var split_formula: String = "amount / 2"
## An action name from the Input Map (e.g. 'inventory_rotate') to rotate the item in the cursor or hovered slot.
@export var rotate_action_name: String = ""

@export_group("Split UI (Optional)")
## Path to a Slider (e.g. HSlider) for selecting split amount.
@export var split_slider_path: NodePath
## Path to a Label that shows the current number selected on the slider.
@export var split_amount_label_path: NodePath

@export_group("Action Buttons")
@export var use_button_path: NodePath
@export var drop_button_path: NodePath
@export var split_button_path: NodePath
@export var rotate_button_path: NodePath

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
@onready var rotate_button: BaseButton = get_node_or_null(rotate_button_path)

@onready var split_slider: Range = get_node_or_null(split_slider_path)
@onready var split_amount_label: Label = get_node_or_null(split_amount_label_path)

func _ready():
	if Engine.is_editor_hint(): return
	
	InventoryManager.current_context_receiver = self
	
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
	if rotate_button: rotate_button.pressed.connect(_on_rotate_pressed)
	
	if split_slider:
		split_slider.value_changed.connect(_on_split_slider_changed)
		
	InventoryManager.context_menu_requested.connect(_on_context_menu_requested)

func _input(event):
	if rotate_action_name != "" and event.is_action_pressed(rotate_action_name):
		# Priority 1: Rotate item on cursor
		if InventoryManager.cursor_item != null and InventoryManager.cursor_item.can_rotate:
			InventoryManager.cursor_runtime["rotated"] = not InventoryManager.cursor_runtime.get("rotated", false)
			InventoryManager.update_cursor_visual()
			get_viewport().set_input_as_handled()
		# Priority 2: Rotate item in hovered slot
		elif InventoryManager.hovered_slot != null:
			var inv = InventoryManager.hovered_slot.inventory_component
			var idx = InventoryManager.hovered_slot.internal_index
			var slot = inv.get_slot(idx)
			if slot and slot.item != null and slot.item.can_rotate:
				# We just toggle rotation and let it fail if no room
				var is_rot = slot.runtime_data.get("rotated", false)
				slot.runtime_data["rotated"] = not is_rot
				
				# Check if it fits
				var ignore = []
				for y in range(slot.item.grid_size.y if is_rot else slot.item.grid_size.x):
					for x in range(slot.item.grid_size.x if is_rot else slot.item.grid_size.y):
						ignore.append(idx + y * inv.grid_columns + x)
						
				if not inv.can_place_item_at(slot.item, idx, ignore, not is_rot):
					# Revert if it doesn't fit
					slot.runtime_data["rotated"] = is_rot
				else:
					# Force refresh by removing and adding it back
					var amount = slot.amount
					var item = slot.item
					var runtime = slot.runtime_data.duplicate(true)
					inv.take_item_amount(idx, amount)
					inv.place_item_amount(idx, item, amount, runtime)
				
				get_viewport().set_input_as_handled()
				
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

func _on_rotate_pressed():
	if current_inventory and current_slot_index != -1:
		var slot = current_inventory.get_slot(current_slot_index)
		if slot and slot.item != null and slot.item.can_rotate:
			var is_rot = slot.runtime_data.get("rotated", false)
			slot.runtime_data["rotated"] = not is_rot
			
			var ignore = []
			for y in range(slot.item.grid_size.y if is_rot else slot.item.grid_size.x):
				for x in range(slot.item.grid_size.x if is_rot else slot.item.grid_size.y):
					ignore.append(current_slot_index + y * current_inventory.grid_columns + x)
					
			if not current_inventory.can_place_item_at(slot.item, current_slot_index, ignore, not is_rot):
				slot.runtime_data["rotated"] = is_rot
			else:
				var amount = slot.amount
				var item = slot.item
				var runtime = slot.runtime_data.duplicate(true)
				current_inventory.take_item_amount(current_slot_index, amount)
				current_inventory.place_item_amount(current_slot_index, item, amount, runtime)
				
		close_menu()

func _on_split_slider_changed(value: float):
	if split_amount_label:
		split_amount_label.text = str(int(value))
