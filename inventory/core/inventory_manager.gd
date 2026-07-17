extends Node

signal inventory_opened(inventory_component)
signal inventory_closed(inventory_component)
signal item_dropped(item: ItemData, amount: int, runtime_data: Dictionary)
signal cursor_item_changed()
signal context_menu_requested(inventory: InventoryComponent, slot_index: int, screen_position: Vector2, source_slot_ui: Control)
signal tooltip_requested(slot_index: int, item_data: ItemData, runtime_data: Dictionary)
signal tooltip_canceled(slot_index: int)

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
		# Critical Bug #3 Fix: use viewport mouse position — correct under all CanvasLayer setups
		_cursor_visual.global_position = get_viewport().get_mouse_position() - _cursor_visual.size / 2

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
		
	var cell_size = source_slot.size
	var h_sep = 0
	var v_sep = 0
	if source_slot.get_parent() is GridContainer:
		h_sep = source_slot.get_parent().get_theme_constant("h_separation")
		v_sep = source_slot.get_parent().get_theme_constant("v_separation")
		
	var drag_size = source_slot.drag_preview_size
	var is_auto = true
	if "auto_drag_preview_size" in source_slot:
		is_auto = source_slot.auto_drag_preview_size
		
	if cursor_item and is_auto:
		var is_rot = cursor_runtime.get("rotated", false)
		var item_w = cursor_item.grid_size.y if is_rot else cursor_item.grid_size.x
		var item_h = cursor_item.grid_size.x if is_rot else cursor_item.grid_size.y
		drag_size = Vector2(
			(item_w * cell_size.x) + (max(0, item_w - 1) * h_sep),
			(item_h * cell_size.y) + (max(0, item_h - 1) * v_sep)
		)
		
	# Create a clean Control as the root of the drag preview
	_cursor_visual = Control.new()
	_cursor_visual.custom_minimum_size = drag_size
	_cursor_visual.size = drag_size
	_cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_layer.add_child(_cursor_visual)
	
	_cursor_icon_ref = TextureRect.new()
	_cursor_icon_ref.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor_icon_ref.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor_icon_ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_visual.add_child(_cursor_icon_ref)
	
	if cursor_item:
		var is_rot = cursor_runtime.get("rotated", false)
		if is_rot and cursor_item.rotate_visual:
			_cursor_icon_ref.rotation_degrees = 90
			var orig_w = cursor_item.grid_size.x * cell_size.x + max(0, cursor_item.grid_size.x - 1) * h_sep
			var orig_h = cursor_item.grid_size.y * cell_size.y + max(0, cursor_item.grid_size.y - 1) * v_sep
			if not is_auto:
				orig_w = drag_size.y
				orig_h = drag_size.x
			_cursor_icon_ref.size = Vector2(orig_w, orig_h)
			_cursor_icon_ref.position = (drag_size - _cursor_icon_ref.size) / 2.0
			_cursor_icon_ref.pivot_offset = _cursor_icon_ref.size / 2.0
		else:
			_cursor_icon_ref.rotation_degrees = 0
			_cursor_icon_ref.size = drag_size
			_cursor_icon_ref.position = Vector2.ZERO
			
	_cursor_label_ref = Label.new()
	_cursor_label_ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_label_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cursor_label_ref.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_cursor_label_ref.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	_cursor_label_ref.add_theme_constant_override("outline_size", 4)
	
	_cursor_label_ref.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cursor_label_ref.position = Vector2(drag_size.x - 40, drag_size.y - 23) # default offset
	_cursor_visual.add_child(_cursor_label_ref)

func _disable_mouse_filter_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_filter_recursive(child)

var current_context_receiver: Node = null

