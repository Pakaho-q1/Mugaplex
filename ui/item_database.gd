@tool
extends Control

# Folder path where item resource files are saved (ends with /)
@export var item_folder: String = "res://items/"

# Autoload registry path
const REGISTRY_PATH = "res://addons/universal_inventory/item_database_registry.tres"
var registry: ItemDatabaseRegistry = null

@onready var search_input: LineEdit = %SearchInput
@onready var item_list: ItemList = $HSplitContainer/LeftPanel/ItemList
@onready var add_button: Button = $HSplitContainer/LeftPanel/ButtonBox/AddItemButton
@onready var delete_button: Button = $HSplitContainer/LeftPanel/ButtonBox/DeleteItemButton

@onready var placeholder: CenterContainer = %Placeholder
@onready var editor_form: VBoxContainer = %EditorForm

@onready var item_id_input: LineEdit = %ItemIDInput
@onready var item_name_input: LineEdit = %ItemNameInput
@onready var item_desc_input: TextEdit = %ItemDescInput
@onready var icon_preview: TextureRect = %IconPreview
@onready var icon_path_label: Label = %IconPathLabel
@onready var select_icon_btn: Button = %SelectIconBtn

@onready var stackable_check: CheckBox = %StackableCheck
@onready var max_stack_input: SpinBox = %MaxStackInput

@onready var module_list_container: VBoxContainer = %ModuleList
@onready var module_select: OptionButton = %ModuleSelect
@onready var add_module_button: Button = %AddModuleButton

var current_item: ItemData = null
var current_index: int = -1
var is_populating: bool = false # Flag to prevent saving when populating fields

func _ready():
	_ensure_item_folder()
	_ensure_registry()
	_init_module_select()
	
	# Connect search input
	if not search_input.text_changed.is_connected(_on_search_input_text_changed):
		search_input.text_changed.connect(_on_search_input_text_changed)
		
	# Connect buttons
	if not add_button.pressed.is_connected(_on_add_button_pressed):
		add_button.pressed.connect(_on_add_button_pressed)
		
	if not delete_button.pressed.is_connected(_on_delete_button_pressed):
		delete_button.pressed.connect(_on_delete_button_pressed)
		
	if not item_list.item_selected.is_connected(_on_item_list_item_selected):
		item_list.item_selected.connect(_on_item_list_item_selected)
		
	if not select_icon_btn.pressed.is_connected(_on_select_icon_btn_pressed):
		select_icon_btn.pressed.connect(_on_select_icon_btn_pressed)
		
	if not add_module_button.pressed.is_connected(_on_add_module_button_pressed):
		add_module_button.pressed.connect(_on_add_module_button_pressed)
		
	# Connect inputs for auto-saving
	if not item_id_input.text_submitted.is_connected(_on_item_id_submitted):
		item_id_input.text_submitted.connect(_on_item_id_submitted)
	if not item_id_input.focus_exited.is_connected(func(): _on_item_id_submitted(item_id_input.text)):
		item_id_input.focus_exited.connect(func(): _on_item_id_submitted(item_id_input.text))
		
	if not item_name_input.focus_exited.is_connected(_on_item_name_focus_exited):
		item_name_input.focus_exited.connect(_on_item_name_focus_exited)
		
	if not item_desc_input.focus_exited.is_connected(_on_item_desc_focus_exited):
		item_desc_input.focus_exited.connect(_on_item_desc_focus_exited)
		
	if not stackable_check.toggled.is_connected(_on_stackable_toggled):
		stackable_check.toggled.connect(_on_stackable_toggled)
		
	if not max_stack_input.value_changed.is_connected(_on_max_stack_value_changed):
		max_stack_input.value_changed.connect(_on_max_stack_value_changed)
		
	_rebuild_registry()
	refresh_item_list()
	clear_item_details()

func _ensure_item_folder() -> void:
	if not DirAccess.dir_exists_absolute(item_folder):
		DirAccess.make_dir_recursive_absolute(item_folder)

func _ensure_registry() -> void:
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = load(REGISTRY_PATH) as ItemDatabaseRegistry
	if not registry:
		registry = ItemDatabaseRegistry.new()
		ResourceSaver.save(registry, REGISTRY_PATH)

