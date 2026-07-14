<div align="center">
  <img src="icon.svg" width="128" height="128" alt="Universal Inventory Logo">
  <h1>Universal Inventory Plugin for Godot 4</h1>
  
  <p><strong>A highly modular, data-driven, and headless inventory framework for Godot 4.x.</strong></p>

  <p>
    <img alt="Godot 4.x" src="https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine">
    <img alt="License" src="https://img.shields.io/badge/License-MIT-green">
    <img alt="Platform" src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey">
  </p>
</div>

<br>

**Universal Inventory** ไม่ใช่แค่ระบบกระเป๋าเก็บของธรรมดา แต่มันคือ **Core Gameplay Framework** ที่ถูกออกแบบมาด้วยแนวคิด "Engine Independence" (เป็นอิสระจากโหนดของ Engine) และ "Data-Driven" ทำให้คุณสามารถนำไปประยุกต์ใช้กับเกมได้ทุกแนว ไม่ว่าจะเป็น Action RPG, Survival Crafting, Card Game, หรือ Turn-based Strategy

---

## ✨ Features (จุดเด่น)

- 🧩 **100% Modular Architecture:** ขยายขีดความสามารถของไอเทมได้อย่างไร้ขีดจำกัดด้วยระบบ `ItemModule` (เช่น อาหารเน่าเสียได้, อาวุธตีบวก, ปืนที่มีกระสุนจำกัด)
- ⚙️ **Headless & Dumb UI:** ลอจิกการคำนวณ (Core) ถูกแยกขาดจากส่วนแสดงผล (UI) อย่างเด็ดขาด คุณสามารถรันระบบนี้บนฝั่งเซิร์ฟเวอร์แบบไร้ UI หรือจะสร้าง UI แบบ 3D VR ขึ้นมาครอบทับก็ทำได้โดยไม่ต้องแก้โค้ด Core
- 📏 **Grid & Slot Support:** รองรับกระเป๋าทั้งแบบช่องเดี่ยวๆ (List) และกระเป๋าแบบ Grid 2D (Bin Packing)
- 🛠️ **Crafting System:** ระบบคราฟต์ที่แยกเป็นอิสระ (`ItemData + ItemData = ItemData`) คราฟต์ไอเทมในกระเป๋าได้ทันทีผ่าน `RecipeRegistry`
- 💥 **Condition & Reaction System:** ระบบสถานะแบบ "ปฏิกิริยาธาตุ" (`Condition + Condition = New Condition`) ตัวละครสามารถเกิดปฏิกิริยาได้ เช่น เปียกน้ำ + ไฟไหม้ = ควันพรางตัว
- 📦 **Save / Load System:** รองรับการเซฟและโหลดข้อมูลกระเป๋าทั้งหมด รวมถึงสถานะ Runtime ของไอเทม (ความทนทาน, เวลาเน่าเสีย) ได้อย่างสมบูรณ์
- ⚡ **Event-Driven:** แจ้งเตือนทุกการเปลี่ยนแปลงผ่านระบบ Signal ทำให้ระบบอื่นในเกม (เช่น ระบบ UI หรือ Player Stats) ตอบสนองได้ทันที

---

## 🚀 Installation (การติดตั้ง)

1. ดาวน์โหลดและแตกไฟล์
2. คัดลอกโฟลเดอร์ `addons/universal_inventory` ไปวางไว้ในโปรเจกต์ Godot ของคุณ (ในโฟลเดอร์ `addons/`)
3. เปิด Godot Editor ไปที่เมนู **Project > Project Settings > Plugins**
4. ติ๊กเครื่องหมายถูก (Enable) ที่ปลั๊กอิน **Universal Inventory**

---

## 🎯 Quick Start (การใช้งานเบื้องต้น)

ระบบถูกออกแบบมาให้เรียกใช้งานได้ง่ายผ่าน `InventoryAPI` โดยไม่ต้องเขียนโค้ดยุ่งยาก

### การเพิ่มไอเทมเข้ากระเป๋า
```gdscript
# โหลดข้อมูลไอเทม
var health_potion = preload("res://items/health_potion.tres")

# นำไอเทมใส่กระเป๋าผู้เล่น 5 ชิ้น
var result = InventoryAPI.add_item(player_inventory, health_potion, 5)

if result.success:
    print("เพิ่มยาสำเร็จ!")
else:
    print("กระเป๋าเต็ม!")
```

### การตรวจสอบและหักไอเทม (ส่งเควสต์)
```gdscript
var wood = preload("res://items/wood.tres")

# เช็คว่ามีไม้ถึง 10 ท่อนหรือไม่ ถ้ามีให้หักออก
if InventoryAPI.consume_item(player_inventory, wood, 10):
    print("สร้างบ้านสำเร็จ!")
else:
    print("ไม้ไม่พอ!")
```

---

## 📚 Documentation (สารบัญคู่มือ)

เพื่อให้คุณเข้าใจวิสัยทัศน์และนำระบบนี้ไปใช้ได้อย่างเต็มประสิทธิภาพ กรุณาอ่านเอกสารแนะนำ (Whitepaper) ในโฟลเดอร์ `docs/`:

- 🏗️ [**Architecture (สถาปัตยกรรมและการออกแบบ)**](docs/architecture.md) - *แนะนำให้ผู้พัฒนาทุกคนอ่านเป็นอันดับแรก*
- 📖 [**API Reference (คู่มืออ้างอิง API)**](docs/api_reference.md) - อธิบายการเรียกใช้งานฟังก์ชัน พร้อม Use Case
- 🛠️ [**Creating Items (คู่มือการสร้างไอเทม)**](docs/creating_items.md) - สอนวิธีใช้ Data-Driven และการเขียน Custom Module
- 🎨 [**UI Guide (คู่มือการสร้างหน้าต่าง UI)**](docs/ui_guide.md) - เจาะลึกคอนเซปต์ "Dumb UI" และการเชื่อมต่อกับระบบ
- 🤖 [**AI Prompting Guide (คู่มือสำหรับป้อน AI)**](docs/ai_prompt_guide.md) - สำหรับโยนให้ ChatGPT/Copilot อ่านก่อนสั่งเขียนโค้ด เพื่อป้องกันการหลุดกรอบแนวคิด

---

## 📝 License (ลิขสิทธิ์)

โปรเจกต์นี้เปิดเผยซอร์สโค้ดภายใต้สัญญาอนุญาตแบบ [MIT License](LICENSE) คุณสามารถนำไปใช้งานในเกมของคุณ (ทั้งเชิงพาณิชย์และแจกฟรี) ได้อย่างอิสระ
