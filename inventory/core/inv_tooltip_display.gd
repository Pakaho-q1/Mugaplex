@tool
extends Node
class_name InvTooltipDisplay

@export_group("Tooltip UI")
## The main container of your tooltip (e.g. PanelContainer). We will show/hide this and move it to the mouse position.
@export var tooltip_container_path: NodePath
## Offset from the mouse cursor to display the tooltip.
@export var cursor_offset: Vector2 = Vector2(15, 15)

@export_group("Item Details Display")
@export var name_label_path: NodePath
@export var description_label_path: NodePath
@export var icon_rect_path: NodePath

@onready var tooltip_container: Control = get_node_or_null(tooltip_container_path)
@onready var name_label: Label = get_node_or_null(name_label_path)
@onready var description_label: Label = get_node_or_null(description_label_path)
@onready var icon_rect: TextureRect = get_node_or_null(icon_rect_path)

func _ready():
	if Engine.is_editor_hint():
		return
		
	if tooltip_container:
		tooltip_container.hide()
		# Ensure tooltip ignores mouse so it doesn't flicker when mouse moves over it
		tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	# Connect to Global signals
	if not InventoryManager.tooltip_requested.is_connected(_on_tooltip_requested):
		InventoryManager.tooltip_requested.connect(_on_tooltip_requested)
	if not InventoryManager.tooltip_canceled.is_connected(_on_tooltip_canceled):
		InventoryManager.tooltip_canceled.connect(_on_tooltip_canceled)

func _process(_delta):
	if Engine.is_editor_hint():
		return
		
	if tooltip_container and tooltip_container.visible:
		# Keep tooltip at mouse position
		var viewport_size = get_viewport().get_visible_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		
		var target_pos = mouse_pos + cursor_offset
		
		# Clamp to screen bounds
		if target_pos.x + tooltip_container.size.x > viewport_size.x:
			target_pos.x = mouse_pos.x - tooltip_container.size.x - cursor_offset.x
		if target_pos.y + tooltip_container.size.y > viewport_size.y:
			target_pos.y = mouse_pos.y - tooltip_container.size.y - cursor_offset.y
			
		tooltip_container.global_position = target_pos

func _on_tooltip_requested(_slot_index: int, item_data: ItemData, _runtime_data: Dictionary) -> void:
	if not item_data: return
	
	if name_label:
		name_label.text = item_data.display_name
	if description_label:
		description_label.text = item_data.description
	if icon_rect:
		icon_rect.texture = item_data.icon
		
	if tooltip_container:
		tooltip_container.show()

func _on_tooltip_canceled(_slot_index: int) -> void:
	if tooltip_container:
		tooltip_container.hide()
