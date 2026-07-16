extends ItemModule
class_name ContainerModule

## Max slots of the nested inventory.
@export var max_slots: int = 10
## Max weight of the nested inventory. 0.0 = unlimited.
@export var max_weight: float = 0.0
## If true, this container's own ItemData.weight is used regardless of contents ("bag of holding").
## If false (project default), get_total_weight() on the parent inventory adds
## the recursive contents weight on top of the container item's own weight.
@export var fixed_weight: bool = false

func get_default_runtime_data() -> Dictionary:
	return {
		"container_slots": [],   # Array of serialized InventorySlot dicts
		"instance_id": randi(),  # unique per physical instance — NOT the item_id
	}

func on_use(runtime_data: Dictionary, user_context: Dictionary) -> Dictionary:
	return {
		"consumed": false,
		"payload": {
			"action": "open_container",
			"slots": runtime_data.get("container_slots", []),
			"instance_id": runtime_data.get("instance_id", -1),
			"max_slots": max_slots,
			"max_weight": max_weight,
		}
	}

func get_runtime_tooltip(runtime_data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var slot_count = runtime_data.get("container_slots", []).size()
	var used = 0
	for s in runtime_data.get("container_slots", []):
		if s != null and s.get("item_id", "") != "":
			used += 1
	lines.append("• Container: %d/%d slots used" % [used, max_slots])
	return lines
