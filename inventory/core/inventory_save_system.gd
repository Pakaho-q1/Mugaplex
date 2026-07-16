extends RefCounted
class_name InventorySaveSystem

# Saves inventory and optional equipment data to a JSON file
static func save_to_file(file_path: String, inventory: InventoryComponent, equipment: EquipmentComponent = null) -> Error:
	if not inventory:
		return ERR_INVALID_PARAMETER
		
	var save_data = {
		"inventory": inventory.serialize()
	}
	
	if equipment:
		save_data["equipment"] = equipment.serialize()
		
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		var err = FileAccess.get_open_error()
		printerr("InventorySaveSystem: Failed to open save file for writing: ", file_path, " (Error: ", err, ")")
		return err
		
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	return OK

# Loads inventory and optional equipment data from a JSON file
static func load_from_file(file_path: String, inventory: InventoryComponent, equipment: EquipmentComponent = null) -> Error:
	if not inventory:
		return ERR_INVALID_PARAMETER
		
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var err = FileAccess.get_open_error()
		printerr("InventorySaveSystem: Failed to open save file for reading: ", file_path, " (Error: ", err, ")")
		return err
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		printerr("InventorySaveSystem: JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return err
		
	var save_data = json.data
	if not save_data is Dictionary:
		printerr("InventorySaveSystem: Invalid save data format (expected Dictionary)")
		return ERR_FILE_CORRUPT
		
	if save_data.has("inventory") and save_data["inventory"] is Array:
		inventory.deserialize(save_data["inventory"])
		
	if equipment and save_data.has("equipment") and save_data["equipment"] is Dictionary:
		equipment.deserialize(save_data["equipment"])
		
	return OK
