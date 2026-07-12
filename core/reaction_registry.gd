@tool
extends Resource
class_name ReactionRegistry

@export var reactions: Array[ConditionReaction] = []

# หารีแอคชั่นที่ตรงกับเงื่อนไขที่มีอยู่ทั้งหมด (เรียงตาม priority)
func find_reaction(active_condition_names: Array[StringName]) -> ConditionReaction:
	var best_reaction: ConditionReaction = null
	
	for reaction in reactions:
		if not reaction or not reaction.result_condition:
			continue
			
		# เช็คว่ามี required conditions ครบหรือไม่
		var has_all = true
		for req in reaction.required_conditions:
			if not active_condition_names.has(req):
				has_all = false
				break
				
		if has_all:
			if best_reaction == null or reaction.priority > best_reaction.priority:
				best_reaction = reaction
				
	return best_reaction
