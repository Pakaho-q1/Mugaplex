extends Node
class_name StatsComponent

signal stat_changed(stat_name: String, new_value: float)

@export_group("Base Stats")
@export var base_stats: Dictionary = {
	"hp": 100.0,
	"max_hp": 100.0,
	"atk": 10.0,
	"def": 5.0,
	"speed": 100.0
}

@export_group("Modifiers")
## Add static modifiers here (e.g., racial traits, permanent buffs)
@export var base_modules: Array[StatModule] = []

@onready var condition_manager = get_node_or_null("ConditionManager")

func get_stat(stat_name: String) -> float:
	var base = base_stats.get(stat_name, 0.0)
	var current = base
	
	# Apply static base modules
	for mod in base_modules:
		if mod and mod.enabled:
			current = mod.apply_modifier(base, current, self)
			
	# Apply dynamic conditions (buffs/debuffs) if ConditionManager exists
	if condition_manager and condition_manager.has_method("get_modified_stat"):
		current = condition_manager.get_modified_stat(stat_name, current, self)
		
	return current

func set_base_stat(stat_name: String, value: float) -> void:
	base_stats[stat_name] = value
	stat_changed.emit(stat_name, get_stat(stat_name))
