extends Node

signal inventory_opened(inventory_component)
signal inventory_closed(inventory_component)
signal item_dropped(item: ItemData, amount: int, runtime_data: Dictionary)
signal cursor_item_changed()
signal context_menu_requested(inventory: InventoryComponent, slot_index: int, screen_position: Vector2, source_slot_ui: Control)

var player_inventory: InventoryComponent

# --- CURSOR MANAGER ---
var cursor_item: ItemData = null
var cursor_amount: int = 0
var cursor_runtime: Dictionary = {}
var cursor_source_inventory: InventoryComponent
var cursor_source_ui: Control = null
var cursor_source_index: int = -1

var _cursor_layer: CanvasLayer
var _cursor_visual: Control = null
var _cursor_icon_ref: TextureRect = null
var _cursor_label_ref: Label = null

func register_player(comp: InventoryComponent) -> void:
	player_inventory = comp

func get_player() -> InventoryComponent:
	return player_inventory

func _ready():
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.layer = 128
	add_child(_cursor_layer)

func _process(delta):
	if cursor_item != null and _cursor_visual != null:
		_cursor_visual.global_position = _cursor_visual.get_global_mouse_position() - _cursor_visual.size / 2

func update_cursor_visual():
	if cursor_item == null:
		if _cursor_visual: _cursor_visual.hide()
	else:
		if _cursor_icon_ref: _cursor_icon_ref.texture = cursor_item.icon
		if _cursor_label_ref: _cursor_label_ref.text = str(cursor_amount) if cursor_amount > 1 else ""
		if _cursor_visual: 
			_cursor_visual.show()
			# Force position update immediately upon visual update to prevent frame flicker at (0,0)
			_cursor_visual.global_position = get_viewport().get_mouse_position() - _cursor_visual.size / 2
	cursor_item_changed.emit()
	
func set_custom_cursor(source_slot: Control):
	if _cursor_visual:
		_cursor_visual.queue_free()
		_cursor_visual = null
		_cursor_icon_ref = null
		_cursor_label_ref = null
		
	if source_slot.get("drag_preview_container_path") and not source_slot.drag_preview_container_path.is_empty():
		var container = source_slot.get_node(source_slot.drag_preview_container_path)
		if container:
			_cursor_visual = container.duplicate(0)
			_cursor_layer.add_child(_cursor_visual)
			_disable_mouse_filter_recursive(_cursor_visual)
			
			if source_slot.icon:
				var icon_path = container.get_path_to(source_slot.icon)
				_cursor_icon_ref = _cursor_visual.get_node_or_null(icon_path) as TextureRect
			
			if source_slot.amount_label:
				var label_path = container.get_path_to(source_slot.amount_label)
				_cursor_label_ref = _cursor_visual.get_node_or_null(label_path) as Label
				
	# Fallback
	if not _cursor_visual:
		_cursor_visual = TextureRect.new()
		_cursor_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cursor_visual.custom_minimum_size = source_slot.drag_preview_size
		_cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cursor_layer.add_child(_cursor_visual)
		_cursor_icon_ref = _cursor_visual
		
		_cursor_label_ref = Label.new()
		_cursor_label_ref.position = Vector2(0, source_slot.drag_preview_size.y * 0.5)
		_cursor_label_ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cursor_visual.add_child(_cursor_label_ref)

func _disable_mouse_filter_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_filter_recursive(child)

