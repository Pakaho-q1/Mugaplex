# คู่มือการใช้งาน API (API Reference)

การเขียนโค้ดสั่งงานกระเป๋า ควรทำผ่าน **API Layer** เสมอ เพื่อลดความผิดพลาดและหลีกเลี่ยงการทำลาย Data ของระบบ

## InventoryAPI (`inventory_api.gd`)

เรียกใช้ผ่านการพิมพ์ `InventoryAPI.ชื่อฟังก์ชัน()` ได้ทุกที่

### 1. การจัดการขั้นพื้นฐาน
- **`add_item(inventory, item, amount)`**
  เพิ่มไอเทมเข้ากระเป๋า คืนค่าเป็น `Dictionary` {success, remaining, message}
- **`move_item(inventory, source_idx, target_idx)`**
  สลับตำแหน่ง/ย้ายของภายในกระเป๋าเดียวกัน
- **`use_item(inventory, index, user_node)`**
  กดใช้ไอเทม
- **`drop_item(inventory, index, amount)`**
  ทิ้งไอเทมลงพื้น (ยิง Signal ออกไปให้เกมหลัก)

### 2. ฟีเจอร์ขั้นสูง (Advanced Features)
- **`sort_inventory(inventory)`**
  จัดเรียงกระเป๋าอัตโนมัติ (Bin Packing) พร้อมรวมกองไอเทมให้
- **`split_stack(inventory, source_idx, target_idx, amount)`**
  แบ่งกองไอเทมไปวางที่ช่องอื่น

### 3. ฟีเจอร์เควสต์และการแลกเปลี่ยน (Query & Transfer)
- **`has_item_amount(inventory, item, amount) -> bool`**
  เช็คว่ามีของครบไหม (นับรวมทุกกอง)
- **`consume_item(inventory, item, amount) -> bool`**
  หักของจากกระเป๋า (หักหลายกองรวมกันให้)
- **`transfer_item(source, target, source_idx, target_idx, amount) -> bool`**
  ย้ายของข้ามกล่อง (ผู้เล่น -> หีบ)

### 4. การเซฟและโหลด (Save/Load)
- **`save_to_file(inventory, equipment, path)`**
- **`load_from_file(inventory, equipment, path)`**
