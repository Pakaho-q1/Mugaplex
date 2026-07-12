extends Node
# ไม่ต้องมี class_name เพราะลงทะเบียนเป็น Autoload ชื่อ InventoryManager แล้ว
# [autoload]
# InventoryManager="*res://addons/universal_inventory/core/inventory_manager.gd"

# กระเป๋าของผู้เล่น — ให้ Player เรียก InventoryManager.register_player(self) ตอน _ready
signal inventory_opened(inventory_component)
signal inventory_closed(inventory_component)
signal item_dropped(item: ItemData, amount: int, runtime_data: Dictionary)

var player_inventory: InventoryComponent

func register_player(comp: InventoryComponent) -> void:
	player_inventory = comp

func get_player() -> InventoryComponent:
	return player_inventory
