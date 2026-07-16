# Universal Inventory: AI Prompting Guide

เอกสารฉบับนี้ถูกออกแบบมาเพื่อ **"ป้อนให้ AI (เช่น ChatGPT, Claude, Copilot)"** อ่านก่อนที่จะสั่งให้มันเขียนโค้ดที่เกี่ยวกับปลั๊กอินนี้ เพื่อให้ AI เข้าใจโครงสร้าง สถาปัตยกรรม และข้อจำกัดต่างๆ อย่างแม่นยำ ป้องกันการเขียนโค้ดมั่ว (Hallucination) หรือหลุดกรอบแนวคิด

> **คำแนะนำสำหรับผู้ใช้งาน:** ให้ Copy เนื้อหาในหน้านี้ไปแปะใน Prompt แรกของคุณ หรือแนบเป็นไฟล์ `.txt` / ให้ Cursor อ่านไฟล์นี้เป็น `Rules` ก่อนเริ่มทำงาน

---

## 🛑 1. กฎข้อห้ามที่ชัดเจน (Hard Constraints)
ในการเขียนโค้ดสร้าง `ItemModule` ใหม่ หรือเขียนโค้ดใช้งาน API กรุณาปฏิบัติตามกฎต่อไปนี้อย่างเคร่งครัด:

1. **ห้ามเข้าถึง State ภายนอก (No Global/Outside State):** 
   - `ItemModule` ต้องทำงานเหมือนฟังก์ชันคณิตศาสตร์ (Pure Calculation) 
   - ห้ามเรียกใช้ `get_node()`, `get_tree()`, หรือเข้าถึง `Autoload / Singleton` เด็ดขาด! โค้ดจะต้องรับ Input เข้ามา ทำการคำนวณ แล้ว Return Dictionary ออกไปเท่านั้น
2. **ห้ามยุ่งกับ UI หรือ SceneTree (UI & Node Agnostic):**
   - ห้ามใช้ `spawn()`, ห้าม `queue_free()`, ห้ามเรียกไฟล์เสียง (`AudioStreamPlayer`), หรือเล่น Effect ในโมดูล
   - `ItemModule` มีหน้าที่แค่ **คืนค่า Payload** โยนกลับไปให้เกม ส่วนเกมจะนำข้อมูลนั้นไปวาด UI หรือเล่นเสียงเอง
3. **ห้ามสร้าง Subclass หรือแก้ไข Core (Favor Composition):**
   - ห้ามเขียนคลาสใหม่ที่สืบทอดจาก `ItemData` (ห้าม `extends ItemData`) ไอเทมทุกชิ้นต้องเกิดจากการนำ `ItemModule` มาประกอบกัน (Composition) ลงบน `ItemData` พื้นฐาน
   - ห้ามแก้ไขสคริปต์ในโฟลเดอร์ `core/` เด็ดขาด ให้เรียกใช้ผ่าน `InventoryAPI` เสมอ

---

## 🌊 2. Data Flow (การไหลของข้อมูล)
เพื่อให้คุณเห็นภาพรวมของการทำงาน ขอให้ยึดลำดับการทำงานต่อไปนี้:

1. **UI / Input:** ผู้เล่นกดคลิกขวาที่ไอเทมในกระเป๋า (UI โง่ๆ ไม่รู้อะไรเลย)
2. **Request:** UI โยนคำสั่งไปให้ `InventoryAPI.use_item(...)`
3. **Framework (Core):** แกนหลักของปลั๊กอินจะรับคำสั่ง และวนลูปเรียกฟังก์ชัน `on_use()` ในทุกๆ โมดูลของไอเทมนั้น
4. **Modules:** โมดูลทำการคำนวณ (Pure Calculation) และรวบรวม `effects` ส่งกลับไปเป็น Dictionary
5. **System / Signal:** Core จะยิง Signal `InventoryManager.item_used` ห้อย `effects` payload ทั้งหมดไปให้เกม
6. **Game / Result:** โค้ดของเกมหลัก (Player.gd หรือ GameController.gd) ได้รับ Signal แล้วทำการลดเลือด เล่นเสียง เอฟเฟกต์ ฯลฯ

---

## 📋 3. โค้ดตัวอย่างตั้งต้น (Boilerplate / Code Templates)

