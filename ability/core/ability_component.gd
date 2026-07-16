extends Node
class_name AbilityComponent

signal ability_cast(ability: AbilityData)
signal ability_cooldown_started(ability_id: StringName, time: float)
signal ability_cooldown_finished(ability_id: StringName)

@export var abilities: Array[AbilityData] = []

var _cooldowns: Dictionary = {}

func _process(delta: float) -> void:
	var finished_keys = []
	for ability_id in _cooldowns.keys():
		_cooldowns[ability_id] -= delta
		if _cooldowns[ability_id] <= 0:
			finished_keys.append(ability_id)
			
	for key in finished_keys:
		_cooldowns.erase(key)
		ability_cooldown_finished.emit(key)

func has_ability(ability_id: StringName) -> bool:
	for a in abilities:
		if a and a.ability_id == ability_id:
			return true
	return false

func get_ability(ability_id: StringName) -> AbilityData:
	for a in abilities:
		if a and a.ability_id == ability_id:
			return a
	return null

func is_on_cooldown(ability_id: StringName) -> bool:
	return _cooldowns.has(ability_id) and _cooldowns[ability_id] > 0

func get_cooldown_left(ability_id: StringName) -> float:
	return _cooldowns.get(ability_id, 0.0)

func cast_ability(ability_id: StringName, target: Node = null) -> Dictionary:
	var result = {"success": false, "message": ""}
	
	if is_on_cooldown(ability_id):
		result.message = "Ability is on cooldown"
		return result
		
	var ability = get_ability(ability_id)
	if not ability:
		result.message = "Ability not found"
		return result
		
	# Process cost (e.g., checking StatsComponent for Mana)
	var stats = get_parent().get_node_or_null("StatsComponent")
	if stats and ability.mana_cost > 0:
		var current_mp = stats.get_stat("mp") # Assuming MP exists
		if current_mp < ability.mana_cost:
			result.message = "Not enough mana"
			return result
		stats.set_base_stat("mp", current_mp - ability.mana_cost)
		
	# Execute modules
	var runtime_data = {}
	for mod in ability.modules:
		if mod and mod.enabled:
			mod.on_cast(get_parent(), target, runtime_data)
			
	# Start cooldown
	if ability.cooldown_time > 0:
		_cooldowns[ability_id] = ability.cooldown_time
		ability_cooldown_started.emit(ability_id, ability.cooldown_time)
		
	ability_cast.emit(ability)
	
	result.success = true
	result.message = "Cast successful"
	return result