func _rebuild_registry() -> void:
	_ensure_registry()
	registry.rebuild(item_folder)
	ResourceSaver.save(registry, REGISTRY_PATH)

func _init_module_select():
	module_select.clear()
	module_select.add_item("Consumable Module", 0)
	module_select.add_item("Food Module", 1)
	module_select.add_item("Weapon Module", 2)
	module_select.add_item("Armor Module", 3)
	module_select.add_item("Tool Module", 4)
	module_select.add_item("Condition Module", 5)
	module_select.add_item("Perishable Module", 6)

# --- SEARCH & FILTER ---
func _on_search_input_text_changed(new_text: String) -> void:
	refresh_item_list(new_text.strip_edges())

# --- LIST MANAGEMENT ---
func refresh_item_list(filter: String = ""):
	_ensure_item_folder()
	item_list.clear()
	
	var files = DirAccess.get_files_at(item_folder)
	for file_name in files:
		if file_name.ends_with(".tres"):
			var file_path = item_folder.path_join(file_name)
			var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
			if item:
				var match_name = filter == "" or filter.to_lower() in item.display_name.to_lower() or filter.to_lower() in String(item.item_id).to_lower()
				if match_name:
					var display_text = item.display_name
					if item.item_id != &"":
						display_text += " [" + String(item.item_id) + "]"
					
					var idx = item_list.add_item(display_text)
					item_list.set_item_metadata(idx, file_path)
					if item.icon:
						item_list.set_item_icon(idx, item.icon)

func _select_item_by_path(path: String) -> void:
	for i in range(item_list.item_count):
		if item_list.get_item_metadata(i) == path:
			item_list.select(i)
			_on_item_list_item_selected(i)
			break

# --- ADD / DELETE BUTTONS ---
func _on_add_button_pressed():
	var new_item = ItemData.new()
	new_item.display_name = "New Item"
	
	# Generate unique ID and filename
	var base_id = "new_item"
	var clean_id = base_id
	var counter = 1
	
	_ensure_item_folder()
	var file_name = "item_" + clean_id + ".tres"
	var save_path = item_folder.path_join(file_name)
	
	while FileAccess.file_exists(save_path):
		clean_id = base_id + "_" + str(counter)
		file_name = "item_" + clean_id + ".tres"
		save_path = item_folder.path_join(file_name)
		counter += 1
		
	new_item.item_id = StringName(clean_id)
	
	ResourceSaver.save(new_item, save_path)
	
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(0.2).timeout
	
	_rebuild_registry()
	refresh_item_list()
	_select_item_by_path(save_path)

func _on_delete_button_pressed():
	var selected = item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx = selected[0]
	var file_path = item_list.get_item_metadata(idx)
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		EditorInterface.get_resource_filesystem().scan()
		await get_tree().create_timer(0.2).timeout
		
		current_item = null
		current_index = -1
		
		_rebuild_registry()
		refresh_item_list()
		clear_item_details()

# --- ITEM DETAIL RENDERING & FORM BINDING ---
func _on_item_list_item_selected(index: int):
	current_index = index
	var file_path = item_list.get_item_metadata(index)
	var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
	
	if item:
		current_item = item
		EditorInterface.edit_resource(item)
		show_item_details(item)

func show_item_details(item: ItemData):
	is_populating = true
	
	# Identity
	item_id_input.text = String(item.item_id)
	item_name_input.text = item.display_name
	item_desc_input.text = item.description
	
	# Icon
	if item.icon:
		icon_preview.texture = item.icon
		icon_path_label.text = item.icon.resource_path.get_file()
	else:
		icon_preview.texture = null
		icon_path_label.text = "(No Icon Assigned)"
		
	# Stack settings
	stackable_check.button_pressed = item.stackable
	max_stack_input.value = item.max_stack
	max_stack_input.editable = item.stackable
	
	# Render modules
	for child in module_list_container.get_children():
		child.queue_free()
		
	if item.modules.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(No modules attached)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		module_list_container.add_child(empty_label)
	else:
		for module in item.modules:
			var editor = _create_module_editor_ui(module)
			module_list_container.add_child(editor)
			
	placeholder.hide()
	editor_form.show()
	is_populating = false

