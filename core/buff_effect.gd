extends Resource
class_name BuffEffect

enum StatType { MAX_HEALTH, CURRENT_HEALTH, SPEED, ATTACK, DEFENSE }

@export var stat_target: StatType = StatType.MAX_HEALTH
@export var amount: float = 10.0
@export var duration_seconds: float = 0.0 # 0 = ส่งผลทันที หรือถาวร
