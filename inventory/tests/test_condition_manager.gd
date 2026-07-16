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

func test_permanent_and_instant_conditions() -> void:
	var cm = ConditionManager.new()
	var target = Node.new()
	
	# Instant
	var inst = ConditionEffect.new()
	inst.stat_target = "heal"
	inst.duration_seconds = 0.0
	cm.apply_condition(inst, target)
	assert_eq(cm.active_conditions.size(), 0, "Instant effect should not be stored")
	
	# Permanent
	var perm = ConditionEffect.new()
	perm.stat_target = "cursed"
	perm.duration_seconds = -1.0
	cm.apply_condition(perm, target)
	assert_eq(cm.active_conditions.size(), 1, "Permanent effect should be stored")
	
	# Simulate 100 seconds
	cm._process(100.0)
	assert_eq(cm.active_conditions.size(), 1, "Permanent effect should not expire")
	
	cm.free()
	target.free()

func test_math_multiply_and_override() -> void:
	var cm = ConditionManager.new()
	var target = Node.new()
	
	var base_hp = 100.0
	
	# Manually insert active conditions to test math logic 
	# without triggering the uniqueness check of apply_condition
	
	var add20 = ConditionEffect.new()
	add20.stat_target = "hp"
	add20.modifier_type = ConditionEffect.ModifierType.ADD
	add20.amount = 20.0
	cm.active_conditions.append({"effect": add20, "target": target, "current_stacks": 1})
	
	var mul10 = ConditionEffect.new()
	mul10.stat_target = "hp"
	mul10.modifier_type = ConditionEffect.ModifierType.MULTIPLY
	mul10.amount = 0.10
	cm.active_conditions.append({"effect": mul10, "target": target, "current_stacks": 1})
	
	var mul15 = ConditionEffect.new()
	mul15.stat_target = "hp"
	mul15.modifier_type = ConditionEffect.ModifierType.MULTIPLY
	mul15.amount = 0.15
	cm.active_conditions.append({"effect": mul15, "target": target, "current_stacks": 1})
	
	# Math: (100 + 20) * (1.0 + 0.10 + 0.15) = 120 * 1.25 = 150
	assert_eq(cm.get_modified_stat("hp", base_hp, target), 150.0)
	
	# Add OVERRIDE with priority 0
	var over_zero = ConditionEffect.new()
	over_zero.stat_target = "hp"
	over_zero.modifier_type = ConditionEffect.ModifierType.OVERRIDE
	over_zero.amount = 999.0
	over_zero.priority = 0
	cm.active_conditions.append({"effect": over_zero, "target": target, "current_stacks": 1})
	
	assert_eq(cm.get_modified_stat("hp", base_hp, target), 999.0)
	
	# Add OVERRIDE with priority 1 (higher)
	var over_one = ConditionEffect.new()
	over_one.stat_target = "hp"
	over_one.modifier_type = ConditionEffect.ModifierType.OVERRIDE
	over_one.amount = 1.0
	over_one.priority = 1
	cm.active_conditions.append({"effect": over_one, "target": target, "current_stacks": 1})
	
	assert_eq(cm.get_modified_stat("hp", base_hp, target), 1.0)
	
	cm.free()
	target.free()

func test_stacking_math_and_ticks() -> void:
	var cm = ConditionManager.new()
	var target = Node.new()
	
	var poison = ConditionEffect.new()
	poison.stat_target = "poison"
	poison.modifier_type = ConditionEffect.ModifierType.ADD
	poison.amount = -5.0
	poison.duration_seconds = 10.0
	poison.stacking_behavior = ConditionEffect.StackingBehavior.STACK
	poison.max_stacks = 3
	poison.tick_interval = 1.0
	
	# Apply first time -> 1 stack
	cm.apply_condition(poison, target, {"source": "snake"})
	assert_eq(cm.get_modified_stat("poison", 0.0, target), -5.0)
	
	# Apply second time -> 2 stacks
	cm.apply_condition(poison, target, {"source": "spider"})
	assert_eq(cm.get_modified_stat("poison", 0.0, target), -10.0)
	
	# Assert context updated
	assert_eq(cm.active_conditions[0]["user_context"]["source"], "spider")
	
	# Apply third and fourth -> cap at 3 stacks
	cm.apply_condition(poison, target)
	cm.apply_condition(poison, target)
	assert_eq(cm.get_modified_stat("poison", 0.0, target), -15.0)
	
	cm.free()
	target.free()
