extends Resource
class_name StatModule

@export var enabled: bool = true

func apply_modifier(base_value: float, current_value: float, target: Node) -> float:
	return current_value
