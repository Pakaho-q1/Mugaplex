# สถาปัตยกรรม (Architecture & Philosophy)

Universal Inventory ไม่ใช่แค่ระบบจัดการกระเป๋าธรรมดา แต่คือ **Core Gameplay Framework** ที่ถูกออกแบบมาเพื่อรองรับเกมทุกรูปแบบ โดยยึดมั่นในหลักการ 2 ข้อ:

1. **Engine Independence:** ระบบ Core ทั้งหมดต้องไม่รู้จักโหนดเกม ไม่ผูกติดกับ Player class ทุกอย่างทำงานผ่านข้อมูล (Data) และ Signals
2. **Separation of Concerns:** UI มีหน้าที่แค่ "วาดภาพ" ส่วน Core มีหน้าที่ "คำนวณ"

---

## 🏗️ โครงสร้าง 3 ชั้น (3-Tier Architecture)

```
+---------------------------------+
|  UI Layer (Dumb UI)             |
|  SlotUI, InventoryUI            |
|  InvContextReceiver             |
+---------------------------------+
            |  Request / Signal
            v
+---------------------------------+
|  API Layer (Service)            |
|  InventoryAPI, EquipmentAPI     |
+---------------------------------+
            |
            v
+---------------------------------+
|  Core Layer (Pure Logic)        |
|  InventoryComponent             |
|  EquipmentComponent             |
|  ConditionManager               |
+---------------------------------+
            |  inventory_changed
            |  item_dropped, etc.
            v
     Game World / Player
```

### Core Layer
ชั้นแกนกลาง สนใจเฉพาะคณิตศาสตร์และข้อมูล ไม่ผูกมัดกับภาพกราฟิก
- **องค์ประกอบ:** `InventoryComponent`, `EquipmentComponent`, `ConditionManager`

### API Layer
ตัวกลางรวบรวมคำสั่งที่ใช้บ่อย เช่น ย้ายของ, ทิ้งของ, คราฟต์ไอเทม
- **องค์ประกอบ:** `InventoryAPI`, `EquipmentAPI`

### UI Layer
ต้องโง่ที่สุดเท่าที่ทำได้ — นั่งรอรับ Signal แล้ววาดใหม่เท่านั้น ไม่มี Logic ใดๆ
- **องค์ประกอบ:** `SlotUI`, `InventoryUI`, `InvContextReceiver`

---

## 📦 Data Model (โมเดลข้อมูล)

เราใช้แนวทาง **Data-Driven & Composition** แทนการสร้างคลาสสืบทอด

| คลาส | บทบาท |
|---|---|
| `ItemData` | Blueprint ของไอเทม เก็บชื่อ รูป และรายชื่อ `ItemModule` |
| `ItemModule` | ชิ้นส่วนลอจิก เช่น `FoodModule`, `WeaponModule` ไอเทมมีกี่โมดูลก็ได้ |
| `InventorySlot` | ช่องหนึ่งในกระเป๋า เก็บ `item`, `amount`, และ `runtime_data` |
| `runtime_data` | Dictionary เก็บข้อมูลที่เปลี่ยนแปลงได้ Real-time เช่น ความทนทาน, เวลาหมดอายุ |

> **หมายเหตุ:** `ItemData` เป็น Resource ที่ใช้ข้อมูลร่วมกันทั้งเกม จึงไม่ควรแก้ค่าที่แตกต่างกันในแต่ละ instance โดยตรง ให้ฝากข้อมูลนั้นไว้ที่ `runtime_data` ของ `InventorySlot` แทน

---

## 🌐 InventoryManager (Autoload / Global)

`InventoryManager` คือโหนด Autoload ที่ทำหน้าที่เป็น **ศูนย์กลางการสื่อสาร (Event Bus)** ของระบบ UI และ Cursor

