extends Resource
class_name ItemRecipe

## List of ingredients required. Each ingredient specifies an item AND the amount needed.
## Supports unlimited ingredients at unlimited quantities (e.g. 100 types x 1000 each).
@export var ingredients: Array[RecipeIngredient] = []
## The item produced when the recipe succeeds.
@export var result_item: ItemData = null
## The number of result_item produced.
@export_range(1, 9999) var result_amount: int = 1
## Higher priority recipes are checked first when multiple recipes match the same ingredients.
@export var priority: int = 0