func clear_item_details():
	placeholder.show()
	editor_form.hide()
	current_item = null
	current_index = -1

func _save_current_item() -> void:
	if is_populating or not current_item:
		return
	if current_item.resource_path != "":
		ResourceSaver.save(current_item, current_item.resource_path)
		_rebuild_registry()

# --- FORM EVENT HANDLERS ---
func _on_item_id_submitted(new_id: String) -> void:
	if is_populating or not current_item:
		return
	new_id = new_id.strip_edges()
	if new_id == "":
		item_id_input.text = String(current_item.item_id)
		return
	
	var clean_id = StringName(new_id)
	if clean_id == current_item.item_id:
		return
		
	# Verify uniqueness / file collision
	var old_path = current_item.resource_path
	var new_filename = "item_" + clean_id + ".tres"
	var new_path = item_folder.path_join(new_filename)
	
	if new_path != old_path and FileAccess.file_exists(new_path):
		printerr("Filename collision: ", new_path)
		item_id_input.text = String(current_item.item_id)
		return
		
	current_item.item_id = clean_id
	_save_current_item()
	
	# Rename file
	if old_path != "" and old_path != new_path:
		var dir = DirAccess.open("res://")
		if dir:
			var err = dir.rename(old_path, new_path)
			if err == OK:
				current_item.resource_path = new_path
				_save_current_item()
				if dir.file_exists(old_path):
					dir.remove(old_path)
				
				EditorInterface.get_resource_filesystem().scan()
				await get_tree().create_timer(0.2).timeout
				
				_rebuild_registry()
				refresh_item_list(search_input.text)
				_select_item_by_path(new_path)
			else:
				printerr("Failed to rename file: ", err)

func _on_item_name_focus_exited() -> void:
	if is_populating or not current_item:
		return
	if current_item.display_name != item_name_input.text:
		current_item.display_name = item_name_input.text
		_save_current_item()
		
		# Refresh listing text
		if current_index != -1:
			var display_text = current_item.display_name
			if current_item.item_id != &"":
				display_text += " [" + String(current_item.item_id) + "]"
			item_list.set_item_text(current_index, display_text)

func _on_item_desc_focus_exited() -> void:
	if is_populating or not current_item:
		return
	if current_item.description != item_desc_input.text:
		current_item.description = item_desc_input.text
		_save_current_item()

func _on_stackable_toggled(button_pressed: bool) -> void:
	if is_populating or not current_item:
		return
	current_item.stackable = button_pressed
	max_stack_input.editable = button_pressed
	_save_current_item()

func _on_max_stack_value_changed(value: float) -> void:
	if is_populating or not current_item:
		return
	current_item.max_stack = int(value)
	_save_current_item()

func _on_select_icon_btn_pressed():
	if not current_item:
		return
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp"]
	file_dialog.file_selected.connect(func(path):
		var texture = load(path)
		if texture:
			current_item.icon = texture
			icon_preview.texture = texture
			icon_path_label.text = path.get_file()
			_save_current_item()
			if current_index != -1:
				item_list.set_item_icon(current_index, texture)
	)
	add_child(file_dialog)
	file_dialog.popup_file_dialog()

# --- DYNAMIC MODULE CREATION & EDITING ---
func _on_add_module_button_pressed():
	if not current_item:
		return
	var selected_idx = module_select.get_selected_id()
	var new_module: ItemModule = null
	
	match selected_idx:
		0: new_module = ConsumableModule.new()
		1: new_module = FoodModule.new()
		2: new_module = WeaponModule.new()
		3: new_module = ArmorModule.new()
		4: new_module = ToolModule.new()
		5: new_module = ConditionModule.new()
		6: new_module = PerishableModule.new()
		
	if new_module:
		current_item.modules.append(new_module)
		_save_current_item()
		show_item_details(current_item)

