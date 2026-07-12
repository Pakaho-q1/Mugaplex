extends ItemModule
class_name ToolModule

enum ToolType { AXE, PICKAXE, HAMMER, WATERING_CAN, HOE, FISHING_ROD }

@export var tool_type: ToolType = ToolType.AXE
@export var tool_power: int = 1
