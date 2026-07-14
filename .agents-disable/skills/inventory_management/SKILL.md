---
name: Use Universal Inventory API
description: "Guidelines and snippets for manipulating the Universal Inventory via the API Layer (add, drop, move, consume)."
---

# Inventory Management (InventoryAPI)
When asked to write code that interacts with the inventory, ALWAYS use `InventoryAPI`. Never mutate variables on `InventoryComponent` directly.

## Rules
- Call static methods directly: `InventoryAPI.add_item(...)`
- Pass the `InventoryComponent` node as the first argument.

## Common Snippets

### Adding Items
```gdscript
var result = InventoryAPI.add_item(player_inventory, item_data, amount)
if result.success:
    pass
elif result.remaining > 0:
    print("Failed to add ", result.remaining, " items")
```

### Checking and Consuming (For Quests or Shops)
```gdscript
if InventoryAPI.has_item_amount(player_inventory, wood_item, 10):
    InventoryAPI.consume_item(player_inventory, wood_item, 10)
    print("Wood consumed successfully")
```

### Crafting
```gdscript
var success = InventoryAPI.craft_items(player_inventory, recipe_registry, [slot_idx1, slot_idx2])
```
