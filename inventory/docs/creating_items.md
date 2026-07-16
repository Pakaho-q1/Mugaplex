# การสร้างไอเทมด้วยระบบ Data-Driven และ Custom Modules

ในเกมทั่วไป เรามักจะสร้างไอเทมโดยการเขียนสคริปต์สืบทอด (Inheritance) เช่น `class Sword extends Item` ซึ่งพอเกมขยายสเกล โค้ดจะเริ่มเละเทะและผูกมัดกันยุ่งเหยิง

Universal Inventory จึงใช้แนวทาง **Data-Driven + Composition** นั่นคือไอเทมทุกชิ้นเกิดจากการ **"นำชิ้นส่วนมาประกอบกัน"** (เหมือนเลโก้)

---

## 1. ฐานราก: การสร้าง `ItemData`

`ItemData` เปรียบเสมือนป้ายชื่อและรูปถ่ายของไอเทม มันไม่รู้ลอจิกอะไรเลย หน้าที่ของมันคือเก็บข้อมูลพื้นฐาน

**วิธีสร้าง:**
1. ใน Godot ให้คลิกขวาที่ FileSystem -> `Create` -> `Resource`
2. เลือก `ItemData`
3. ตั้งชื่อไฟล์ เช่น `apple.tres`
4. ปรับค่าใน Inspector:
   - `item_id`: รหัสประจำตัว (ควรเป็นภาษาอังกฤษตัวพิมพ์เล็ก เช่น `apple`)
   - `name`: ชื่อที่แสดงผล (เช่น `Red Apple`)
   - `icon`: รูปภาพไอเทม
   - `grid_size`: ขนาด กว้างxยาว (เช่น X:1, Y:1)
   - `stackable`: ซ้อนกันได้หรือไม่? (ถ้าใช่ ปรับ `max_stack` ด้วย)

แค่นี้คุณก็ได้แอปเปิลมา 1 ลูก แต่มันยังกินไม่ได้และทำอะไรไม่ได้เลย!

---

## 2. เสกพลังให้ไอเทมด้วย `ItemModule`

เพื่อให้แอปเปิลกินได้ เราต้องใส่ `FoodModule` เข้าไปให้มัน

**วิธีประกอบโมดูล:**
1. เปิด `apple.tres` ขึ้นมา
2. เลื่อนลงมาที่หมวด `modules`
3. กดเครื่องหมาย `+` เพื่อเพิ่ม Array 
4. เลือกโมดูลที่ต้องการ (เช่น `FoodModule`, `PerishableModule`)
5. ปรับค่าตัวแปรในโมดูลนั้นๆ (เช่น เซ็ตให้ `PerishableModule` หมดอายุใน 3600 วินาที แล้วกลายเป็นไอเทม `rotten_apple`)

*เพียงเท่านี้แอปเปิลของคุณก็สามารถเน่าเสียได้เองโดยที่คุณไม่ต้องเขียนโค้ดเลยแม้แต่บรรทัดเดียว!*

---

## 3. 👨‍💻 เขียน Custom Module ของคุณเอง (Tutorial)

ถ้าคุณอยากทำไอเทมที่ยิงพลุไฟได้เมื่อกดใช้ ลำพังโมดูลที่ปลั๊กอินแถมมาให้อาจจะไม่พอ คุณสามารถเขียนโมดูลของคุณเองได้ง่ายๆ

### กฎข้อที่ 1: ห้ามแก้ค่าตัวแปรของกระเป๋าหรือไอเทมตรงๆ!
ให้จำไว้ว่า Module ถูกรันในระดับ Core คุณไม่ควรอ้างอิงถึงโหนดผู้เล่น หรือโหนดปืนโดยตรง ให้ใช้แนวทาง **"คืนค่า Payload"** กลับไปบอกเกมแทน

### ขั้นตอนการสร้าง `FireworkModule`

1. สร้างไฟล์สคริปต์ใหม่ชื่อ `firework_module.gd`
2. ให้สืบทอดจาก `ItemModule` และตั้ง `class_name`
```gdscript
extends ItemModule
class_name FireworkModule

@export var color: Color = Color.RED
@export var explosion_radius: float = 10.0
```
3. เราต้องการให้ตอนที่ "กดใช้" ไอเทมนี้ มันส่งข้อมูลสีและรัศมีไปบอกเกม เราจึงต้อง Override ฟังก์ชัน `on_use`
```gdscript
# ฟังก์ชันนี้ถูกเรียกเมื่อผู้เล่นคลิกขวา -> ใช้งานไอเทม
func on_use(slot: InventorySlot, user_context: Dictionary) -> Dictionary:
    # 1. คืนค่า consumed_amount เพื่อบอกว่าไอเทมนี้ถูกใช้แล้วกี่ชิ้น (โดนลบออกจากกระเป๋า)
    # 2. คืนค่า effects เป็น Payload เพื่อโยนออกไปให้เกมนำไปยิงพลุต่อ
    return {
        "consumed_amount": 1,
        "effects": [
            {
                "type": "firework_explosion",
                "color": color,
                "radius": explosion_radius
            }
        ]
    }
```
4. ในโค้ดหลักของเกมคุณ คุณก็นั่งรอรับ Signal เมื่อมีคนกดใช้ไอเทม
```gdscript
func _ready():
    InventoryManager.item_used.connect(_on_item_used)

func _on_item_used(item: ItemData, effects: Array):
    # วนลูปอ่าน Payload จากทุกโมดูลที่ถูกใช้
    for effect in effects:
        if effect["type"] == "firework_explosion":
            # สั่งให้เกมยิงพลุจริงๆ ขึ้นฟ้า!
            spawn_firework(effect["color"], effect["radius"])
```

### การแก้ไขค่าแบบ Real-time ด้วย `on_update`
หากคุณอยากทำโมดูล "ไฟฉาย" ที่แบตเตอรี่ลดลงเรื่อยๆ ทุกวินาที ให้ใช้ `on_update` เพื่อแก้ไข `runtime_data`:

```gdscript
func on_update(slot: InventorySlot, delta: float) -> Dictionary:
    var current_battery = slot.runtime_data.get("battery", 100.0)
    current_battery -= delta
    
    # คืนค่าตัวแปรที่อยากอัปเดตลงใน runtime_data
    return {
        "battery": max(0, current_battery)
    }
```

---

## 4. ศูนย์กลางลงทะเบียน (`ItemDatabaseRegistry.tres`)

เมื่อคุณสร้าง `ItemData` เสร็จแล้วเป็นร้อยๆ ชิ้น ระบบจำเป็นต้องรู้ที่อยู่ของมันเพื่อนำไปใช้งาน (เช่น ตอนเซฟ/โหลดเกม มันจะจำแค่รหัส `iron_sword` ไม่ได้จำทั้งไฟล์)

1. เปิดไฟล์ `ItemDatabaseRegistry.tres`
2. ระบุโฟลเดอร์ใน `scan_paths` (ปกติจะเป็น `res://items/`)
3. กดปุ่ม `Rebuild Item Database` (ไอคอนเฟืองใน Inspector)
4. ปลั๊กอินจะสแกนโฟลเดอร์และอัปเดตรายชื่อไอเทมทั้งหมดให้โดยอัตโนมัติ!
