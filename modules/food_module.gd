extends ItemModule
class_name FoodModule

@export var health_restore: float = 20.0
@export var hunger_restore: float = 50.0
@export var thirst_restore: float = 0.0

func on_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	return {
		"consumed": true, 
		"payload": {
			"action": "restore_stats",
			"health": health_restore,
			"hunger": hunger_restore,
			"thirst": thirst_restore
		}
	}