func handle_slot_click(inv: InventoryComponent, slot_index: int, event: InputEventMouseButton, source_slot: Control) -> void:
	if inv == null or slot_index < 0: return
	var target_slot = inv.slots[slot_index]
	var target_owning = target_slot.get_owning_slot()
	var real_index = inv.slots.find(target_owning)
	
	var split_action_name = ""
	var split_formula = "amount / 2"
	if current_context_receiver:
		split_action_name = current_context_receiver.get("split_action_name") if "split_action_name" in current_context_receiver else ""
		split_formula = current_context_receiver.get("split_formula") if "split_formula" in current_context_receiver else "amount / 2"
		
	var is_split = (split_action_name != "" and InputMap.has_action(split_action_name) and Input.is_action_pressed(split_action_name))

	if event.button_index == MOUSE_BUTTON_LEFT:
		if cursor_item == null:
			# Pickup
			if target_owning.item != null:
				var take_amt = target_owning.amount
				if is_split:
					# Split pickup
					var expr = Expression.new()
					var error = expr.parse(split_formula, ["amount"])
					if error == OK:
						var result = expr.execute([take_amt])
						if not expr.has_execute_failed():
							take_amt = clampi(int(result), 1, take_amt)
				
				var payload = inv.take_item_amount(real_index, take_amt)
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
				elif not is_split and target_owning.item == null and inv.has_method("get_overlapping_items"):
					# Place failed on an empty slot. Check if exactly 1 item is in the way (Multi-cell Swap)
					var overlaps = inv.get_overlapping_items(cursor_item, real_index, cursor_runtime.get("rotated", false))
					if overlaps.size() == 1:
						var swap_slot = overlaps[0]
						var swap_index = inv.slots.find(swap_slot)
						var temp_item = swap_slot.item
						var temp_amount = swap_slot.amount
						var temp_runtime = swap_slot.runtime_data.duplicate(true)
						
						var payload = inv.take_item_amount(swap_index, temp_amount)
						var re_left_over = inv.place_item_amount(real_index, cursor_item, cursor_amount, cursor_runtime)
						
						if re_left_over == 0:
							cursor_item = temp_item
							cursor_amount = temp_amount
							cursor_runtime = temp_runtime
							if source_slot: set_custom_cursor(source_slot)
							update_cursor_visual()
						else:
							# Revert
							inv.place_item_amount(swap_index, payload["item"], payload["amount"], payload["runtime_data"])
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
var hovered_inventory_ui: Control = null
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO

func cancel_cursor():
	return_cursor_to_source()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if cursor_item == null:
				is_dragging = true
				drag_start_position = event.global_position
			else:
				# Design Issue #8 Fix: Click-to-Hold mode (drag_mode=0) requires clicking a Slot to place.
				# Other modes allow clicking outside UI to drop to ground.
				var allow_outside_drop = true
				if cursor_source_ui != null:
					var mode = cursor_source_ui.get("drag_mode")
					if mode != null and mode == 0:  # Click-to-Hold only
						allow_outside_drop = false
				
				if allow_outside_drop and hovered_slot == null and hovered_inventory_ui == null:
					drop_cursor_to_ground()
					get_viewport().set_input_as_handled()
		else:
			# Released
			if cursor_item != null:
				if is_dragging:
					var dist = drag_start_position.distance_to(event.global_position)
					if dist > 5.0:
						if hovered_slot != null and is_instance_valid(hovered_slot):
							var mode = hovered_slot.get("drag_mode")
							if mode == null or mode != 0:
								handle_slot_click(hovered_slot.inventory_component, hovered_slot.internal_index, event, hovered_slot)
						else:
							if hovered_inventory_ui != null and is_instance_valid(hovered_inventory_ui):
								if hovered_inventory_ui.has_method("get_closest_slot"):
									var closest = hovered_inventory_ui.get_closest_slot(event.global_position)
									if closest:
										var mode = closest.get("drag_mode")
										if mode == null or mode != 0:
											handle_slot_click(closest.inventory_component, closest.internal_index, event, closest)
										return
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
		if item_dropped.get_connections().size() > 0:
			item_dropped.emit(cursor_item, cursor_amount, cursor_runtime)
			cursor_item = null
			cursor_amount = 0
			cursor_runtime.clear()
			update_cursor_visual()
		else:
			return_cursor_to_source()








