extends TestSuite
class_name TestConditionManager

func _init() -> void:
	suite_name = "ConditionManager"

func test_apply_condition_stores_condition() -> void:
	var cm = ConditionManager.new()
	var target = Node.new()
	
	var ce = ConditionEffect.new()
	ce.stat_target = "wet"
	ce.amount = 0.0
	ce.duration_seconds = 10.0
	
	cm.apply_condition(ce, target)
	
	assert_eq(cm.active_conditions.size(), 1)
	assert_eq(cm.active_conditions[0]["effect"].stat_target, "wet")
	assert_eq(cm.active_conditions[0]["target"], target)
	
	cm.free()
	target.free()

func test_condition_manager_processes_reactions() -> void:
	var cm = ConditionManager.new()
	var target = Node.new()
	var registry = ReactionRegistry.new()
	
	var reaction = ConditionReaction.new()
	var req: Array[StringName] = [&"wet", &"burning"]
	reaction.required_conditions = req
	reaction.consume_inputs = true
	var steam = ConditionEffect.new()
	steam.stat_target = "steam"
	steam.duration_seconds = 5.0
	reaction.result_condition = steam
	
	registry.reactions.append(reaction)
	cm.reaction_registry = registry
	
	# Apply wet
	var wet = ConditionEffect.new()
	wet.stat_target = "wet"
	wet.duration_seconds = 10.0
	cm.apply_condition(wet, target)
	
	assert_eq(cm.active_conditions.size(), 1, "Should have wet condition")
	
	# Apply burning, should trigger reaction
	var burning = ConditionEffect.new()
	burning.stat_target = "burning"
	burning.duration_seconds = 10.0
	cm.apply_condition(burning, target)
	
	assert_eq(cm.active_conditions.size(), 1, "Inputs consumed, only steam remains")
	assert_eq(cm.active_conditions[0]["effect"].stat_target, "steam", "Result is steam")
	
	cm.free()
	target.free()
