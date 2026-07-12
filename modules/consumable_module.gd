extends ItemModule
class_name ConsumableModule

@export var cooldown: float = 1.0
@export var consume_on_use: bool = true # ติ๊กบอกว่าใช้แล้วของหายไป 1 ชิ้น

func on_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	return {"consumed": consume_on_use, "payload": {"action": "consume"}}
