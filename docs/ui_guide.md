# คู่มือการใช้งาน UI สำเร็จรูป (UI Guide)

เราเตรียม UI มาตรฐานพร้อม Drag & Drop ให้แล้ว คุณสามารถนำไปใช้ได้ทันที

## การเรียกใช้งาน
1. ลาก Node ชื่อ `InventoryUI` มาวางในฉากของคุณ
2. ลาก Node ชื่อ `EquipmentUI` มาวางในฉากของคุณ
3. เชื่อมต่อ (Bind) UI เข้ากับข้อมูลของตัวละคร:
```gdscript
# ในสคริปต์ของ Player หรือ UI Manager
@onready var inventory_ui = $InventoryUI
@onready var player_inventory = $Player/InventoryComponent

func _ready():
    inventory_ui.set_inventory(player_inventory)
```

## โครงสร้างของ UI
- **`InventoryUI`**: วาดช่อง Grid อัตโนมัติตาม `grid_columns` และ `max_slots`
- **`InventorySlotUI`**: หน้าต่างช่องเดี่ยวๆ ที่แสดงรูปไอเทมและตัวเลขจำนวน รองรับระบบ Drag & Drop ภายในตัว

## การปรับแต่งหน้าตา (Theming)
คุณสามารถเข้าไปแก้ Resource ของ `InventorySlotUI.tscn` ได้อย่างอิสระ:
- เปลี่ยนรูปพื้นหลัง
- เปลี่ยนฟอนต์ตัวเลข
- เปลี่ยนสไตล์เวลาเมาส์ Hover หรือเวลากำลังลาก (Drag)
