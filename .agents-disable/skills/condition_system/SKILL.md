---
name: Use Universal Inventory Condition System
description: "Guidelines for applying buffs, debuffs, and querying stats using the ConditionManager."
---

# Condition System (ConditionManager)
The `ConditionManager` is an advanced stat-modifier and state tracking system handling ADD, MULTIPLY, OVERRIDE logic as well as stacking and periodic ticks.

## Rules
- When writing logic that checks a character's final stats, always query `ConditionManager.get_modified_stat()`.
- Pass a `base_value` to `get_modified_stat()`, it will calculate `(base_value + ADD) * MULTIPLY` or use the `OVERRIDE` with the highest priority.
- Permanent conditions should have `duration_seconds = -1.0`. Instant conditions have `duration_seconds = 0.0`.
- Provide `user_context` (e.g. `{"source": enemy_node}`) to `apply_condition` if you need to track who caused the effect.

## Snippets

### Applying a Condition
```gdscript
var poison = ConditionEffect.new()
poison.stat_target = "poison"
poison.modifier_type = ConditionEffect.ModifierType.ADD
poison.amount = -5.0
poison.duration_seconds = 10.0
poison.tick_interval = 1.0
poison.stacking_behavior = ConditionEffect.StackingBehavior.STACK

condition_manager.apply_condition(poison, target_node, {"source": self})
```

### Checking for Tags
```gdscript
if condition_manager.has_condition("wet", target_node):
    print("Target is wet!")
```

### Retrieving a Modified Stat
```gdscript
var base_speed = 300.0
var final_speed = condition_manager.get_modified_stat("speed", base_speed, self)
```
