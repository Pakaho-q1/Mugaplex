extends Node
class_name BuffManager

signal modifiers_changed
signal instant_effect_triggered(effect: BuffEffect, target: Node)
signal buff_applied(effect: BuffEffect)
signal buff_expired(effect: BuffEffect)

# Stores active buffs: Array of Dict {"effect": BuffEffect, "time_left": float, "target": Node}
var active_buffs: Array[Dictionary] = []

func _process(delta: float) -> void:
	var to_remove = []
	var changed = false
	
	for i in range(active_buffs.size()):
		var buff = active_buffs[i]
		buff["time_left"] -= delta
		if buff["time_left"] <= 0.0:
			to_remove.append(i)
			
	# Remove expired buffs in reverse order to keep indices correct
	to_remove.reverse()
	for idx in to_remove:
		var expired = active_buffs[idx]
		active_buffs.remove_at(idx)
		buff_expired.emit(expired["effect"])
		changed = true
		
	if changed:
		modifiers_changed.emit()

func apply_buff(effect: BuffEffect, target: Node) -> void:
	if not effect or not target:
		return
		
	# If duration is 0 or less, it's an instant/one-off effect
	if effect.duration_seconds <= 0.0:
		instant_effect_triggered.emit(effect, target)
		buff_applied.emit(effect)
		return
		
	# Check if this stat target is already buffed on the target
	for buff in active_buffs:
		if buff["effect"].stat_target == effect.stat_target and buff["target"] == target:
			# Refresh the duration
			buff["time_left"] = effect.duration_seconds
			modifiers_changed.emit()
			return
			
	# Apply and store the temporary buff
	active_buffs.append({
		"effect": effect,
		"time_left": effect.duration_seconds,
		"target": target
	})
	
	buff_applied.emit(effect)
	modifiers_changed.emit()

# Sums up all active modifiers of the specified stat type
func get_stat_modifier(stat_type: BuffEffect.StatType, target: Node = null) -> float:
	var total = 0.0
	for buff in active_buffs:
		var effect = buff["effect"]
		if effect.stat_target == stat_type:
			if target == null or buff["target"] == target:
				total += effect.amount
	return total
