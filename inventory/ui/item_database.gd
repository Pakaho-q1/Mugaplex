@tool
extends Control

const REGISTRY_PATH = "res://addons/mugaplex/inventory/item_database_registry.tres"
var registry: ItemDatabaseRegistry = null

@onready var base_path_input: LineEdit = %BasePathInput
@onready var sub_path_input: LineEdit = %SubPathInput
@onready var search_input: LineEdit = %SearchInput
@onready var item_list: ItemList = $HSplitContainer/LeftPanel/ItemList

@onready var add_button: Button = $HSplitContainer/LeftPanel/ButtonBox/AddItemButton
@onready var delete_button: Button = $HSplitContainer/LeftPanel/ButtonBox/DeleteItemButton
@onready var save_button: Button = $HSplitContainer/LeftPanel/ButtonBox/SaveButton

@onready var module_list: VBoxContainer = %ModuleList

var current_index: int = -1

func _ready():
	_ensure_registry()
	
	if not search_input.text_changed.is_connected(_on_search_input_text_changed):
		search_input.text_changed.connect(_on_search_input_text_changed)
		
	if not add_button.pressed.is_connected(_on_add_button_pressed):
		add_button.pressed.connect(_on_add_button_pressed)
		
	if not delete_button.pressed.is_connected(_on_delete_button_pressed):
		delete_button.pressed.connect(_on_delete_button_pressed)
		
	if not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)
		
	if not item_list.item_selected.is_connected(_on_item_list_item_selected):
		item_list.item_selected.connect(_on_item_list_item_selected)
		
	if not base_path_input.text_changed.is_connected(func(t): refresh_item_list()):
		base_path_input.text_changed.connect(func(t): refresh_item_list())
		
	refresh_item_list()
	_populate_module_library()

func _get_full_base_path() -> String:
	var path = base_path_input.text.strip_edges()
	if path == "": path = "items"
	if not path.begins_with("res://"):
		path = "res://" + path
	return path

func _get_full_sub_path() -> String:
	var sub = sub_path_input.text.strip_edges()
	var base = _get_full_base_path()
	if sub == "":
		return base
	return base.path_join(sub)

func _ensure_folder(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

func _ensure_registry() -> void:
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = load(REGISTRY_PATH) as ItemDatabaseRegistry
	if not registry:
		registry = ItemDatabaseRegistry.new()
		ResourceSaver.save(registry, REGISTRY_PATH)

func _rebuild_registry() -> void:
	_ensure_registry()
	var base = _get_full_base_path()
	if DirAccess.dir_exists_absolute(base):
		registry.rebuild(base)
		ResourceSaver.save(registry, REGISTRY_PATH)

# --- SEARCH & FILTER ---
func _on_search_input_text_changed(new_text: String) -> void:
	refresh_item_list(new_text.strip_edges())

# --- LIST MANAGEMENT ---
func _scan_directory_recursive(path: String, items: Array[ItemData]):
	if not DirAccess.dir_exists_absolute(path): return
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					var file_path = path.path_join(file_name)
					var res = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
					if res is ItemData:
						items.append(res as ItemData)
			else:
				if file_name != "." and file_name != "..":
					_scan_directory_recursive(path.path_join(file_name), items)
			file_name = dir.get_next()

func refresh_item_list(filter: String = ""):
	item_list.clear()
	var base = _get_full_base_path()
	_ensure_folder(base)
	
	var items: Array[ItemData] = []
	_scan_directory_recursive(base, items)
	
	for item in items:
		var match_name = filter == "" or filter.to_lower() in item.display_name.to_lower() or filter.to_lower() in String(item.item_id).to_lower()
		if match_name:
			var display_text = item.display_name
			if item.item_id != &"":
				display_text += " [" + String(item.item_id) + "]"
			
			var idx = item_list.add_item(display_text)
			item_list.set_item_metadata(idx, item.resource_path)
			if item.icon:
				item_list.set_item_icon(idx, item.icon)

func _select_item_by_path(path: String) -> void:
	for i in range(item_list.item_count):
		if item_list.get_item_metadata(i) == path:
			item_list.select(i)
			_on_item_list_item_selected(i)
			break

# --- BUTTONS ---
func _on_add_button_pressed():
	var new_item = ItemData.new()
	new_item.display_name = "New Item"
	
	var base_id = "new_item"
	var clean_id = base_id
	var counter = 1
	
	var save_dir = _get_full_sub_path()
	_ensure_folder(save_dir)
	
	var file_name = "item_" + clean_id + ".tres"
	var save_path = save_dir.path_join(file_name)
	
	while FileAccess.file_exists(save_path):
		clean_id = base_id + "_" + str(counter)
		file_name = "item_" + clean_id + ".tres"
		save_path = save_dir.path_join(file_name)
		counter += 1
		
	new_item.item_id = StringName(clean_id)
	
	ResourceSaver.save(new_item, save_path)
	EditorInterface.get_resource_filesystem().scan()
	
	_rebuild_registry()
	refresh_item_list()
	_select_item_by_path(save_path)
	
	EditorInterface.edit_resource(new_item)

func _on_delete_button_pressed():
	var selected = item_list.get_selected_items()
	if selected.is_empty(): return
	var idx = selected[0]
	var file_path = item_list.get_item_metadata(idx)
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		EditorInterface.get_resource_filesystem().scan()
		
		current_index = -1
		
		_rebuild_registry()
		refresh_item_list()

func _on_save_button_pressed():
	if current_index != -1 and current_index < item_list.item_count:
		var file_path = item_list.get_item_metadata(current_index)
		# Load the item again from cache (which the inspector modified) and save it
		var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE)
		if item:
			ResourceSaver.save(item, file_path)
			
	_rebuild_registry()
	refresh_item_list(search_input.text.strip_edges())
	print("Item Database: Current item saved. Registry rebuilt and list refreshed.")

