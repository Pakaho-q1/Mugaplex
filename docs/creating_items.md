# การสร้างไอเทมและการใช้ Module

การสร้างไอเทมใน Universal Inventory นั้นง่ายและทรงพลังมากผ่านระบบ Module 

## 1. การสร้าง ItemData (ของพื้นฐาน)
1. ใน Godot ให้คลิกขวาที่ FileSystem -> Create -> Resource
2. เลือก `ItemData`
3. ตั้งชื่อไฟล์ (เช่น `sword.tres`)
4. ปรับค่าใน Inspector:
   - `item_id`: ตั้งรหัส (เช่น `iron_sword`)
   - `name` / `description`: ชื่อและคำอธิบาย
   - `grid_size`: ขนาด (เช่น X:1, Y:3)
   - `stackable`: สามารถซ้อนกันได้ไหม (True/False)

## 2. การเพิ่มความสามารถ (Item Modules)
ไอเทมเปล่าๆ ทำอะไรไม่ได้จนกว่าเราจะใส่ Module ให้มัน
ที่ช่อง `modules` ของ `ItemData` ให้กดเพิ่ม Array และใส่ Module ที่ต้องการ เช่น:
- **`EquipmentModule`**: กำหนดให้ไอเทมชิ้นนี้ใส่ในช่อง Equipment Category ที่กำหนดได้
- **`PerishableModule`**: กำหนดให้ไอเทมชิ้นนี้มีวันหมดอายุ และจะกลายสภาพเป็นไอเทมอื่นเมื่อเวลาหมด

## 3. การสร้าง Custom Module ของตัวเอง
คุณสามารถสร้างสคริปต์สืบทอดจาก `ItemModule` ได้อย่างอิสระ:
```gdscript
extends ItemModule
class_name WeaponStatsModule

@export var attack_damage: int = 15
@export var durability: int = 100
```
จากนั้นเซฟและนำไปยัดใส่ ItemData ได้เลย ระบบจะโหลดขึ้นมาให้อัตโนมัติ!

## 4. ItemDatabaseRegistry (ศูนย์บัญชาการไอเทม)
ระบบต้องการรู้ว่ารหัส `iron_sword` คือ Resource ไฟล์ไหน
ให้ไปที่ `ItemDatabaseRegistry.tres` และกดเรียก `rebuild()` เพื่อให้ปลั๊กอินสแกนโฟลเดอร์ไอเทมของคุณ และจับคู่ ID เข้ากับไฟล์โดยอัตโนมัติ
