extends "res://addons/mugaplex/inventory/tests/test_framework.gd"

var inv: InventoryComponent
var wrapper: Node

func before_each():
	inv = InventoryComponent.new()
	inv.max_slots = 10
	inv._ready()
	
	var wrapper_script = preload("res://addons/mugaplex/inventory/network/inventory_network_wrapper.gd")
	assert_not_null(wrapper_script, "Wrapper script failed to load!")
	wrapper = wrapper_script.new()
	assert_not_null(wrapper, "Wrapper failed to instantiate!")
	wrapper.inventory = inv
	
	# ต้อง Add Child เข้า Tree เผื่อใช้คำสั่ง RPC/Multiplayer
	Engine.get_main_loop().root.add_child(inv)
	Engine.get_main_loop().root.add_child(wrapper)
	wrapper._ready()

func after_each():
	if wrapper.is_inside_tree():
		wrapper.get_parent().remove_child(wrapper)
	wrapper.queue_free()
	
	if inv.is_inside_tree():
		inv.get_parent().remove_child(inv)
	inv.queue_free()

func test_add_viewer_adds_to_list():
	before_each()
	# In offline mode, multiplayer.is_server() is true by default
	wrapper.add_viewer(2)
	assert_true(wrapper.viewers.has(2), "Viewer should be added")
	after_each()
	
func test_remove_viewer_removes_from_list():
	before_each()
	wrapper.add_viewer(2)
	wrapper.remove_viewer(2)
	assert_false(wrapper.viewers.has(2), "Viewer should be removed")
	after_each()

func test_request_move_item_as_host_works():
	before_each()
	# Create dummy item
	var item = ItemData.new()
	item.item_id = "test_item"
	item.grid_size = Vector2(1, 1)
	
	inv.slots[0].item = item
	inv.slots[0].amount = 1
	inv._set_occupied(0, item, false)
	
	# Mock sender id bypassing
	wrapper.add_viewer(0) # 0 is local sender when calling without RPC
	
	wrapper.request_move_item(0, 5)
	
	assert_null(inv.slots[0].item, "Item should have moved from slot 0")
	assert_not_null(inv.slots[5].item, "Item should be in slot 5")
	after_each()
