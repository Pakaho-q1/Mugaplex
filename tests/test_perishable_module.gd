extends TestSuite
class_name TestPerishableModule

func _init() -> void:
	suite_name = "PerishableModule"


func test_calculate_decay_reduces_freshness_by_delta() -> void:
	var p = PerishableModule.new()
	p.freshness_duration = 100.0

	var result = p.calculate_decay(100.0, 10.0)

	assert_eq(result["freshness"], 90.0, "ผ่านไป 10 วินาที ความสดควรลดจาก 100 เหลือ 90")
	assert_false(result["spoiled"], "ความสด 90 ยังไม่ควรถือว่าเน่า")


func test_calculate_decay_clamps_at_zero_and_marks_spoiled() -> void:
	var p = PerishableModule.new()

	var result = p.calculate_decay(5.0, 10.0)

	assert_eq(result["freshness"], 0.0, "ความสดต้องไม่ติดลบ ต้อง clamp ไว้ที่ 0")
	assert_true(result["spoiled"], "เมื่อความสดหมด (<=0) ต้องถือว่าเน่าแล้ว")


func test_calculate_decay_is_pure_and_deterministic() -> void:
	# spoil_chance_per_second default = 0 จึงไม่มีความสุ่มมาปน ผลลัพธ์ต้องเหมือนกันทุกครั้ง
	var p = PerishableModule.new()

	var result_a = p.calculate_decay(50.0, 5.0)
	var result_b = p.calculate_decay(50.0, 5.0)

	assert_eq(result_a["freshness"], result_b["freshness"], "input เดิมต้องให้ผลลัพธ์เดิมเสมอ (deterministic)")
	assert_eq(result_a["spoiled"], result_b["spoiled"])


func test_calculate_decay_does_not_mutate_any_external_state() -> void:
	# ยืนยันว่า calculate_decay ไม่แก้ไขค่าใดๆ ใน module เอง (pure calculation)
	var p = PerishableModule.new()
	p.freshness_duration = 100.0

	p.calculate_decay(80.0, 20.0)

	assert_eq(p.freshness_duration, 100.0, "การเรียก calculate_decay ต้องไม่แก้ไขค่า config ของ module เอง")


func test_is_spoiled_reads_runtime_data_correctly() -> void:
	var p = PerishableModule.new()
	p.freshness_duration = 100.0

	var slot = InventorySlot.new()
	slot.runtime_data["freshness"] = 0.0
	assert_true(p.is_spoiled(slot), "freshness = 0 ต้องถือว่าเน่าแล้ว")

	slot.runtime_data["freshness"] = 50.0
	assert_false(p.is_spoiled(slot), "freshness = 50 ยังไม่ควรเน่า")


func test_get_freshness_ratio_returns_normalized_value() -> void:
	var p = PerishableModule.new()
	p.freshness_duration = 200.0

	var slot = InventorySlot.new()
	slot.runtime_data["freshness"] = 100.0

	assert_eq(p.get_freshness_ratio(slot), 0.5, "freshness 100/200 ต้องได้อัตราส่วน 0.5")
