import re
import sys

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Pattern 1: slot.get_owning_slot() where slot is declared nearby or loop var
    # E.g. var owning_slot = slot.get_owning_slot() -> var owning_slot = inventory.get_owning_slot(idx) (we need index, wait)
    
    # Actually, let's just write exactly what needs to be replaced using replace()
    replacements = [
        ("var slot = inventory.slots[slot_index].get_owning_slot()", "var slot = inventory.get_owning_slot(slot_index)"),
        ("var owning_slot = slot.get_owning_slot()", "var owning_slot = inventory.get_owning_slot(index)"), # Wait, line 65 uses index
        ("var slot = inventory.slots[idx].get_owning_slot()", "var slot = inventory.get_owning_slot(idx)"),
        ("var source_slot = inventory.slots[source_idx].get_owning_slot()", "var source_slot = inventory.get_owning_slot(source_idx)"),
        ("var t_owning = target_slot.get_owning_slot()", "var t_owning = target_inv.get_owning_slot(target_idx)"), # line 410 uses target_inv
        # line 196: target_slot.get_owning_slot() -> inventory.get_owning_slot(target_idx)
        ("var t_owning = target_slot.get_owning_slot()", "var t_owning = inventory.get_owning_slot(target_idx)"),
        ("var source_slot = source_inv.slots[source_idx].get_owning_slot()", "var source_slot = source_inv.get_owning_slot(source_idx)"),
        ("if slot.item != null and slot.occupied_by == null:", "if slot.item != null and slot.occupied_by_index == -1:")
    ]
    
    # manual line-by-line replacements for loops
    lines = content.split('\n')
    for i in range(len(lines)):
        # line 65
        if 'var owning_slot = slot.get_owning_slot()' in lines[i] and 'drop_item' in lines[i-5]:
            lines[i] = lines[i].replace('slot.get_owning_slot()', 'inventory.get_owning_slot(index)')
        # line 196
        elif 'var t_owning = target_slot.get_owning_slot()' in lines[i] and 'split_stack' in lines[20]: # rough check
            if i < 250:
                lines[i] = lines[i].replace('target_slot.get_owning_slot()', 'inventory.get_owning_slot(target_idx)')
            else:
                lines[i] = lines[i].replace('target_slot.get_owning_slot()', 'target_inv.get_owning_slot(target_idx)')
        
        # loops
        elif 'var owning_slot = slot.get_owning_slot()' in lines[i]:
            # This is inside a loop `for i in range(inventory.slots.size()):`
            lines[i] = lines[i].replace('slot.get_owning_slot()', 'inventory.get_owning_slot(i)')
        elif 'for slot in inventory.slots:' in lines[i]:
            # Line 319
            lines[i] = lines[i].replace('for slot in inventory.slots:', 'for i in range(inventory.slots.size()):\n\t\tvar slot = inventory.slots[i]')

    content = '\n'.join(lines)
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

process_file("d:/WindowsMega/game-maker/study/addons/mugaplex/inventory/api/inventory_api.gd")
print("Done")
