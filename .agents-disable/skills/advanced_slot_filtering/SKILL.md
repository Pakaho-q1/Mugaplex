---
name: Configure Universal Inventory Slots
description: "Guidelines for configuring InventorySlot rules, such as restricting slots to specific item categories or modules (e.g. Fridge, Equipment)."
---

# Advanced Slot Filtering
`InventorySlot` in Universal Inventory is incredibly powerful. It is not just a container; it has a robust rule-engine that can reject or accept items based on `Category` or `Module` presence.

## Rules
- When you want to create a restricted container (like a Fridge that only accepts food, or a Weapon Slot that only accepts swords), you configure the `InventorySlot` directly.
- `accepted_categories`: Array of string names. If set, the slot will only accept items that have at least one module granting this category.
- `accepted_modules`: Array of `Script`. If set, the slot will only accept items that contain at least one of these modules.
- `max_amount_override`: Set this to `1` for equipment slots to ensure items don't stack inside the equipment UI.

## Snippets

### Creating an Equipment Slot (e.g., Helmet)
This slot will only accept items with the category `equip_head` and will prevent stacking.

```gdscript
var head_slot = InventorySlot.new()
head_slot.accepted_categories = [&"equip_head"]
head_slot.max_amount_override = 1
```

### Creating a Fridge (Only accepts Perishable items)
This slot will only accept items that contain the `PerishableModule` script.

```gdscript
var fridge_slot = InventorySlot.new()
fridge_slot.accepted_modules = [preload("res://addons/mugaplex/inventory/modules/perishable_module.gd")]
```

### Checking if an item can be accepted
The API automatically uses this under the hood, but you can also use it manually for your custom UI dragging logic.

```gdscript
if head_slot.can_accept(helmet_item_data):
    print("This item can be placed here!")
else:
    print("Invalid item for this slot!")
```
