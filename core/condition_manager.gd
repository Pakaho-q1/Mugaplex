extends Node
class_name ConditionManager

signal conditions_changed
signal instant_effect_triggered(effect: ConditionEffect, target: Node)
signal condition_applied(effect: ConditionEffect)
signal condition_expired(effect: ConditionEffect)

@export var reaction_registry: ReactionRegistry

# Stores active conditions: Array of Dict {"effect": ConditionEffect, "time_left": float, "target": Node}
var active_conditions: Array[Dictionary] = []

func _process(delta: float) -> void:
	var to_remove = []
	var changed = false
	
	for i in range(active_conditions.size()):
		var cond = active_conditions[i]
		cond["time_left"] -= delta
		if cond["time_left"] <= 0.0:
			to_remove.append(i)
			
	# Remove expired conditions in reverse order to keep indices correct
	to_remove.reverse()
	for idx in to_remove:
		var expired = active_conditions[idx]
		active_conditions.remove_at(idx)
		condition_expired.emit(expired["effect"])
		changed = true
		
	if changed:
		conditions_changed.emit()

func apply_condition(effect: ConditionEffect, target: Node) -> void:
	if not effect or not target:
		return
		
	# If duration is 0 or less, it's an instant/one-off effect
	if effect.duration_seconds <= 0.0:
		instant_effect_triggered.emit(effect, target)
		condition_applied.emit(effect)
		return
		
	# Check if this stat target is already active on the target
	for cond in active_conditions:
		if cond["effect"].stat_target == effect.stat_target and cond["target"] == target:
			# Refresh the duration
			cond["time_left"] = effect.duration_seconds
			conditions_changed.emit()
			return
			
	# Apply and store the temporary condition
	active_conditions.append({
		"effect": effect,
		"time_left": effect.duration_seconds,
		"target": target
	})
	
	condition_applied.emit(effect)
	conditions_changed.emit()
	
	# Check for Reactions
	_check_reactions(target)

func _check_reactions(target: Node) -> void:
	if not reaction_registry:
		return
		
	# รวบรวมรายชื่อ condition ปัจจุบัน
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
				condition_expired.emit(expired["effect"])
				
		# Apply result condition
		if reaction.result_condition:
			apply_condition(reaction.result_condition, target)

# Sums up all active modifiers of the specified stat type
func get_stat_modifier(stat_type: StringName, target: Node = null) -> float:
	var total = 0.0
	for cond in active_conditions:
		var effect = cond["effect"]
		if effect.stat_target == stat_type:
			if target == null or cond["target"] == target:
				total += effect.amount
	return total
