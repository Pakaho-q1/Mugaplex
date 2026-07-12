# คู่มืออ้างอิง API (API Reference)

การเขียนโค้ดเพื่อควบคุมกระเป๋า ไอเทม และระบบต่างๆ ของ Universal Inventory **ควรทำผ่านฟังก์ชันของคลาส API เท่านั้น** การแก้ไขค่าตัวแปรใน `InventoryComponent` หรือ `EquipmentComponent` โดยตรงอาจทำให้ระบบพังและ Signal ไม่ทำงาน

ในหน้าเอกสารนี้จะรวบรวม API ที่สำคัญ พร้อมทั้ง Use Case และ Code Snippet เพื่อให้นำไปใช้งานได้ทันที

---

## 🎒 InventoryAPI (`inventory_api.gd`)

ฟังก์ชันทั้งหมดในคลาสนี้เป็น `static func` หมายความว่าคุณไม่ต้องสร้างอินสแตนซ์ของคลาส สามารถพิมพ์ `InventoryAPI.ชื่อฟังก์ชัน(...)` เรียกใช้งานได้เลยจากทุกที่

### 1. การจัดการไอเทมพื้นฐาน

#### `add_item(inventory: InventoryComponent, item: ItemData, amount: int = 1) -> Dictionary`
เพิ่มไอเทมเข้าไปในกระเป๋า ระบบจะพยายามวางไอเทมในช่องที่ว่าง หรือนำไปซ้อนทับ (Stack) ในช่องที่มีไอเทมชนิดเดียวกันอยู่แล้ว
- **พารามิเตอร์:**
  - `inventory`: กระเป๋าเป้าหมาย
  - `item`: ข้อมูลไอเทมที่ต้องการเพิ่ม
  - `amount`: จำนวนชิ้น (ค่าเริ่มต้นคือ 1)
- **ค่าที่ส่งคืน (Dictionary):**
  - `"success"`: `bool` บ่งบอกว่าเพิ่มสำเร็จหรือไม่
  - `"remaining"`: `int` จำนวนไอเทมที่ยัดไม่ลง (เช่น กระเป๋าเต็มก่อน)
  - `"message"`: `String` คำอธิบายสถานะ
- **Use Case:** เมื่อผู้เล่นเดินชนไอเทมดรอปบนพื้น หรือได้รับรางวัลจากเควสต์
```gdscript
var result = InventoryAPI.add_item(player_inventory, potion_item, 5)
if result.success:
    print("เพิ่มไอเทมสำเร็จ!")
elif result.remaining > 0:
    print("กระเป๋าเต็ม ของร่วงลงพื้น ", result.remaining, " ชิ้น")
```

#### `move_item(inventory: InventoryComponent, source_idx: int, target_idx: int) -> void`
ย้ายของหรือสลับของระหว่างสองช่องภายในกระเป๋าเดียวกัน
- **Use Case:** เมื่อผู้เล่นลากไอเทมด้วยเมาส์ในหน้า UI กระเป๋าตัวเอง

#### `drop_item(inventory: InventoryComponent, index: int, amount: int = -1) -> bool`
โยนไอเทมออกจากกระเป๋า ฟังก์ชันนี้จะไปหักของออกและเปล่งสัญญาณ (Signal) `InventoryManager.item_dropped`
- **Use Case:** โยนขยะทิ้ง
```gdscript
# ทิ้งของในช่องที่ 0 จำนวน 1 ชิ้น
InventoryAPI.drop_item(player_inventory, 0, 1)
```

---

### 2. ฟีเจอร์ขั้นสูง (Advanced Features)

#### `sort_inventory(inventory: InventoryComponent) -> void`
เรียงของในกระเป๋าโดยอัตโนมัติ 
- **พฤติกรรม:** ระบบจะนำไอเทมชนิดเดียวกันมากองรวมกัน (Stacking) ก่อน จากนั้นจะพยายามจัดเรียงตามขนาดของช่องตาราง (Bin Packing) ให้ใช้พื้นที่คุ้มค่าที่สุด และสุดท้ายจะดันไอเทมทั้งหมดไปอยู่ช่องแรกๆ ของกระเป๋า
- **Use Case:** ปุ่ม "จัดเรียงอัตโนมัติ" ในหน้า UI