func _create_module_editor_ui(module: ItemModule) -> Control:
	var panel = PanelContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants_separation = 8
	margin.add_child(vbox)
	
	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = _get_module_name(module)
	title.theme_type_variation = &"HeaderSmall"
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.pressed.connect(func():
		current_item.modules.erase(module)
		_save_current_item()
		show_item_details(current_item)
	)
	header.add_child(remove_btn)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.theme_override_constants_h_separation = 10
	grid.theme_override_constants_v_separation = 8
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	
	# Build module controls
	if module is ConsumableModule:
		var cm = module as ConsumableModule
		_add_spin_box(grid, "Cooldown (s):", cm.cooldown, 0.0, 3600.0, 0.1, func(val): 
			cm.cooldown = val
			_save_current_item()
		)
		_add_checkbox(grid, "Consume on Use:", cm.consume_on_use, func(val):
			cm.consume_on_use = val
			_save_current_item()
		)
	elif module is FoodModule:
		var fm = module as FoodModule
		_add_spin_box(grid, "Health Restore:", fm.health_restore, -9999.0, 9999.0, 1.0, func(val):
			fm.health_restore = val
			_save_current_item()
		)
		_add_spin_box(grid, "Hunger Restore:", fm.hunger_restore, -9999.0, 9999.0, 1.0, func(val):
			fm.hunger_restore = val
			_save_current_item()
		)
		_add_spin_box(grid, "Thirst Restore:", fm.thirst_restore, -9999.0, 9999.0, 1.0, func(val):
			fm.thirst_restore = val
			_save_current_item()
		)
	elif module is WeaponModule:
		var wm = module as WeaponModule
		_add_spin_box(grid, "Physical Damage:", wm.physical_damage, 0.0, 99999.0, 1.0, func(val):
			wm.physical_damage = val
			_save_current_item()
		)
		_add_spin_box(grid, "Attack Speed:", wm.attack_speed, 0.05, 100.0, 0.05, func(val):
			wm.attack_speed = val
			_save_current_item()
		)
	elif module is ArmorModule:
		var am = module as ArmorModule
		_add_spin_box(grid, "Physical Defense:", am.physical_defense, 0.0, 99999.0, 1.0, func(val):
			am.physical_defense = val
			_save_current_item()
		)
		_add_spin_box(grid, "Magic Resistance:", am.magic_resistance, 0.0, 99999.0, 1.0, func(val):
			am.magic_resistance = val
			_save_current_item()
		)
	elif module is ToolModule:
		var tm = module as ToolModule
		_add_enum_dropdown(grid, "Tool Type:", ToolModule.ToolType, tm.tool_type, func(val):
			tm.tool_type = val as ToolModule.ToolType
			_save_current_item()
		)
		_add_spin_box(grid, "Tool Power:", tm.tool_power, 1.0, 100.0, 1.0, func(val):
			tm.tool_power = int(val)
			_save_current_item()
		)
	elif module is PerishableModule:
		var pm = module as PerishableModule
		_add_spin_box(grid, "Freshness Duration (s):", pm.freshness_duration, 1.0, 999999.0, 1.0, func(val):
			pm.freshness_duration = val
			_save_current_item()
		)
		_add_spin_box(grid, "Spoil Chance / Sec:", pm.spoil_chance_per_second, 0.0, 1.0, 0.001, func(val):
			pm.spoil_chance_per_second = val
			_save_current_item()
		)
		_add_item_dropdown(grid, "Spoiled Item:", pm.spoiled_item, func(item):
			pm.spoiled_item = item
			_save_current_item()
		)
		_add_checkbox(grid, "Destroy on Spoil:", pm.destroy_on_spoil, func(val):
			pm.destroy_on_spoil = val
			_save_current_item()
		)
	elif module is ConditionModule:
		var bm = module as ConditionModule
		_build_condition_module_ui(vbox, bm)
		
	return panel

func _add_spin_box(grid: GridContainer, label_text: String, value: float, min_val: float, max_val: float, step: float, callback: Callable) -> void:
	var label = Label.new()
	label.text = label_text
	grid.add_child(label)
	
	var sb = SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step
	sb.value = value
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.value_changed.connect(callback)
	grid.add_child(sb)

func _add_checkbox(grid: GridContainer, label_text: String, value: bool, callback: Callable) -> void:
	var label = Label.new()
	label.text = label_text
	grid.add_child(label)
	
	var cb = CheckBox.new()
	cb.button_pressed = value
	cb.toggled.connect(callback)
	grid.add_child(cb)

