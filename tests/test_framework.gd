extends RefCounted
class_name TestSuite

## Framework ทดสอบเบาๆ ไม่พึ่ง addon ภายนอก (ไม่ใช้ GUT)
## แต่ละ test suite ให้ extends TestSuite แล้วเขียนฟังก์ชันที่ขึ้นต้นด้วย test_
## เรียก .run() เพื่อรันทุก test_* ในตัวเองแล้วคืนผลสรุปเป็น Dictionary

var suite_name: String = "TestSuite"

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func assert_eq(actual, expected, message: String = "") -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		var msg = message if message != "" else "expected [%s] but got [%s]" % [str(expected), str(actual)]
		_failures.append(msg)


func assert_true(condition: bool, message: String = "") -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		_failures.append(message if message != "" else "expected true but got false")


func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message if message != "" else "expected false but got true")


func assert_null(value, message: String = "") -> void:
	if value == null:
		_passed += 1
	else:
		_failed += 1
		_failures.append(message if message != "" else "expected null but got [%s]" % str(value))


func assert_not_null(value, message: String = "") -> void:
	if value != null:
		_passed += 1
	else:
		_failed += 1
		_failures.append(message if message != "" else "expected non-null value")


## รันทุกฟังก์ชันที่ชื่อขึ้นต้นด้วย test_ ในคลาสลูก แล้วคืนผลสรุป
func run() -> Dictionary:
	_passed = 0
	_failed = 0
	_failures.clear()

	for m in get_method_list():
		var method_name: String = m["name"]
		if method_name.begins_with("test_"):
			call(method_name)

	return {
		"suite": suite_name,
		"passed": _passed,
		"failed": _failed,
		"failures": _failures.duplicate(),
	}
