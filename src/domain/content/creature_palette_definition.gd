class_name CreaturePaletteDefinition
extends Resource
## Restricted sprite palette authored as portable HTML color values.

@export var primary: String
@export var secondary: String
@export var accent: String
@export var outline: String


func colors() -> Array[String]:
	return [primary, secondary, accent, outline]
