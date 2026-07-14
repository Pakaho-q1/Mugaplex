# Universal Inventory: Core Philosophy & Hard Constraints

When working on the `universal_inventory` plugin, always adhere to the following rules:

1. **Favor Composition over Inheritance**: Never subclass `ItemData`. New items and features must be built by combining `ItemModule`s.
2. **Pure Calculation Modules**: `ItemModule` scripts must behave like pure mathematical functions. They receive input (via `slot`, `user_context`, `delta`), process it, and return a dictionary (`payload`). 
3. **No Global State in Modules**: `ItemModule` scripts must NEVER access singletons, autoloads, or outer scope variables.
4. **No UI or Nodes in Modules**: `ItemModule` scripts must NEVER spawn nodes, `queue_free()` anything, play sounds, or interact with UI. They only return `effects` payloads.
5. **Dumb UI Principle**: UI components should NEVER contain game logic. They should only observe signals (like `inventory_changed`) to redraw, and forward player input (clicks, drags) to `InventoryAPI`.
6. **Data-Driven Conditions**: When applying statuses (buffs/debuffs), use `ConditionManager` and pass `ConditionEffect` resources. Understand that `ModifierType` processes as ADD -> MULTIPLY -> OVERRIDE.
