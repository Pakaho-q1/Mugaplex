---
name: Create Universal Inventory Item Module
description: "Creates a new ItemModule for the Universal Inventory plugin, strictly adhering to pure calculation and data-driven constraints."
---

# Create Item Module
When asked to create a new item capability or module, follow these guidelines:

## Rules
- Extend `ItemModule` and provide a `class_name`.
- Use `@export` for configuration variables so game designers can edit them in the Inspector.
- Do NOT modify the game world directly. Return a dictionary payload containing `effects`, `consumed_amount`, or `runtime_data_updates`.
- Do NOT use `get_node()`, `get_tree()`, Singletons, or play sounds.
- Override `on_use()` for active items.
- Override `on_update()` for periodic background updates (like ticking durability or expiration).

## Template

```gdscript
extends ItemModule
class_name YourCustomModule

@export var example_amount: float = 10.0

func on_use(slot: InventorySlot, user_context: Dictionary) -> Dictionary:
    # 1. Read existing runtime data if needed
    var current_state = slot.runtime_data.get("state_key", 100)
    
    # 2. Package instructions for the game to execute
    var payload = {
        "type": "custom_effect",
        "amount": example_amount
    }
    
    # 3. Return the result dictionary
    return {
        "consumed_amount": 1, # How many items to consume
        "effects": [payload], # Payload for the game to handle via signal
        "runtime_data_updates": {
            "state_key": current_state - 1 # Real-time state updates
        }
    }
```
