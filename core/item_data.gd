extends Resource
class_name ItemData

# ซิกเนลของตัวเอง (ยิงผ่าน notify_changed() เมื่อแก้ผ่านโค้ด)
# Inspector จะยิง changed เองอัตโนมัติ — item_database จะเชื่อมทั้งคู่
signal data_changed

@export_group("Identity")
@export var item_id: StringName = ""
@export var display_name: String = "New Item"
@export_multiline var description: String = ""

@export_group("Visual")
@export var icon: Texture2D

@export_group("Inventory")
@export var stackable: bool = false
@export_range(1, 9999) var max_stack: int = 99
@export var grid_size: Vector2i = Vector2i(1, 1)

@export_group("Modules")
# ตัวแปรนี้จะเก็บ Array ของโมดูลที่เราสร้างขึ้นมา
@export var modules: Array[ItemModule] = []

# ฟังก์ชันสำหรับเช็กและดึงโมดูลไปใช้งาน
func get_module(module_class: Script) -> ItemModule:
	for module in modules:
		if module != null and is_instance_of(module, module_class):
			return module
	return null

# เรียกหลังแก้ค่าผ่านโค้ด (เช่น item.stackable = true; item.notify_changed())
func notify_changed() -> void:
	data_changed.emit()

# ระบบตรวจจับความขัดแย้งของโมดูล (Module Resolution Validation)
func validate_modules() -> void:
	var seen_classes = {}
	for module in modules:
		if module == null:
			continue
		
		# ดึงชื่อคลาสของสคริปต์
		var script = module.get_script()
		if not script:
			continue
			
		var class_path = script.resource_path
		if seen_classes.has(class_path):
			push_warning("Item '%s' (ID: %s) มีโมดูลชนิดเดียวกัน (%s) ซ้อนทับกันอยู่! โปรดระวังพฤติกรรม Overwrite ตามนโยบาย Sequential Override" % [display_name, item_id, class_path.get_file()])
		else:
			seen_classes[class_path] = true
