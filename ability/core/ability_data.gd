extends Resource
class_name AbilityData

@export var ability_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Usage")
@export var cooldown_time: float = 1.0
@export var mana_cost: float = 0.0

@export_group("Behaviors")
## The modules that define what this ability actually does when cast.
## Notice that Godot Inspector will only allow classes extending 'AbilityModule' here.
@export var modules: Array[AbilityModule] = []
