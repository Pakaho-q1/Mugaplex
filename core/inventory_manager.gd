extends Node

signal inventory_opened(inventory_component)
signal inventory_closed(inventory_component)
signal item_dropped(item: ItemData, amount: int, runtime_data: Dictionary)
signal cursor_item_changed()

var player_inventory: InventoryComponent

# --- CURSOR MANAGER ---
var cursor_item: ItemData = null
var cursor_amount: int = 0
var cursor_runtime: Dictionary = {}
var cursor_source_inventory: InventoryComponent = null
var cursor_source_index: int = -1

var _cursor_layer: CanvasLayer
var _cursor_icon: TextureRect
var _cursor_label: Label

func register_player(comp: InventoryComponent) -> void:
	player_inventory = comp

func get_player() -> InventoryComponent:
	return player_inventory

func _ready():
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.layer = 128
	add_child(_cursor_layer)
	
	_cursor_icon = TextureRect.new()
	_cursor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor_icon.custom_minimum_size = Vector2(64, 64)
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_layer.add_child(_cursor_icon)
	
	_cursor_label = Label.new()
	_cursor_label.position = Vector2(0, 32)
	_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_icon.add_child(_cursor_label)

func _process(delta):
	if cursor_item != null:
		_cursor_icon.global_position = _cursor_icon.get_global_mouse_position() - _cursor_icon.custom_minimum_size / 2

func update_cursor_visual():
	if cursor_item == null:
		_cursor_icon.texture = null
		_cursor_label.text = ""
		_cursor_icon.hide()
	else:
		_cursor_icon.texture = cursor_item.icon
		_cursor_label.text = str(cursor_amount) if cursor_amount > 1 else ""
		_cursor_icon.show()
	cursor_item_changed.emit()

func handle_slot_click(inv: InventoryComponent, slot_index: int, event: InputEventMouseButton, split_action_name: String, split_formula: String) -> void:
	if inv == null or slot_index < 0: return
	var target_slot = inv.slots[slot_index]
	var target_owning = target_slot.get_owning_slot()
	var real_index = inv.slots.find(target_owning)
	
	# Check if holding split modifier
	var is_split = (split_action_name != "" and InputMap.has_action(split_action_name) and Input.is_action_pressed(split_action_name))

	if event.button_index == MOUSE_BUTTON_LEFT:
		if cursor_item == null:
			# Pickup
			if target_owning.item != null:
				var take_amt = target_owning.amount
				if is_split:
					var expr = Expression.new()
					if expr.parse(split_formula, ["amount"]) == OK:
						var result = expr.execute([target_owning.amount], self)
						if not expr.has_execute_failed():
							take_amt = clampi(int(result), 1, target_owning.amount)
				
				var payload = inv.take_item_amount(real_index, take_amt)
				if payload.has("item"):
					cursor_item = payload["item"]
					cursor_amount = payload["amount"]
					cursor_runtime = payload["runtime_data"]
					cursor_source_inventory = inv
					cursor_source_index = real_index
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
