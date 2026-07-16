extends Node
class_name ConditionManager

signal conditions_changed
signal instant_effect_triggered(effect: ConditionEffect, target: Node, user_context: Dictionary)
signal condition_applied(effect: ConditionEffect, target: Node, user_context: Dictionary)
signal condition_expired(effect: ConditionEffect, target: Node, user_context: Dictionary)
signal condition_ticked(effect: ConditionEffect, target: Node, current_stacks: int, user_context: Dictionary)

@export var reaction_registry: ReactionRegistry

# Stores active conditions: Array of Dict 
# { "effect": ConditionEffect, "time_left": float, "target": Node, "current_stacks": int, "time_since_last_tick": float, "user_context": Dictionary }
var active_conditions: Array[Dictionary] = []

func _process(delta: float) -> void:
	var to_remove = []
	var changed = false
	
	for i in range(active_conditions.size()):
		var cond = active_conditions[i]
		
		# Process ticks if applicable
		var effect: ConditionEffect = cond["effect"]
		if effect.tick_interval > 0.0:
			cond["time_since_last_tick"] += delta
			if cond["time_since_last_tick"] >= effect.tick_interval:
				cond["time_since_last_tick"] = 0.0
				condition_ticked.emit(effect, cond["target"], cond["current_stacks"], cond["user_context"])
		
		# Process expiration for temporary conditions
		if effect.duration_seconds > 0.0:
			cond["time_left"] -= delta
			if cond["time_left"] <= 0.0:
				to_remove.append(i)
			
	# Remove expired conditions in reverse order
	to_remove.reverse()
	for idx in to_remove:
		var expired = active_conditions[idx]
		active_conditions.remove_at(idx)
		condition_expired.emit(expired["effect"], expired["target"], expired["user_context"])
		changed = true
		
	if changed:
		conditions_changed.emit()

func apply_condition(effect: ConditionEffect, target: Node, user_context: Dictionary = {}) -> void:
	if not effect or not target:
		return
		
	# If duration is 0, it's an instant/one-off effect
	if effect.duration_seconds == 0.0:
		instant_effect_triggered.emit(effect, target, user_context)
		condition_applied.emit(effect, target, user_context)
		return
		
	# Check if this stat target is already active on the target
	for cond in active_conditions:
		if cond["effect"].stat_target == effect.stat_target and cond["target"] == target:
			if effect.stacking_behavior == ConditionEffect.StackingBehavior.IGNORE:
				return
			elif effect.stacking_behavior == ConditionEffect.StackingBehavior.REFRESH:
				cond["time_left"] = effect.duration_seconds
				cond["user_context"] = user_context
				cond["effect"] = effect # Update effect instance in case amounts differ
			elif effect.stacking_behavior == ConditionEffect.StackingBehavior.STACK:
				cond["time_left"] = effect.duration_seconds
				cond["user_context"] = user_context
				cond["effect"] = effect
				cond["current_stacks"] = min(cond["current_stacks"] + 1, effect.max_stacks)
				
			conditions_changed.emit()
			return
			
	# Apply and store the condition (temporary or permanent)
	active_conditions.append({
		"effect": effect,
		"time_left": effect.duration_seconds,
		"target": target,
		"current_stacks": 1,
		"time_since_last_tick": 0.0,
		"user_context": user_context
	})
	
	condition_applied.emit(effect, target, user_context)
	conditions_changed.emit()
	
	# Check for Reactions
	_check_reactions(target, user_context)

func _check_reactions(target: Node, user_context: Dictionary) -> void:
	if not reaction_registry:
		return
		
	var active_names: Array[StringName] = []
	for cond in active_conditions:
		if cond["target"] == target:
			active_names.append(cond["effect"].stat_target)
			
	var reaction = reaction_registry.find_reaction(active_names)
	if reaction:
		# Consume inputs
		if reaction.consume_inputs:
			var to_remove = []
			for i in range(active_conditions.size()):
				if active_conditions[i]["target"] == target and reaction.required_conditions.has(active_conditions[i]["effect"].stat_target):
					to_remove.append(i)
			to_remove.reverse()
			for idx in to_remove:
				var expired = active_conditions[idx]
				active_conditions.remove_at(idx)
				condition_expired.emit(expired["effect"], expired["target"], expired["user_context"])
				
		# Apply result condition
		if reaction.result_condition:
			apply_condition(reaction.result_condition, target, user_context)

func has_condition(stat_target: StringName, target: Node = null) -> bool:
	for cond in active_conditions:
		if cond["effect"].stat_target == stat_target:
			if target == null or cond["target"] == target:
				return true
	return false

func get_modified_stat(stat_type: StringName, base_value: float, target: Node = null) -> float:
	var total_add = 0.0
	var total_multiply = 0.0
	var has_override = false
	var override_value = 0.0
	var highest_priority = -999999
	
	# Collect all relevant conditions
	for cond in active_conditions:
		var effect: ConditionEffect = cond["effect"]
		if effect.stat_target == stat_type:
			if target == null or cond["target"] == target:
				var effective_amount = effect.amount * cond["current_stacks"]
				
				match effect.modifier_type:
					ConditionEffect.ModifierType.ADD:
						total_add += effective_amount
					ConditionEffect.ModifierType.MULTIPLY:
						total_multiply += effective_amount
					ConditionEffect.ModifierType.OVERRIDE:
						# Highest priority wins. If tied, sequential override (latest wins)
						if effect.priority >= highest_priority:
							highest_priority = effect.priority
							override_value = effect.amount
							has_override = true

	if has_override:
		return override_value
		
	return (base_value + total_add) * (1.0 + total_multiply)
