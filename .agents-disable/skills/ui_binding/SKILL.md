---
name: Bind Universal Inventory UI
description: "Guidelines for correctly linking game data to the Universal Inventory UI without writing logic in UI scripts."
---

# UI Binding Guide (Dumb UI)
The Universal Inventory follows a strict "Dumb UI" concept. UI scripts do not process logic; they only draw state based on signals and send inputs to the `InventoryAPI`.

## Rules
- Do NOT write logic in UI scripts (e.g. checking if the player has enough gold).
- To bind an inventory to a UI element, call `set_inventory()` on the UI component and pass the core `InventoryComponent`.

## Snippets

### Binding UI to Player Inventory
```gdscript
# Inside Player.gd or UIManager.gd
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var player_inventory = $Player/InventoryComponent

func _ready():
    # This automatically connects all necessary signals
    inventory_ui.set_inventory(player_inventory)
```

### Listening to Core Signals (Instead of UI Signals)
Instead of listening to UI clicks, listen to the framework's core signals.
```gdscript
func _ready():
    InventoryManager.item_used.connect(_on_item_used)

func _on_item_used(item: ItemData, effects: Array):
    pass
```
