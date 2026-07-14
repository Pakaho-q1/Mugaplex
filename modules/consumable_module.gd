extends ItemModule
class_name ConsumableModule

## Time in seconds before this item can be consumed again.
@export var cooldown: float = 1.0
## If true, one stack of the item is destroyed upon use.
@export var consume_on_use: bool = true

func on_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	return {"consumed": consume_on_use, "payload": {"action": "consume"}}

