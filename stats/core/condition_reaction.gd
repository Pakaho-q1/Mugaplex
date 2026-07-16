extends Resource
class_name ConditionReaction

@export var required_conditions: Array[StringName] = []
@export var result_condition: ConditionEffect = null
@export var consume_inputs: bool = true
@export var priority: int = 0
