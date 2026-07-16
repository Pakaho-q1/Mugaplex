# คู่มืออ้างอิง API (API Reference)

การเขียนโค้ดเพื่อควบคุมกระเป๋า ไอเทม และระบบต่างๆ ของ Universal Inventory **ควรทำผ่านฟังก์ชันของคลาส API เท่านั้น** การแก้ไขค่าตัวแปรใน `InventoryComponent` โดยตรงอาจทำให้ระบบพังและ Signal ไม่ทำงาน

---

## 🎒 InventoryAPI

ฟังก์ชันทั้งหมดเป็น `static func` — เรียกใช้งานได้เลยโดยไม่ต้องสร้าง instance

### การจัดการไอเทมพื้นฐาน

#### `add_item(inventory, item, amount = 1) -> Dictionary`
เพิ่มไอเทมเข้าไปในกระเป๋า ระบบจะพยายามซ้อนทับ (Stack) ก่อน แล้วค่อยหาช่องว่าง

- **คืนค่า:** `{ "success": bool, "remaining": int, "message": String }`

```gdscript
var result = InventoryAPI.add_item(player_inventory, health_potion, 5)
if result.success:
    print("เพิ่มยาสำเร็จ!")
elif result.remaining > 0:
    print("กระเป๋าเต็ม ของร่วง %d ชิ้น" % result.remaining)
```

#### `move_item(inventory, source_idx, target_idx) -> void`
ย้ายหรือสลับของระหว่างสองช่องภายในกระเป๋าเดียวกัน

#### `drop_item(inventory, index, amount = -1) -> bool`
โยนไอเทมออกจากกระเป๋า จะส่ง Signal `InventoryManager.item_dropped` ให้ Game World สร้าง Item Drop

```gdscript
# ทิ้งของทั้งหมดในช่อง 0
InventoryAPI.drop_item(player_inventory, 0)

# ทิ้งเฉพาะ 1 ชิ้น
InventoryAPI.drop_item(player_inventory, 0, 1)
```

#### `use_item(inventory, index) -> void`
ใช้งานไอเทม — รัน `before_use` และ `on_use` ของทุก Module บนไอเทมนั้น

```gdscript
# ใช้โดย InvContextReceiver เมื่อกดปุ่ม "Use"
InventoryAPI.use_item(player_inventory, slot_index)
```

---

### ฟีเจอร์ขั้นสูง

#### `sort_inventory(inventory) -> void`
เรียงของในกระเป๋าโดยอัตโนมัติ รวมกองเดียวกันก่อน แล้วดันไปช่องแรกๆ

#### `split_stack(inventory, source_idx, target_idx, amount) -> bool`
แบ่งของออกจากกองไปใส่ในช่องอื่น

---

### Query & Transaction

#### `has_item_amount(inventory, item, amount) -> bool`
ตรวจว่าในกระเป๋ามีไอเทมชนิดนี้รวมกันถึงจำนวนที่กำหนดหรือไม่ (บวกจากทุกช่อง)

```gdscript
if InventoryAPI.has_item_amount(player_inventory, mushroom_item, 10):
    print("เควสต์เสร็จสมบูรณ์!")
```

#### `consume_item(inventory, item, amount) -> bool`
หักไอเทมออกจากกระเป๋าตามจำนวน ถ้าของมีไม่พอจะคืน `false` และ **ไม่หักของเลย**

```gdscript
if InventoryAPI.consume_item(player_inventory, mushroom_item, 10):
    give_quest_reward()
else:
    print("เห็ดไม่พอ!")
```

#### `transfer_item(source_inv, target_inv, source_idx, target_idx = -1, amount = -1) -> bool`
ย้ายไอเทมข้ามกระเป๋า `target_idx = -1` ให้ระบบหาช่องว่างให้เอง, `amount = -1` ย้ายทั้งกอง

---

### ระบบคราฟต์

#### `craft_items(inventory, registry, slot_indices) -> bool`
นำไอเทมในช่องที่ระบุมาผสมกัน ถ้าตรงกับสูตรจะหักวัตถุดิบและใส่ผลลัพธ์เข้ากระเป๋า

```gdscript
var success = InventoryAPI.craft_items(player_inventory, my_recipe_registry, [0, 1])
if success:
    print("คราฟต์สำเร็จ!")
```

---

## 🗡️ EquipmentAPI

#### `equip_from_inventory(equipment, inventory, inv_idx) -> bool`
ถอดไอเทมจากช่องในกระเป๋า ไปใส่ในช่องสวมใส่ที่ถูกต้อง (ระบบเช็ค Category อัตโนมัติ)

#### `unequip_to_inventory(equipment, inventory, equip_category) -> bool`
ถอดอุปกรณ์ที่ใส่อยู่ออก และย้ายกลับไปเก็บในกระเป๋า

---

## 🌐 InventoryManager (Autoload — ไม่ใช่ Static)

ไม่เหมือน `InventoryAPI` ตัว `InventoryManager` เป็น Autoload Node ที่จัดการเรื่อง **Cursor** และ **UI Event**

### ฟังก์ชันหลักที่ควรรู้

#### `handle_slot_click(inv, slot_index, event, source_slot)`
Logic กลางสำหรับ Click Interaction ของ Slot ทั้งหมด — `SlotUI` จะเรียกฟังก์ชันนี้แทนที่จะจัดการเอง

#### `grab_item_to_cursor(inv, slot_index, amount, source_slot_ui)`
ดึงไอเทมจำนวนที่กำหนดออกจากกระเป๋าเข้ามือ (Cursor) — ใช้โดย `InvContextReceiver` เวลา Split

#### `return_cursor_to_source()`
คืนไอเทมที่ถืออยู่กลับช่องต้นทาง (เมื่อยกเลิกการลาก)

#### `drop_cursor_to_ground()`
โยนไอเทมที่ถืออยู่ทิ้ง ส่ง Signal `item_dropped` ให้ Game World

#### `register_player(comp: InventoryComponent)`
ลงทะเบียนกระเป๋าของผู้เล่นหลัก เพื่อให้ระบบอื่นอ้างอิงผ่าน `InventoryManager.get_player()`

---

## 💾 Save / Load

```gdscript
# บันทึก
InventoryAPI.save_to_file(player_inventory, player_equipment, "user://save1.tres")

# โหลด
InventoryAPI.load_from_file(player_inventory, player_equipment, "user://save1.tres")
```

---

## 📡 Signals ที่สำคัญ

### InventoryComponent
| Signal | เมื่อไหร่ |
|---|---|
| `inventory_changed()` | เมื่อข้อมูลใน Slot เปลี่ยนแปลง ให้ UI วาดใหม่ |

### InventoryManager
| Signal | ข้อมูลที่ส่ง |
|---|---|
| `context_menu_requested(inv, slot_index, pos, source_ui)` | คลิกขวาที่ Slot ที่มีไอเทม |
| `item_dropped(item, amount, runtime_data)` | ลากไอเทมออกนอก UI |
| `cursor_item_changed()` | ไอเทมในมือเปลี่ยน |
| `inventory_opened(component)` | เปิดหน้าต่างกระเป๋า |
| `inventory_closed(component)` | ปิดหน้าต่างกระเป๋า |
