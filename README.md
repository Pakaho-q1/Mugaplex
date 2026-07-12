# Universal Inventory Plugin for Godot 4

![Godot v4.x](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine)
![License](https://img.shields.io/badge/License-MIT-green)

ปลั๊กอินระบบกระเป๋าเก็บของ (Inventory System) ที่ทรงพลังและยืดหยุ่นที่สุดสำหรับ Godot Engine ออกแบบมาด้วยแนวคิด **Engine Independence** และ **Headless Architecture** ทำให้คุณสามารถนำไปประยุกต์ใช้กับเกมได้ทุกแนว ไม่ว่าจะเป็น RPG, Survival, Card Game, หรือ Turn-based Strategy

## จุดเด่น (Features)
- 🧩 **100% Modular Architecture:** ขยายความสามารถของไอเทมได้อย่างไร้ขีดจำกัดผ่านระบบ `ItemModule` (เช่น ไอเทมเน่าเสียได้, อาวุธตีบวก, ยูนิตการ์ด)
- 📏 **Grid & Slot Support:** รองรับทั้งกระเป๋าแบบช่องเดี่ยวๆ ทั่วไป และกระเป๋าแบบ Grid 2D (Bin Packing) 
- 🧠 **Headless API:** แกนหลักของระบบ (Core) แยกขาดจากส่วนแสดงผล (UI) ทำให้คุณสามารถใช้สคริปต์ควบคุมระบบหลังบ้านได้โดยไม่ต้องมี UI แม้แต่ชิ้นเดียว
- 📦 **Save / Load System:** รองรับการเซฟและโหลดข้อมูลกระเป๋าครบวงจร
- ⚡ **Event-Driven:** ทุกการกระทำจะเชื่อมต่อกันด้วยระบบ Signal ทำให้ระบบอื่นในเกมตอบสนองได้ทันที

## การเริ่มต้นใช้งานอย่างรวดเร็ว (Quick Start)

1. เปิด `addons/universal_inventory` ในโปรเจกต์ของคุณ
2. คัดลอก `ItemDatabaseRegistry.tres` ของคุณไปใส่ในโปรเจกต์
3. เรียกใช้ API ผ่านสคริปต์ของคุณได้ทันที!

```gdscript
# ตัวอย่างการหยิบไอเทมเข้ากระเป๋า
var item = ItemDatabase.get_item("health_potion")
InventoryAPI.add_item(player_inventory, item, 2)
```

## สารบัญคู่มือ (Documentation)
กรุณาอ่านเอกสารในโฟลเดอร์ `docs/` สำหรับการเรียนรู้เจาะลึกในแต่ละส่วน:
1. [สถาปัตยกรรม & แนวคิด (Architecture)](docs/architecture.md)
2. [การสร้างไอเทมและ Module (Creating Items)](docs/creating_items.md)
3. [คู่มือการใช้งาน API (API Reference)](docs/api_reference.md)
4. [คู่มือการใช้งาน UI สำเร็จรูป (UI Guide)](docs/ui_guide.md)
