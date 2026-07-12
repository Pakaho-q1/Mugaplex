extends Node

## วิธีใช้:
## 1. เปิดไฟล์ run_tests.tscn ใน Godot Editor
## 2. กด F6 (Run Current Scene) หรือกด Play แล้วเลือกฉากนี้
## 3. ดูผลลัพธ์ที่แถบ Output ด้านล่าง Editor
##
## ทางเลือก (รันแบบ headless ผ่าน command line โดยไม่เปิด Editor):
##   godot --headless --path <โฟลเดอร์โปรเจกต์> res://addons/universal_inventory/tests/run_tests.tscn
## หมายเหตุ: path preload ด้านล่างสมมติว่าโฟลเดอร์นี้อยู่ที่
## res://addons/universal_inventory/ ตามที่ REGISTRY_PATH อื่นๆ ในโปรเจกต์ใช้อยู่แล้ว
## ถ้าคุณวาง plugin ไว้คนละที่ ให้แก้ path ด้านล่างให้ตรงกับตำแหน่งจริง

const TEST_SUITES: Array[Script] = [
	preload("res://addons/universal_inventory/tests/test_inventory_slot.gd"),
	preload("res://addons/universal_inventory/tests/test_perishable_module.gd"),
	preload("res://addons/universal_inventory/tests/test_inventory_component.gd"),
	preload("res://addons/universal_inventory/tests/test_equipment_component.gd"),
]


func _ready() -> void:
	run_all_tests()


func run_all_tests() -> void:
	var total_passed := 0
	var total_failed := 0

	print("\n===== Running Unit Tests =====\n")

	for suite_script in TEST_SUITES:
		var suite: TestSuite = suite_script.new()
		var result: Dictionary = suite.run()

		total_passed += result["passed"]
		total_failed += result["failed"]

		var status = "PASS" if result["failed"] == 0 else "FAIL"
		print("[%s] %s — passed: %d, failed: %d" % [
			status, result["suite"], result["passed"], result["failed"]
		])

		for failure_message in result["failures"]:
			print("    ✗ %s" % failure_message)

	print("\n===== Summary: %d passed, %d failed =====\n" % [total_passed, total_failed])

	if total_failed > 0:
		push_error("Unit tests failed: %d test(s) did not pass" % total_failed)
		
	# ปิด Godot ทันทีถ้าเป็นการรันแบบ headless
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
