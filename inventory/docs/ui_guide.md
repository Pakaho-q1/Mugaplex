# คู่มือการออกแบบและการปรับแต่ง UI (UI Guide)

ปัญหาคลาสสิกของการทำระบบ Inventory คือ **"UI มักจะเข้าไปยุ่งกับ Logic เสมอ"** Universal Inventory แก้ปัญหานี้ด้วยแนวคิด **"Dumb UI"** ที่ UI มีหน้าที่แค่ 2 อย่าง: วาดภาพตาม Signal และส่งต่อ Input ไปให้ API จัดการ

---

## 🏗️ สถาปัตยกรรม UI โดยรวม

```
Player Input (Click/Drag)
        |
        v
   SlotUI (รับ Input แล้วส่งต่อ)
        |
        v
 InventoryManager (Autoload / ศูนย์กลาง)
   |-- จัดการ Cursor Item (ไอเทมที่ถืออยู่)
   |-- ส่ง Signal: context_menu_requested
   |-- ส่ง Signal: item_dropped
        |
        |---> InventoryComponent (แก้ไขข้อมูล)
        |         |-- Emits: inventory_changed
        |                  |
        |                  v
        |           InventoryUI (วาดช่องใหม่ทั้งหมด)
        |
        |---> InvContextReceiver (เปิดเมนูคลิกขวา)
```

---

## 🔌 InventoryUI — การแสดงผลกระเป๋า

สคริปต์ UI ของปลั๊กอินใช้ซ้ำ (Reusable) ได้กับทุกอย่าง ไม่ว่าจะเป็นกระเป๋าผู้เล่น กล่องสมบัติ หรือศพมอนสเตอร์

```gdscript
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var player_inventory = $Player/InventoryComponent

func _ready():
    inventory_ui.set_inventory(player_inventory)
```

ทันทีที่เรียก `set_inventory()` ตัว UI จะสร้างช่องตามจำนวน Slot ใน Component และ Connect Signal `inventory_changed` โดยอัตโนมัติ

---

## 🎮 SlotUI — ช่องเก็บไอเทมแต่ละช่อง

### Inspector Settings

**หมวด Core Elements**
| ตัวแปร | คำอธิบาย |
|---|---|
| `icon_rect_path` | NodePath ไปยัง TextureRect สำหรับแสดงรูปไอเทม |
| `amount_label_path` | NodePath ไปยัง Label สำหรับแสดงจำนวน |
| `interaction_control_path` | NodePath ไปยัง Control ที่รับ Mouse Click (ถ้าไม่ระบุ ใช้ตัวเองเป็น clickable area) |

**หมวด Drag & Drop Settings**
| ตัวแปร | คำอธิบาย |
|---|---|
| `drag_mode` | `0` Click-to-Hold, `1` Hold-to-Drag, `2` **Hybrid** (ค่าเริ่มต้น — ทำได้ทั้งคู่) |
| `drag_preview_size` | ขนาด Preview ที่ติดเมาส์เวลาลาก |
| `drag_preview_container_path` | NodePath ไปยัง Container ที่จะ Duplicate มาเป็น Preview (ถ้าไม่ระบุ ใช้ TextureRect ธรรมดา) |

**หมวด Split Behavior**
| ตัวแปร | คำอธิบาย |
|---|---|
| `pickup_delay_ms` | หน่วงการหยิบไอเทม (ms) เพื่อให้ Double-click ทำงานได้ถูกต้อง **ทำงานเฉพาะตอนมือว่าง** |
| `split_action_name` | ชื่อ Action ใน InputMap ที่ใช้กด + คลิกเพื่อแบ่งไอเทม |
| `split_formula` | สูตรคำนวณจำนวนที่แบ่ง เช่น `"amount / 2"` |

### พฤติกรรมการคลิก

| การกระทำ | ผล |
|---|---|
| คลิกซ้าย (มือว่าง) | หยิบไอเทมทั้งกอง → ติดเมาส์ |
| คลิกซ้าย (มีของในมือ) | วางของ / ซ้อนทับ / สลับ |
| คลิกขวา (มือว่าง + มีไอเทม) | เปิด Context Menu ผ่าน InvContextReceiver |
| คลิกขวา (มีของในมือ) | วางทีละ 1 ชิ้น |
| ดับเบิลคลิก | ใช้งานไอเทม (ถ้าเปิด `use_on_double_click`) |

### พฤติกรรมการลาก (Drag & Drop)

| การปล่อย | ผล |
|---|---|
| ปล่อยบน SlotUI อื่น | วาง / สลับ / ซ้อนทับ |
| ปล่อยในขอบเขต UI แต่ไม่โดน Slot | คืนไอเทมกลับช่องเดิม |
| ปล่อยนอกขอบเขต UI ทั้งหมด | ส่ง Signal `item_dropped` → โยนทิ้งลงพื้น |

