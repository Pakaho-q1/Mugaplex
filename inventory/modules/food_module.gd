extends ItemModule
class_name FoodModule

## Amount of health restored when eaten.
@export var health_restore: float = 20.0
## Amount of hunger restored when eaten.
@export var hunger_restore: float = 50.0
## Amount of thirst restored when eaten.
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

