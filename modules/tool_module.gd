extends ItemModule
class_name ToolModule

enum ToolType { AXE, PICKAXE, HAMMER, WATERING_CAN, HOE, FISHING_ROD }

## The type of tool this is.
@export var tool_type: ToolType = ToolType.AXE
## The strength of the tool. Higher power can harvest tougher resources.
@export var tool_power: int = 1
