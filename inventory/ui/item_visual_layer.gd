extends Control
class_name ItemVisualLayer

const VISUAL_TEMPLATE = preload("res://addons/mugaplex/inventory/ui/item_visual_ui.tscn")

var _active_visuals: Dictionary = {}
var _inv_comp: InventoryComponent = null
var _grid: GridContainer = null

var _custom_highlight: Control = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_custom_highlight_scene(scene: PackedScene):
	if _custom_highlight:
		_custom_highlight.queue_free()
		_custom_highlight = null
	if scene:
		_custom_highlight = scene.instantiate() as Control
		if _custom_highlight:
			_custom_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_custom_highlight)
			_custom_highlight.hide()

func _get_layout_metrics(grid_container: GridContainer) -> Dictionary:
	var h_sep: int = grid_container.get_theme_constant("h_separation")
	var v_sep: int = grid_container.get_theme_constant("v_separation")
	var cell_size = Vector2(64, 64)
	
	if grid_container.get_child_count() > 0:
		var sample_slot = grid_container.get_child(0)
		if sample_slot is Control:
			cell_size = sample_slot.size
			if cell_size.x <= 0 or cell_size.y <= 0:
				cell_size = sample_slot.custom_minimum_size
			if cell_size.x <= 0 or cell_size.y <= 0:
				cell_size = Vector2(64, 64)
			
	return {
		"grid_columns": grid_container.columns,
		"cell_size": cell_size,
		"separation": Vector2(h_sep, v_sep)
	}

func refresh(inventory_component: InventoryComponent, grid_container: GridContainer):
	_inv_comp = inventory_component
	_grid = grid_container
	var current_top_left_indices: Dictionary = {}
	var metrics = _get_layout_metrics(grid_container)
	
	for i in inventory_component.slots.size():
		var slot = inventory_component.slots[i]
		if slot.item == null or slot.is_occupied_cell():
			continue
			
		current_top_left_indices[i] = true
		var is_rot = slot.runtime_data.get("rotated", false)
		
		if _active_visuals.has(i):
			_active_visuals[i].update_position_and_size(slot, metrics, i, is_rot)
		else:
			var visual = VISUAL_TEMPLATE.instantiate() as ItemVisualUI
			add_child(visual)
			visual.update_position_and_size(slot, metrics, i, is_rot)
			_active_visuals[i] = visual
			
	for old_index in _active_visuals.keys():
		if not current_top_left_indices.has(old_index):
			_active_visuals[old_index].queue_free()
			_active_visuals.erase(old_index)

func set_hover_highlight(top_left_index: int):
	# Kept for backward compatibility with built-in highlight
	for idx in _active_visuals.keys():
		var visual = _active_visuals[idx]
		visual.set_highlight(idx == top_left_index)

func _process(delta: float):
	if not _custom_highlight or not is_instance_valid(_custom_highlight):
		return
	if not _inv_comp or not _grid:
		_custom_highlight.hide()
		return
		
	var hovered = InventoryManager.hovered_slot
	var hovered_ui = InventoryManager.hovered_inventory_ui
	
	if hovered == null and hovered_ui != null and hovered_ui.has_method("get_closest_slot"):
		# Smart snap fallback for highlight
		hovered = hovered_ui.get_closest_slot(get_viewport().get_mouse_position())
		
	if hovered and hovered.inventory_component == _inv_comp:
		var idx = hovered.internal_index
		var item = InventoryManager.cursor_item
		var is_rot = false
		if item:
			is_rot = InventoryManager.cursor_runtime.get("rotated", false)
		else:
			var slot_data = _inv_comp.slots[idx]
			var owning = slot_data.get_owning_slot()
			if owning.item:
				item = owning.item
				is_rot = owning.runtime_data.get("rotated", false)
				idx = _inv_comp.slots.find(owning)
				
		var metrics = _get_layout_metrics(_grid)
		var grid_w = metrics.grid_columns
		var cell_w = metrics.cell_size.x
		var cell_h = metrics.cell_size.y
		var h_sep = metrics.separation.x
		var v_sep = metrics.separation.y
		
		var col = idx % grid_w
		var row = idx / grid_w
		
		var item_w = 1
		var item_h = 1
		if item:
			item_w = item.grid_size.y if is_rot else item.grid_size.x
			item_h = item.grid_size.x if is_rot else item.grid_size.y
			
		_custom_highlight.position = Vector2(col * (cell_w + h_sep), row * (cell_h + v_sep))
		_custom_highlight.size = Vector2(
			(item_w * cell_w) + (max(0, item_w - 1) * h_sep),
			(item_h * cell_h) + (max(0, item_h - 1) * v_sep)
		)
		_custom_highlight.show()
	else:
		_custom_highlight.hide()