#### `split_stack(inventory: InventoryComponent, source_idx: int, target_idx: int, amount: int) -> bool`
แบ่งของออกจากกองไปใส่ในช่องอื่น
- **Use Case:** กด Shift + ลากไอเทม เพื่อแบ่งยา 10 ขวดออกเป็นกองละ 5 ขวด

---

### 3. ระบบเควสต์และการค้าขาย (Query & Transaction)

#### `has_item_amount(inventory: InventoryComponent, item: ItemData, amount: int) -> bool`
ตรวจว่าในกระเป๋ามีไอเทมชนิดนี้รวมกันถึงจำนวนที่กำหนดหรือไม่ โดยจะบวกจำนวนจากทุกช่องที่มี
- **Use Case:** NPC ตรวจสอบก่อนส่งเควสต์ "หาเห็ด 10 ดอก"
```gdscript
if InventoryAPI.has_item_amount(player_inventory, mushroom_item, 10):
    print("เควสต์เสร็จสมบูรณ์!")
```

#### `consume_item(inventory: InventoryComponent, item: ItemData, amount: int) -> bool`
หักไอเทมออกจากกระเป๋าตามจำนวนที่กำหนด ระบบจะฉลาดพอที่จะหักของจากหลายๆ กองรวมกันจนกว่าจะครบตามจำนวน และจะคืนค่า `false` หากของมีไม่พอ (และจะไม่หักของเลย)
- **Use Case:** จ่ายเงินซื้อของ หรือส่งมอบเควสต์
```gdscript
# หักเห็ด 10 ดอก 
if InventoryAPI.consume_item(player_inventory, mushroom_item, 10):
    give_quest_reward()
else:
    print("เห็ดไม่พอ!")
```

#### `transfer_item(source_inv, target_inv, source_idx, target_idx = -1, amount = -1) -> bool`
ย้ายไอเทมข้ามกระเป๋า เช่น จากผู้เล่นไปยังหีบสมบัติ
- **พารามิเตอร์:**
  - `target_idx`: หากเป็น `-1` ระบบจะหาช่องว่างในกระเป๋าปลายทางให้เอง
  - `amount`: หากเป็น `-1` จะย้ายไปทั้งกอง
- **Use Case:** คลิกขวาที่ไอเทมเพื่อย้ายของเข้าตู้เก็บของอย่างรวดเร็ว

---

### 4. ระบบการคราฟต์ (Crafting)

#### `craft_items(inventory: InventoryComponent, registry: RecipeRegistry, slot_indices: Array[int]) -> bool`
ทดสอบนำไอเทมในช่องที่ระบุมาผสมกัน หากตรงกับสูตรใน `registry` จะทำการหักวัตถุดิบและใส่ผลลัพธ์เข้ากระเป๋า
- **Use Case:** กดปุ่ม "ผสม" ในหน้าต่าง Crafting
```gdscript
# ลองเอาของในช่อง 0 และ 1 มาผสมกัน
var success = InventoryAPI.craft_items(player_inventory, my_recipe_registry, [0, 1])
if success:
    print("คราฟต์สำเร็จ!")
```

---

## 🗡️ EquipmentAPI (`equipment_api.gd`)

API สำหรับจัดการเรื่องการสวมใส่ชุดและอาวุธ

#### `equip_from_inventory(equipment: EquipmentComponent, inventory: InventoryComponent, inv_idx: int) -> bool`
ถอดไอเทมจากช่องในกระเป๋า ไปใส่ในช่องสวมใส่ที่ถูกต้อง (ระบบจะเช็ค Category อัตโนมัติว่าใส่ตรงช่องหรือไม่)
- **Use Case:** ดับเบิลคลิกที่เสื้อเกราะในกระเป๋า เพื่อสวมใส่

#### `unequip_to_inventory(equipment: EquipmentComponent, inventory: InventoryComponent, equip_category: StringName) -> bool`
ถอดอุปกรณ์ที่ใส่อยู่ออก และย้ายกลับไปเก็บในกระเป๋าที่ว่างอยู่
- **Use Case:** ถอดดาบเก็บใส่กระเป๋า

---

## 💾 ระบบ Save/Load
การเซฟไฟล์กระเป๋า ไม่จำเป็นต้องไล่วนลูปเอง ระบบมีคำสั่งสำเร็จรูปให้แล้ว
- **`InventoryAPI.save_to_file(inventory, equipment, "user://save1.tres")`**
- **`InventoryAPI.load_from_file(inventory, equipment, "user://save1.tres")`**