# --- ITEM SELECTION ---
func _on_item_list_item_selected(index: int):
	current_index = index
	var file_path = item_list.get_item_metadata(index)
	var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE) as ItemData
	
	if item:
		EditorInterface.edit_resource(item)

# --- MODULE ENCYCLOPEDIA ---
func _populate_module_library():
	for child in module_list.get_children():
		child.queue_free()
		
	var module_paths = [
		"res://addons/mugaplex/inventory/modules/consumable_module.gd",
		"res://addons/mugaplex/inventory/modules/food_module.gd",
		"res://addons/mugaplex/inventory/modules/weapon_module.gd",
		"res://addons/mugaplex/inventory/modules/armor_module.gd",
		"res://addons/mugaplex/inventory/modules/tool_module.gd",
		"res://addons/mugaplex/inventory/modules/condition_module.gd",
		"res://addons/mugaplex/inventory/modules/perishable_module.gd"
	]
	
	for path in module_paths:
		var script = load(path) as Script
		if script:
			_create_module_card(script, path.get_file().get_basename().capitalize())

func _create_module_card(script: Script, title: String):
	var panel = PanelContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Header
	var header = Label.new()
	header.text = title
	header.theme_type_variation = &"HeaderMedium"
	vbox.add_child(header)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Inputs (Exports)
	var prop_title = Label.new()
	prop_title.text = "Inputs (Inspector Variables):"
	prop_title.modulate = Color(0.8, 0.8, 1.0)
	vbox.add_child(prop_title)
	
	var props = script.get_script_property_list()
	var has_exports = false
	for p in props:
		if p["usage"] & PROPERTY_USAGE_EDITOR:
			# Skip built-in script properties
			if p["name"] in ["Script Variables", "script", "resource_name", "resource_path", "resource_local_to_scene"]:
				continue
			var l = Label.new()
			l.text = "  - " + p["name"]
			l.add_theme_font_size_override("font_size", 12)
			vbox.add_child(l)
			has_exports = true
			
	if not has_exports:
		var l = Label.new()
		l.text = "  (No exposed variables)"
		l.add_theme_font_size_override("font_size", 12)
		l.modulate = Color(0.5, 0.5, 0.5)
		vbox.add_child(l)
		
	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Capabilities (Methods)
	var cap_title = Label.new()
	cap_title.text = "Capabilities (Behaviors):"
	cap_title.modulate = Color(0.8, 1.0, 0.8)
	vbox.add_child(cap_title)
	
	var methods = script.get_script_method_list()
	var cap_count = 0
	for m in methods:
		var mname = m["name"]
		var desc = ""
		if mname == "on_use": desc = "Provides item use logic."
		elif mname == "before_use": desc = "Can prevent item usage."
		elif mname == "get_runtime_tooltip": desc = "Provides dynamic UI text."
		elif mname == "on_update": desc = "Updates every frame (e.g. decay)."
		elif mname == "get_default_runtime_data": desc = "Initializes unique data per item."
		
		if desc != "":
			var l = Label.new()
			l.text = "  * " + mname + "() -> " + desc
			l.add_theme_font_size_override("font_size", 12)
			vbox.add_child(l)
			cap_count += 1
			
	if cap_count == 0:
		var l = Label.new()
		l.text = "  (Pure data module)"
		l.add_theme_font_size_override("font_size", 12)
		l.modulate = Color(0.5, 0.5, 0.5)
		vbox.add_child(l)
		
	module_list.add_child(panel)
