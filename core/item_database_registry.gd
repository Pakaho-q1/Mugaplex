@tool
extends Resource
class_name ItemDatabaseRegistry

# Dictionary mapping item_id (StringName) -> ItemData (Resource)
@export var items: Dictionary = {}

# Retrieves an ItemData by its ID
func get_item(item_id: StringName) -> ItemData:
	return items.get(item_id, null)

# Scans the specified folder and rebuilds the registry mapping
func rebuild(item_folder: String) -> void:
	items.clear()
	if not DirAccess.dir_exists_absolute(item_folder):
		return
		
	var files = DirAccess.get_files_at(item_folder)
	for file_name in files:
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var file_path = item_folder.path_join(file_name)
			var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemData
			if item:
				item.validate_modules()
				if item.item_id != &"":
					items[item.item_id] = item
				else:
					# Use filename without extension if item_id is empty
					var fallback_id = StringName(file_name.get_basename())
					items[fallback_id] = item
