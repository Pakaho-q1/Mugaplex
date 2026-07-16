@tool
extends EditorPlugin

var main_panel_instance: Control

func _enter_tree():
	# โหลด Scene UI ที่เราเพิ่งสร้าง
	var gui_scene = preload("res://addons/mugaplex/inventory/ui/item_database.tscn")
	main_panel_instance = gui_scene.instantiate()
	
	# เอาไปแปะไว้ที่ Main Screen (หน้าเดียวกับ 2D, 3D, Script)
	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	_make_visible(false) # ซ่อนไว้ก่อนจนกว่าจะกดแท็บ

func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()

# บอก Godot ว่า Plugin นี้ขอพื้นที่ Main Screen นะ
func _has_main_screen() -> bool:
	return true

# ชื่อที่จะโผล่บนแท็บด้านบน
func _get_plugin_name() -> String:
	return "Item DB"

# ระบบสลับหน้าจอ (โชว์/ซ่อน)
func _make_visible(visible: bool):
	if main_panel_instance:
		main_panel_instance.visible = visible
