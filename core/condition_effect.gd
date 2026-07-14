extends Resource
class_name ConditionEffect

enum ModifierType { ADD, MULTIPLY, OVERRIDE }
enum StackingBehavior { REFRESH, STACK, IGNORE }

@export var stat_target: StringName = &"max_health"
@export var modifier_type: ModifierType = ModifierType.ADD
@export var amount: float = 10.0
@export var priority: int = 0

## Duration of the condition. 
## == 0.0: Instant effect
## > 0.0: Temporary effect
## < 0.0: Permanent effect (until manually removed or consumed by reaction)
@export var duration_seconds: float = 0.0 

## Interval for periodic effects. If > 0.0, condition_ticked will be emitted.
@export var tick_interval: float = 0.0

@export var stacking_behavior: StackingBehavior = StackingBehavior.REFRESH
@export var max_stacks: int = 1
