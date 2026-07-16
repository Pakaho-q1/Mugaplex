@tool
extends Resource
class_name ItemData

signal data_changed

@export_group("Identity")
## The unique identifier for this item (e.g. 'iron_sword'). Must be unique across all items.
@export var item_id: StringName = ""
## The name displayed to the player in the UI.
@export var display_name: String = "New Item"
## A detailed description of the item shown in tooltips or details panels.
@export_multiline var description: String = ""

@export_group("Visual")
## The icon image shown in the inventory slot.
@export var icon: Texture2D

@export_group("Inventory")
## If true, multiple identical items can be stacked in a single slot.
@export var stackable: bool = false
## If true, this item cannot be 'Used' (e.g. raw materials like wood or iron).
@export var disable_use: bool = false
## The maximum number of items that can be stacked in a single slot. Ignored if stackable is false.
@export_range(1, 9999) var max_stack: int = 99
## How many grid cells this item occupies (width, height). Used for multi-cell (Diablo-style) inventories.
@export var grid_size: Vector2i = Vector2i(1, 1):
	set(value):
		grid_size = value
		emit_changed()
## Weight of a single unit of this item. 0.0 = weightless (default, fully backward-compatible).
@export var weight: float = 0.0
## If false, this item can never be rotated in a grid inventory, even if the player requests it.
@export var can_rotate: bool = true

@export_group("Modules")
## Add modules here to define item behaviors (e.g. ConsumableModule, EquipmentModule).
@export var modules: Array[ItemModule] = []

func get_module(module_class: Script) -> ItemModule:
	for module in modules:
		if module != null and is_instance_of(module, module_class):
			return module
	return null

func notify_changed() -> void:
	data_changed.emit()

func validate_modules() -> void:
	var seen_classes = {}
	for module in modules:
		if module == null:
			continue
		
		var script = module.get_script()
		if not script:
			continue
			
		var class_path = script.resource_path
		if seen_classes.has(class_path):
			push_warning("Item '%s' (ID: %s) has duplicate modules of type %s!" % [display_name, item_id, class_path.get_file()])
		else:
			seen_classes[class_path] = true
