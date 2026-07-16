extends Node
class_name PerishableProcessor

@export var target_inventory: InventoryComponent
@export var update_interval: float = 1.0

var timer: float = 0.0

func _ready():
	if not target_inventory:
		# Try to find via autoload
		target_inventory = InventoryManager.get_player()

func _process(delta: float):
	if not target_inventory:
		return
	
	timer += delta
	if timer >= update_interval:
		timer = 0.0
		target_inventory.update_perishables(update_interval)