### Signals ที่สำคัญ
| Signal | เมื่อไหร่ | ใครฟัง |
|---|---|---|
| `context_menu_requested(inv, slot_index, pos, source_ui)` | เมื่อคลิกขวาที่ช่องที่มีไอเทม | `InvContextReceiver` |
| `item_dropped(item, amount, runtime_data)` | เมื่อลากไอเทมปล่อยนอก UI | Game World (สร้าง Item Drop 3D) |
| `cursor_item_changed()` | เมื่อไอเทมในมือเปลี่ยน | UI อื่นๆ ที่ต้องการแสดงสิ่งที่ถืออยู่ |
| `inventory_opened(component)` | เมื่อเปิดหน้าต่างกระเป๋า | ระบบ Pause หรือ Camera |
| `inventory_closed(component)` | เมื่อปิดหน้าต่างกระเป๋า | ระบบ Pause หรือ Camera |

### Cursor Manager
InventoryManager จัดการ "ไอเทมที่ถืออยู่ในมือ" (เวลาคลิกหยิบหรือลากไอเทม)

| ตัวแปร | คำอธิบาย |
|---|---|
| `cursor_item: ItemData` | ไอเทมที่ถืออยู่ (`null` ถ้าไม่มี) |
| `cursor_amount: int` | จำนวนที่ถือ |
| `cursor_source_inventory` | กระเป๋าต้นทาง (เพื่อส่งคืนเวลายกเลิก) |
| `cursor_source_index: int` | ช่องต้นทาง |

### ฟังก์ชันที่ UI เรียกใช้
| ฟังก์ชัน | คำอธิบาย |
|---|---|
| `handle_slot_click(inv, slot_index, event, source_slot)` | จัดการ Logic ทั้งหมดของการคลิก: หยิบ, วาง, สลับ, ซ้อนทับ |
| `grab_item_to_cursor(inv, slot_index, amount, source_ui)` | ดึงไอเทมจำนวนที่กำหนดเข้ามือ (ใช้โดย InvContextReceiver เวลา Split) |
| `return_cursor_to_source()` | คืนไอเทมกลับช่องเดิม |
| `drop_cursor_to_ground()` | โยนไอเทมทิ้ง (ส่ง Signal `item_dropped`) |

### Drag & Drop Logic (Global)
InventoryManager คอย Monitor Input ระดับ Global ผ่าน `_input()` เพื่อตรวจสอบ:
- **ระหว่างลาก (Drag):** ตรวจจากระยะ > 5px จาก จุดเริ่มต้น
- **ปล่อยบน SlotUI:** วาง/สลับผ่าน `handle_slot_click`
- **ปล่อยบน UI แต่ไม่โดน Slot:** คืนกลับช่องเดิม (`return_cursor_to_source`)
- **ปล่อยนอก UI ทั้งหมด:** โยนทิ้งพื้น (`drop_cursor_to_ground`) และ Consume event ป้องกันตัวละครรับ Input

---

## 🛡️ นโยบายโมดูล (Module Resolution Policy)

เมื่อไอเทมมีหลาย Module ที่ทำงานพร้อมกัน ระบบใช้กฎเหล่านี้:

1. **Veto (สำหรับ `before_use`):** ถ้า Module ใดคืน `prevented: true` การกระทำถูกระงับทันที หยุดรัน Module ที่เหลือ
2. **Accumulation (สำหรับ `on_use`):** ผลลัพธ์จากทุก Module รวมกันเป็น Array ส่งกลับให้เกม
3. **Sequential Override (สำหรับ `on_update`):** ถ้า 2 Module เขียน Key เดียวกันใน `runtime_data` Module ที่อยู่ท้ายสุดในอาร์เรย์จะชนะ

---

## 🧪 Crafting & Condition Reaction

### Item Crafting System (โดเมนกระเป๋า)
- **แนวคิด:** `ItemData + ItemData = ItemData`
- ใช้ `RecipeRegistry` เก็บสูตร `ItemRecipe`
- เรียกผ่าน `InventoryAPI.craft_items()`

### Condition Reaction System (โดเมนตัวละคร)
- **แนวคิด:** `Condition + Condition = New Condition` (ระบบปฏิกิริยาธาตุ)
- ขับเคลื่อนผ่าน `ConditionManager` บนตัวละคร
- ตัวอย่าง: Wet + Burning = Steam (ควันพรางตัว)