---

## 📋 InvContextReceiver — เมนูคลิกขวาสำเร็จรูป

โหนดนี้รับ Signal `context_menu_requested` จาก `InventoryManager` **โดยอัตโนมัติ** ไม่ต้องเชื่อมสายใดๆ ด้วยตัวเอง

### การติดตั้ง
1. สร้างโหนด `Node` ในซีน แล้วแนบสคริปต์ `inv_context_receiver.gd`
2. สร้าง UI ของเมนู (PanelContainer, ปุ่มต่างๆ) เป็นลูกของโหนดนี้
3. เชื่อม NodePath ใน Inspector

> **หมายเหตุ:** ไม่ต้องกังวลเรื่อง CanvasLayer! โหนดนี้จะสร้าง CanvasLayer (Layer 100) ให้เองอัตโนมัติตอน `_ready()` ทำให้เมนูแสดงบนสุดเสมอ ไม่ว่าจะวางโหนดไว้ที่ไหนก็ตาม (แม้อยู่ใต้ Player Node ก็ทำงานได้ถูกต้อง)

### Inspector Settings

**หมวด Menu UI**
| ตัวแปร | คำอธิบาย |
|---|---|
| `menu_container_path` | NodePath ไปยัง Container หลักของเมนู ระบบจะ Show/Hide และย้ายตำแหน่งตัวนี้ |

**หมวด Item Details Display (ไม่บังคับ)**
เมื่อเชื่อม NodePath ระบบจะอัปเดตเนื้อหาให้อัตโนมัติเมื่อเมนูเปิด
| ตัวแปร | รับข้อมูล |
|---|---|
| `name_label_path` | ชื่อไอเทม (`item.display_name`) |
| `description_label_path` | คำอธิบายไอเทม (`item.description`) |
| `icon_rect_path` | รูปไอเทม (`item.icon`) |

**หมวด Action Buttons (ไม่บังคับ)**
| ตัวแปร | พฤติกรรมเมื่อกด |
|---|---|
| `use_button_path` | เรียก `InventoryAPI.use_item()` แล้วปิดเมนู ปุ่ม Disable ถ้า `item.disable_use = true` |
| `drop_button_path` | เรียก `InventoryAPI.drop_item()` แล้วปิดเมนู |
| `split_button_path` | ดึงไอเทมเข้า Cursor ตามจำนวน Slider แล้วปิดเมนู ปุ่ม Disable ถ้ามีแค่ 1 ชิ้น |

**หมวด Split UI (ไม่บังคับ)**
| ตัวแปร | คำอธิบาย |
|---|---|
| `split_slider_path` | NodePath ไปยัง HSlider — ค่า min/max ถูกตั้งอัตโนมัติตามจำนวนไอเทม |
| `split_amount_label_path` | NodePath ไปยัง Label แสดงตัวเลขที่ Slider ชี้อยู่ |

### Signals
| Signal | เมื่อไหร่ |
|---|---|
| `menu_opened(inventory, slot_index)` | เมื่อเมนูแสดงขึ้น ใช้ทำ Animation เปิด |
| `menu_closed()` | เมื่อเมนูถูกปิด |

---

## 🧑‍💻 การติดตั้งกับตัวละคร (Player Integration)

### ปัญหา: Input ทะลุจาก UI ไปหาตัวละคร

หากตัวละครของคุณใช้ `Input.is_action_just_pressed(...)` ใน `_physics_process` ตัวละครจะรับ Input แม้จะคลิกใน UI ก็ตาม

**วิธีแก้ที่ถูกต้อง:** ย้ายโค้ด Input ของตัวละครไปไว้ใน `_unhandled_input()` แทน

```gdscript
# ผิด: ตัวละครรับ Input แม้จะคลิก UI
func _physics_process(delta):
    if Input.is_action_just_pressed("attack"):
        attack()

# ถูก: ตัวละครจะไม่รับ Input ถ้า UI ดัก Input นั้นไปแล้ว
func _unhandled_input(event):
    if event.is_action_pressed("attack"):
        attack()
```

`_unhandled_input` จะทำงานก็ต่อเมื่อ Input นั้นไม่ถูกระบบ UI หรือโหนดอื่นดักจับไปก่อนเท่านั้น นี่คือ Pattern มาตรฐานของ Godot สำหรับแยก Game World Input กับ UI Input ครับ

---

## 🏗️ Item Database Editor (เครื่องมือฝั่ง Editor)

ปลั๊กอินมี UI พิเศษที่ทำงานใน Godot Editor ที่ Bottom Panel:

- ดูและแก้ไขรายชื่อไอเทมทั้งหมดที่ลงทะเบียนใน Registry
- รองรับ Custom Module ที่คุณเขียนเอง — หน้าจอจะแสดงฟิลด์ `@export` ของ Module คุณโดยอัตโนมัติ
