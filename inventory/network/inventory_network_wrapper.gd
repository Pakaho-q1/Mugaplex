class_name InventoryNetworkWrapper
extends Node

## Wrapper สำหรับจัดการระบบ Network ของ InventoryComponent
## ทำงานภายใต้สถาปัตยกรรม Listen Server (Host-Client) หรือ Dedicated Server

@export var inventory: InventoryComponent

## รายชื่อ Peer ID ที่กำลังเปิดดูกระเป๋าใบนี้อยู่
## Server จะส่งข้อมูลอัปเดตไปให้เฉพาะคนเหล่านี้ เพื่อประหยัด Bandwidth
var viewers: Array[int] = []

func _ready() -> void:
	if not inventory:
		push_error("InventoryNetworkWrapper: ไม่พบ InventoryComponent กรุณาเชื่อมต่อผ่าน Inspector")
		return
		
	# Server เป็นคนเดียวที่จับตาดูความเปลี่ยนแปลงของกระเป๋า
	if multiplayer.is_server():
		inventory.inventory_changed.connect(_on_server_inventory_changed)

# ==========================================
# ฝั่ง Server: จัดการ Viewers (Subscribe System)
# ==========================================

## ให้ Server เรียกเมื่อมีผู้เล่นมากดเปิดหีบใบนี้
func add_viewer(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if not viewers.has(peer_id):
		viewers.append(peer_id)
		# ส่งข้อมูลสภาพล่าสุดของกระเป๋าไปให้คนที่เพิ่งเปิดดู
		rpc_id(peer_id, "_client_sync_inventory", inventory.serialize())

## ให้ Server เรียกเมื่อผู้เล่นปิดหีบ หรือเดินออกห่าง
func remove_viewer(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if viewers.has(peer_id):
		viewers.erase(peer_id)

## เมื่อกระเป๋ามีการขยับของบน Server จะส่งข้อมูลไปหา Viewer ทุกคน
func _on_server_inventory_changed() -> void:
	if not multiplayer.is_server(): return
	var data = inventory.serialize()
	
	# แจ้งอัปเดตเฉพาะคนที่เปิดกระเป๋านี้อยู่
	for peer in viewers:
		if peer == multiplayer.get_unique_id():
			# ถ้าเป็น Host (ID = 1) และกำลังเปิดดูอยู่ ให้ข้ามไป เพราะ Local State อัปเดตไปแล้วตอนกด
			# (หรือถ้าอยากให้ชัวร์ จะให้ Host โหลด Data ตัวเองทับไปอีกรอบก็ได้ แต่จะเสียประสิทธิภาพเปล่าๆ)
			pass
		else:
			rpc_id(peer, "_client_sync_inventory", data)

# ==========================================
# ฝั่ง Client: การยิงคำสั่งต่างๆ (API)
# ==========================================

## Client เรียกใช้เพื่อขอย้ายของ
func request_move_item(source_idx: int, target_idx: int) -> void:
	if multiplayer.is_server():
		# ฉันคือ Host! ทำงานตรงๆ ได้เลย ไม่ต้องรอเน็ต
		_server_request_move_item(source_idx, target_idx)
	else:
		# ยิงขออนุญาตไปที่ Server (ID = 1)
		rpc_id(1, "_server_request_move_item", source_idx, target_idx)

## Client เรียกใช้เพื่อขอหมุนไอเทม
func request_rotate_item(slot_index: int) -> void:
	if multiplayer.is_server():
		_server_request_rotate_item(slot_index)
	else:
		rpc_id(1, "_server_request_rotate_item", slot_index)

## Client เรียกใช้เพื่อขอแยกกอง
func request_split_stack(source_idx: int, target_idx: int, amount: int) -> void:
	if multiplayer.is_server():
		_server_request_split_stack(source_idx, target_idx, amount)
	else:
		rpc_id(1, "_server_request_split_stack", source_idx, target_idx, amount)


# ==========================================
# ฝั่ง Server: รับคำสั่งจาก Client
# ==========================================

@rpc("any_peer", "reliable")
func _server_request_move_item(source_idx: int, target_idx: int) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# ป้องกันการแฮ็ก: ผู้สั่งไม่มีสิทธิ์ดูกระเป๋านี้อยู่ (เว้นแต่เป็น Host ยิงเอง ซึ่ง Sender ID จะเป็น 0 ถ้าไม่ได้ใช้ RPC)
	if sender_id != 0 and not viewers.has(sender_id):
		return 
		
	# ให้ Core ทำการย้าย (จะเช็ค can_place_item_at ให้อัตโนมัติ)
	InventoryAPI.move_item(inventory, source_idx, target_idx)
	# เมื่อย้ายสำเร็จ Signal _on_server_inventory_changed จะทำงานเองและส่ง Data ให้ทุกคน

@rpc("any_peer", "reliable")
func _server_request_rotate_item(slot_index: int) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id != 0 and not viewers.has(sender_id):
		return 
		
	InventoryAPI.rotate_item(inventory, slot_index)

@rpc("any_peer", "reliable")
func _server_request_split_stack(source_idx: int, target_idx: int, amount: int) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id != 0 and not viewers.has(sender_id):
		return 
		
	InventoryAPI.split_stack(inventory, source_idx, target_idx, amount)


# ==========================================
# ฝั่ง Client: รับข้อมูลอัปเดตจาก Server
# ==========================================

@rpc("authority", "reliable")
func _client_sync_inventory(serialized_data: Array) -> void:
	if multiplayer.is_server():
		# Host ไม่ควรได้รับคำสั่งนี้ เพราะ Host ถือ Core ตัวจริงอยู่แล้ว
		return
		
	# อัปเดตกระเป๋าร่างเงา
	inventory.deserialize(serialized_data)
	# ซึ่งจะพ่น signal `inventory_changed` ออกมา ทำให้ UI ที่เกาะอยู่วาดภาพใหม่ทันที
