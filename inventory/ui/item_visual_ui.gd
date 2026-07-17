extends Control
class_name ItemVisualUI

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel

var current_slot_index: int = -1

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon: icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if amount_label: amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_position_and_size(slot: InventorySlot, metrics: Dictionary, index: int, is_rotated: bool = false):
	current_slot_index = index
	var item = slot.item
	if not item:
		return
		
	var grid_w = metrics.grid_columns
	var cell_w = metrics.cell_size.x
	var cell_h = metrics.cell_size.y
	var h_sep = metrics.separation.x
	var v_sep = metrics.separation.y
	
	var col = index % grid_w
	var row = index / grid_w
	
	position = Vector2(col * (cell_w + h_sep), row * (cell_h + v_sep))
	
	var item_w = item.grid_size.y if is_rotated else item.grid_size.x
	var item_h = item.grid_size.x if is_rotated else item.grid_size.y
	
	size = Vector2(
		(item_w * cell_w) + ((item_w - 1) * h_sep),
		(item_h * cell_h) + ((item_h - 1) * v_sep)
	)
	
	# Handle Icon Scaling and Rotation
	if icon:
		icon.texture = item.icon
		
		if is_rotated and item.rotate_visual:
			icon.rotation_degrees = 90
			# The texture needs to be its original unrotated bounds, then rotated
			var orig_w = item.grid_size.x * cell_w + (item.grid_size.x - 1) * h_sep
			var orig_h = item.grid_size.y * cell_h + (item.grid_size.y - 1) * v_sep
			icon.size = Vector2(orig_w, orig_h)
			icon.position = (size - icon.size) / 2.0
			icon.pivot_offset = icon.size / 2.0
		else:
			icon.rotation_degrees = 0
			icon.size = size
			icon.position = Vector2.ZERO
			
	if amount_label:
		amount_label.text = str(slot.amount) if slot.amount > 1 else ""