func handle_slot_click(inv: InventoryComponent, slot_index: int, event: InputEventMouseButton, source_slot: Control) -> void:
	if inv == null or slot_index < 0: return
	var target_slot = inv.slots[slot_index]
	var target_owning = target_slot.get_owning_slot()
	var real_index = inv.slots.find(target_owning)
	
	var split_action_name = source_slot.split_action_name if "split_action_name" in source_slot else ""
	var split_formula = source_slot.split_formula if "split_formula" in source_slot else "amount / 2"
	
	# Check if holding split modifier
	var is_split = (split_action_name != "" and InputMap.has_action(split_action_name) and Input.is_action_pressed(split_action_name))

	if event.button_index == MOUSE_BUTTON_LEFT:
		if cursor_item == null:
			# Pickup
			if target_owning.item != null:
				var payload = inv.take_item_amount(real_index, target_owning.amount)
				cursor_item = payload["item"]
				cursor_amount = payload["amount"]
				cursor_runtime = payload["runtime_data"]
				cursor_source_inventory = inv
				cursor_source_index = real_index
				cursor_source_ui = source_slot
				set_custom_cursor(source_slot)
				update_cursor_visual()
		else:
			# Place or Swap or Merge
			if target_owning.item == null or target_owning.item == cursor_item:
				# Place/Merge
				var left_over = inv.place_item_amount(real_index, cursor_item, cursor_amount, cursor_runtime)
				if left_over < cursor_amount:
					cursor_amount = left_over
					if cursor_amount <= 0:
						cursor_item = null
						cursor_runtime.clear()
					update_cursor_visual()
			else:
				# Swap
				if not is_split: # Full swap only
					var temp_item = target_owning.item
					var temp_amount = target_owning.amount
					var temp_runtime = target_owning.runtime_data.duplicate(true)
					
					var payload = inv.take_item_amount(real_index, temp_amount)
					var left_over = inv.place_item_amount(real_index, cursor_item, cursor_amount, cursor_runtime)
					if left_over == 0:
						cursor_item = temp_item
						cursor_amount = temp_amount
						cursor_runtime = temp_runtime
						set_custom_cursor(source_slot)
						update_cursor_visual()
					else:
						# Revert if failed
						inv.place_item_amount(real_index, payload["item"], payload["amount"], payload["runtime_data"])
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if cursor_item != null:
			# Place 1
			var left_over = inv.place_item_amount(real_index, cursor_item, 1, cursor_runtime)
			if left_over == 0: # 1 item was placed
				cursor_amount -= 1
				if cursor_amount <= 0:
					cursor_item = null
					cursor_runtime.clear()
				update_cursor_visual()

func grab_item_to_cursor(inv: InventoryComponent, slot_index: int, amount: int, source_slot_ui: Control = null) -> void:
	if inv == null or slot_index < 0: return
	var target_slot = inv.slots[slot_index]
	var target_owning = target_slot.get_owning_slot()
	if target_owning.item == null: return
	
	var real_index = inv.slots.find(target_owning)
	var take_amt = clampi(amount, 1, target_owning.amount)
	
	# If we already have something in cursor, we can't grab unless it's the same item?
	# Actually, if the cursor is not empty, grabbing more of the same item should merge into the cursor.
	# But typical split logic expects the cursor to be empty.
	if cursor_item != null:
		if cursor_item != target_owning.item:
			return # Can't split into a cursor holding a different item
		if not cursor_item.stackable:
			return
			
	var payload = inv.take_item_amount(real_index, take_amt)
	if payload.has("item"):
		if cursor_item == null:
			cursor_item = payload["item"]
			cursor_amount = payload["amount"]
			cursor_runtime = payload["runtime_data"]
			cursor_source_inventory = inv
			cursor_source_index = real_index
		else:
			cursor_amount += payload["amount"]
			
		if source_slot_ui:
			set_custom_cursor(source_slot_ui)
		update_cursor_visual()


var hovered_slot: Control = null
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if cursor_item == null:
				is_dragging = true
				drag_start_position = event.global_position
			else:
				if get_viewport().gui_get_hovered_control() == null:
					drop_cursor_to_ground()
					get_viewport().set_input_as_handled()
		else:
			# Released
			if cursor_item != null:
				if is_dragging:
					var dist = drag_start_position.distance_to(event.global_position)
					if dist > 5.0:
						if hovered_slot != null:
							var mode = hovered_slot.get("drag_mode")
							if mode == null or mode != 0:
								handle_slot_click(hovered_slot.inventory_component, hovered_slot.internal_index, event, hovered_slot)
						else:
							var hovered_ui = get_viewport().gui_get_hovered_control()
							if hovered_ui != null:
								return_cursor_to_source()
								get_viewport().set_input_as_handled()
							else:
								drop_cursor_to_ground()
								get_viewport().set_input_as_handled()
					else:
						# Quick click
						if cursor_source_ui != null:
							var source_mode = cursor_source_ui.get("drag_mode")
							if source_mode != null and source_mode == 1:
								# Hold-to-Drag only. They clicked without dragging, cancel.
								return_cursor_to_source()
								get_viewport().set_input_as_handled()
					is_dragging = false
				else:
					pass # Click outside UI drop is now handled on pressed

func return_cursor_to_source():
	if cursor_source_inventory and cursor_source_index != -1 and cursor_item != null:
		cursor_source_inventory.place_item_amount(cursor_source_index, cursor_item, cursor_amount, cursor_runtime)
		cursor_item = null
		cursor_amount = 0
		cursor_runtime.clear()
		update_cursor_visual()

func drop_cursor_to_ground():
	if cursor_item != null:
		item_dropped.emit(cursor_item, cursor_amount, cursor_runtime)
		cursor_item = null
		cursor_amount = 0
		cursor_runtime.clear()
		update_cursor_visual()