### 3.1 Template สำหรับสร้าง `ItemModule` ใหม่
AI ควรใช้ Template นี้ในการสร้างความสามารถใหม่ๆ ให้กับไอเทม:

```gdscript
extends ItemModule
class_name YourNewModule

# 1. กำหนดตัวแปรที่ต้องการให้ Game Designer ปรับได้ผ่าน Inspector
@export var damage_amount: float = 10.0
@export var element_type: StringName = &"fire"

# 2. Hook ที่ใช้บ่อยที่สุด: เมื่อผู้เล่นกดใช้งานไอเทม
func on_use(slot: InventorySlot, user_context: Dictionary) -> Dictionary:
    # อ่านข้อมูล runtime ปัจจุบัน (ถ้ามี)
    var current_durability = slot.runtime_data.get("durability", 100)
    
    # ห้ามยุ่งกับ Node หรือ UI! แค่เตรียมข้อมูล Payload ส่งกลับไป
    var payload = {
        "type": "deal_damage",
        "amount": damage_amount,
        "element": element_type
    }
    
    return {
        # จำนวนชิ้นที่จะถูกหักออกจากกระเป๋า
        "consumed_amount": 1,
        # ส่งต่อ Payload ให้เกมเอาไปจัดการต่อ
        "effects": [payload],
        # ถ้าต้องการลบหรือแก้ตัวแปร runtime
        "runtime_data_updates": {
            "durability": current_durability - 1
        }
    }

# 3. Hook สำหรับการทำงานเป็น Background (Tick)
func on_update(slot: InventorySlot, delta: float) -> Dictionary:
    # ใช้สำหรับกรณีที่ไอเทมต้องเสื่อมสภาพตามเวลา ฯลฯ
    return {}
```

### 3.2 Template สำหรับฝั่ง Game (เพื่อรอรับ Signal)
เมื่อคุณเขียนโมดูลเสร็จ อย่าลืมเขียนโค้ดฝั่งเกมเพื่อรอรับ Payload ไปประมวลผลต่อ:

```gdscript
extends Node

func _ready():
    # รับ Signal ดักฟังเหตุการณ์การใช้งานไอเทมทุกชิ้น
    InventoryManager.item_used.connect(_on_inventory_item_used)

func _on_inventory_item_used(item: ItemData, effects: Array):
    # วนลูปอ่าน payload ที่โมดูลส่งมา
    for effect in effects:
        match effect.get("type"):
            "deal_damage":
                # ทำการลด HP หรือเล่นเสียงตรงนี้
                deal_damage_to_enemies(effect.amount, effect.element)
            "heal_player":
                player.heal(effect.amount)
```

---

## 🛠️ 4. รายการ API พื้นฐาน (Available Hooks & Interfaces)
เพื่อป้องกันการตั้งชื่อฟังก์ชันมั่ว นี่คือรายชื่อฟังก์ชันและ Object ที่คุณสามารถเรียกใช้ได้:

### คลาส `ItemModule` (เขียนทับ/Override ได้)
- `func on_use(slot: InventorySlot, user_context: Dictionary) -> Dictionary`
- `func on_update(slot: InventorySlot, delta: float) -> Dictionary`
- `func before_use(slot: InventorySlot, user_context: Dictionary) -> Dictionary` (คืนค่า `{"prevented": true}` หากต้องการสั่งห้ามใช้ไอเทม)

### คลาส `InventoryAPI` (เรียกใช้เพื่อควบคุมกระเป๋า)
- `InventoryAPI.add_item(inventory: InventoryComponent, item: ItemData, amount: int = 1) -> Dictionary`
- `InventoryAPI.drop_item(inventory: InventoryComponent, index: int, amount: int = -1) -> bool`
- `InventoryAPI.has_item_amount(inventory: InventoryComponent, item: ItemData, amount: int) -> bool`
- `InventoryAPI.consume_item(inventory: InventoryComponent, item: ItemData, amount: int) -> bool`
- `InventoryAPI.craft_items(inventory: InventoryComponent, registry: RecipeRegistry, slot_indices: Array[int]) -> bool`

### คลาส `ConditionManager` (ระบบสถานะบัฟ/ดีบัฟ)
- `apply_condition(effect: ConditionEffect, target: Node, user_context: Dictionary)`
- `has_condition(stat_target: StringName, target: Node) -> bool`
- `get_modified_stat(stat_type: StringName, base_value: float, target: Node) -> float`
