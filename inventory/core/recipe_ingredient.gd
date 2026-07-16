extends Resource
class_name RecipeIngredient

## The item required for this ingredient.
@export var item: ItemData = null
## The number of this item required.
@export_range(1, 99999) var amount: int = 1
