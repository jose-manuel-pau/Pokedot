class_name ItemDefinition
extends Resource
## Immutable item content. Runtime quantities live in Inventory; battle and
## capture effects are interpreted by application services.

const CATEGORY_CAPTURE_DEVICE := "capture_device"
const CATEGORY_HEALING := "healing"
const CATEGORY_REVIVAL := "revival"
const CATEGORY_STATUS_REMEDY := "status_remedy"
const CATEGORY_BATTLE_CONSUMABLE := "battle_consumable"
const CATEGORY_KEY_ITEM := "key_item"
const VALID_CATEGORIES: Array[String] = [
	CATEGORY_CAPTURE_DEVICE,
	CATEGORY_HEALING,
	CATEGORY_REVIVAL,
	CATEGORY_STATUS_REMEDY,
	CATEGORY_BATTLE_CONSUMABLE,
	CATEGORY_KEY_ITEM,
]

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_enum(
	"capture_device",
	"healing",
	"revival",
	"status_remedy",
	"battle_consumable",
	"key_item"
) var category: String = CATEGORY_BATTLE_CONSUMABLE
@export_range(1, 999, 1) var max_stack: int = 99
@export var consumable: bool = true
@export var battle_usable: bool = true
@export_range(0, 999999, 1) var purchase_price: int = 0
@export_range(0.01, 10.0, 0.01) var capture_multiplier: float = 1.0
@export_range(0, 9999, 1) var healing_amount: int = 0
@export_range(0.0, 1.0, 0.01) var healing_fraction: float = 0.0
@export var cured_status_ids: Array[StringName] = []


func is_capture_device() -> bool:
	return category == CATEGORY_CAPTURE_DEVICE


func is_healing_item() -> bool:
	return category == CATEGORY_HEALING


func is_revival_item() -> bool:
	return category == CATEGORY_REVIVAL


func is_status_remedy() -> bool:
	return category == CATEGORY_STATUS_REMEDY
