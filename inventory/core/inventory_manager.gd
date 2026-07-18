extends Node

# --- SIGNALS ---
signal inventory_opened(inventory_component)
signal inventory_closed(inventory_component)

# Global signals for the new Drag & Drop system
signal item_dropped(item: ItemData, amount: int, runtime_data: Dictionary)
signal context_menu_requested(inventory: InventoryComponent, slot_index: int, screen_position: Vector2, button: int)

# --- REGISTRATION ---
var player_inventory: InventoryComponent

func register_player(comp: InventoryComponent) -> void:
	player_inventory = comp

func get_player() -> InventoryComponent:
	return player_inventory
