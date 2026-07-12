extends Resource
class_name ItemRecipe

@export var ingredients: Array[ItemData] = []
@export var result_item: ItemData = null
@export var result_amount: int = 1
@export var priority: int = 0
