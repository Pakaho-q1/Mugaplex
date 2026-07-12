extends PanelContainer

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel

var slot_index: int = -1
var inventory_component: InventoryComponent = null
var inventory_ui: Control = null # Parent layout manager

# --- อัปเดตการแสดงผล (ตามข้อมูลที่ได้รับจาก Data) ---
func update_slot(slot_data: InventorySlot, index: int, comp: InventoryComponent, ui_manager: Control):
	slot_index = index
	inventory_component = comp
	inventory_ui = ui_manager
	
	if slot_data == null:
		_clear_display()
		return
		
	# วาดหน้าจอโดยอ้างอิงจากข้อมูลช่องหลักจริง (กรณีโดนจอง)
	var owning_slot = slot_data.get_owning_slot()
	if owning_slot.item == null or slot_data.is_occupied_cell():
		_clear_display()
		if slot_data.is_occupied_cell():
			# แสดงผลเป็นช่องที่โดนจอง (อาจจะวาดทับด้วยสีอื่น/ว่างเปล่า)
			tooltip_text = "Reserved cell"
	else:
		icon.texture = owning_slot.item.icon
		tooltip_text = owning_slot.item.display_name # เปิดการใช้งาน Tooltip ของ Godot
		if owning_slot.amount > 1:
			amount_label.text = str(owning_slot.amount)
		else:
			amount_label.text = ""

func _clear_display():
	icon.texture = null
	amount_label.text = ""
	tooltip_text = ""

# --- การคลิกเพื่อขอใช้งานไอเทม (ส่งต่อคำขอ) ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_request_use()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_request_use()

func _request_use() -> void:
	if slot_index != -1 and inventory_ui and inventory_ui.has_method("request_use"):
		inventory_ui.request_use(slot_index)

# --- ระบบ DRAG & DROP (ถามสิทธิ์จาก Data และส่งต่อผลลัพธ์) ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_index == -1 or not inventory_component:
		return null
		
	var slot_data = inventory_component.slots[slot_index]
	var owning_slot = slot_data.get_owning_slot()
	
	if owning_slot.item == null:
		return null
		
	# สร้างรูปพรีวิวติดตามเมาส์
	var preview_texture = TextureRect.new()
	preview_texture.texture = owning_slot.item.icon
	preview_texture.custom_minimum_size = Vector2(64, 64)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var preview_control = Control.new()
	preview_texture.position = -preview_texture.custom_minimum_size / 2
	preview_control.add_child(preview_texture)
	set_drag_preview(preview_control)
	
	# หา Index ของสล็อตหลักตัวจริงเพื่อส่งเป็นข้อมูลลาก
	var owning_index = inventory_component.slots.find(owning_slot)
	return {"source_index": owning_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("source_index"):
		return false
		
	var source_idx = data["source_index"]
	if source_idx == slot_index:
		return false
		
	if not inventory_component or slot_index >= inventory_component.slots.size():
		return false
		
	# ยืมถามสิทธิ์ (can_accept) จากข้อมูลสล็อตจริงฝั่ง Data
	var source_item = inventory_component.slots[source_idx].item
	var target_slot_data = inventory_component.slots[slot_index]
	
	return target_slot_data.can_accept(source_item)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_idx = data["source_index"]
	if inventory_ui and inventory_ui.has_method("request_move"):
		inventory_ui.request_move(source_idx, slot_index)

# --- ระบบสร้าง Tooltip ตามโมดูลของไอเทม (Pure UI Representation) ---
func _make_custom_tooltip(_for_text: String) -> Control:
	if slot_index == -1 or not inventory_component:
		return null
		
	var slot_data = inventory_component.slots[slot_index]
	var owning_slot = slot_data.get_owning_slot()
	if not owning_slot or not owning_slot.item:
		return null
		
	var item = owning_slot.item
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.25, 0.35)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.theme_override_constants_separation = 4
	panel.add_child(vbox)
	
	# ชื่อไอเทม
	var title = Label.new()
	title.text = item.display_name
	title.theme_type_variation = &"HeaderSmall"
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(title)
	
	# คำอธิบาย
	if item.description != "":
		var desc = Label.new()
		desc.text = item.description
		desc.add_theme_font_size_override("font_size", 11)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(desc)
		
	vbox.add_child(HSeparator.new())
	
	# รายละเอียดโมดูล (สืบค้นผ่าน Reflection)
	var has_modules_info = false
	for module in item.modules:
		if not module:
			continue
			
		var mod_script = module.get_script()
		var mod_name = mod_script.resource_path.get_file().get_basename().capitalize()
		
		var props_text = []
		for prop in module.get_property_list():
			if prop.name in ["resource_path", "resource_name", "resource_local_to_scene", "script", "resource_scene_unique_id"]:
				continue
			if prop.name.begins_with("_"):
				continue
				
			var val = module.get(prop.name)
			if val != null and str(val) != "<null>":
				var prop_label = prop.name.capitalize().replace("_", " ")
				if val is Resource and "display_name" in val:
					props_text.append("• %s: %s" % [prop_label, val.display_name])
				else:
					props_text.append("• %s: %s" % [prop_label, str(val)])
				
		if not props_text.is_empty():
			has_modules_info = true
			var mod_label = Label.new()
			mod_label.text = mod_name
			mod_label.add_theme_font_size_override("font_size", 11)
			mod_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
			vbox.add_child(mod_label)
			
			var prop_label = Label.new()
			prop_label.text = "\n".join(props_text)
			prop_label.add_theme_font_size_override("font_size", 10)
			prop_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			vbox.add_child(prop_label)
			
	# ข้อมูลความทนทาน/ความเน่าเสียชั่วขณะ
	var runtime_lines = []
	for module in item.modules:
		if module.has_method("get_runtime_tooltip"):
			runtime_lines.append_array(module.get_runtime_tooltip(owning_slot.runtime_data))
			
	if not runtime_lines.is_empty():
		if has_modules_info:
			vbox.add_child(HSeparator.new())
		var rt_title = Label.new()
		rt_title.text = "Runtime Data"
		rt_title.add_theme_font_size_override("font_size", 11)
		rt_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		vbox.add_child(rt_title)
		
		var rt_label = Label.new()
		rt_label.text = "\n".join(runtime_lines)
		rt_label.add_theme_font_size_override("font_size", 10)
		rt_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		vbox.add_child(rt_label)
		
	return panel