func _add_enum_dropdown(grid: GridContainer, label_text: String, enum_dict: Dictionary, current_value: int, callback: Callable) -> void:
	var label = Label.new()
	label.text = label_text
	grid.add_child(label)
	
	var ob = OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var keys = enum_dict.keys()
	for i in range(keys.size()):
		ob.add_item(keys[i], enum_dict[keys[i]])
		if enum_dict[keys[i]] == current_value:
			ob.select(i)
			
	ob.item_selected.connect(callback)
	grid.add_child(ob)

func _add_item_dropdown(grid: GridContainer, label_text: String, current_val: ItemData, callback: Callable) -> void:
	var label = Label.new()
	label.text = label_text
	grid.add_child(label)
	
	var ob = OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_item("None (Null)", -1)
	ob.select(0)
	
	var item_list_data = []
	_ensure_registry()
	
	var idx = 1
	for key in registry.items.keys():
		var it = registry.items[key]
		if it:
			ob.add_item(it.display_name + " (" + String(it.item_id) + ")", idx)
			item_list_data.append(it)
			if current_val and current_val.item_id == it.item_id:
				ob.select(idx)
			idx += 1
			
	ob.item_selected.connect(func(selected_idx):
		if selected_idx == 0:
			callback.call(null)
		else:
			callback.call(item_list_data[selected_idx - 1])
	)
	grid.add_child(ob)

func _build_condition_module_ui(parent_box: VBoxContainer, bm: ConditionModule) -> void:
	var list_container = VBoxContainer.new()
	parent_box.add_child(list_container)
	
	var draw_conditions = Callable()
	draw_conditions = func():
		for child in list_container.get_children():
			child.queue_free()
			
		for i in range(bm.effects.size()):
			var effect = bm.effects[i]
			if not effect:
				continue
				
			var row = HBoxContainer.new()
			row.theme_override_constants_separation = 5
			list_container.add_child(row)
			
			# Stat target line edit
			var stat_le = LineEdit.new()
			stat_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stat_le.text = String(effect.stat_target)
			stat_le.placeholder_text = "e.g. max_health, attack"
			stat_le.text_changed.connect(func(new_text):
				effect.stat_target = StringName(new_text)
				_save_current_item()
			)
			row.add_child(stat_le)
			
			# Amount spinbox
			var amount_sb = SpinBox.new()
			amount_sb.min_value = -9999.0
			amount_sb.max_value = 9999.0
			amount_sb.step = 0.5
			amount_sb.value = effect.amount
			amount_sb.prefix = "Amt:"
			amount_sb.value_changed.connect(func(val):
				effect.amount = val
				_save_current_item()
			)
			row.add_child(amount_sb)
			
			# Duration spinbox
			var dur_sb = SpinBox.new()
			dur_sb.min_value = 0.0
			dur_sb.max_value = 3600.0
			dur_sb.step = 0.5
			dur_sb.value = effect.duration_seconds
			dur_sb.prefix = "Dur:"
			dur_sb.value_changed.connect(func(val):
				effect.duration_seconds = val
				_save_current_item()
			)
			row.add_child(dur_sb)
			
			# Remove button
			var remove_row_btn = Button.new()
			remove_row_btn.text = "X"
			var cached_idx = i
			remove_row_btn.pressed.connect(func():
				bm.effects.remove_at(cached_idx)
				_save_current_item()
				draw_conditions.call()
			)
			row.add_child(remove_row_btn)
			
	draw_conditions.call()
	
	var add_condition_row_btn = Button.new()
	add_condition_row_btn.text = "+ Add Condition Effect"
	add_condition_row_btn.pressed.connect(func():
		var new_effect = ConditionEffect.new()
		new_effect.stat_target = &"max_health"
		new_effect.amount = 10.0
		new_effect.duration_seconds = 10.0
		bm.effects.append(new_effect)
		_save_current_item()
		draw_conditions.call()
	)
	parent_box.add_child(add_condition_row_btn)

func _get_module_name(module: ItemModule) -> String:
	var script = module.get_script()
	if script and script.get_global_name():
		return script.get_global_name()
	return script.resource_path.get_file().trim_suffix(".gd") if script else "ItemModule"
