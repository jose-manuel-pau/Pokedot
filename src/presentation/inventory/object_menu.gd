class_name ObjectMenu
extends Control
## Map-accessible inventory adapter. Item effects and stock mutations remain in
## FieldItemUseService; this node only manages selection and presentation.

signal object_used(item_id: StringName, instance_id: String, healing_applied: int)
signal menu_closed

const POTION_PRIORITY: Array[StringName] = [
	&"potion",
	&"mega_potion",
	&"ultra_potion",
]

@onready var count_label: Label = $Shade/Panel/Margin/Content/Header/Count
@onready var title_label: Label = $Shade/Panel/Margin/Content/Header/Title
@onready var item_list: VBoxContainer = $Shade/Panel/Margin/Content/Body/Items/ItemMargin/ItemContent/Scroll/ItemList
@onready var target_grid: GridContainer = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/TargetScroll/TargetGrid
@onready var item_name: Label = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/ItemName
@onready var item_description: Label = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/Description
@onready var potency_label: Label = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/Potency
@onready var target_name: Label = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/TargetName
@onready var health_bar: ProgressBar = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/Health
@onready var health_label: Label = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/HealthText
@onready var feedback_label: Label = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/Feedback
@onready var use_button: Button = $Shade/Panel/Margin/Content/Body/UsePanel/UseMargin/UseContent/Use
@onready var close_button: Button = $Shade/Panel/Margin/Content/Header/Close

var _catalog: ContentCatalog
var _inventory: Inventory
var _collection: CreatureCollection
var _preferences: PlayerPreferences
var _field_items: FieldItemUseService
var _selected_item_id: StringName = &""
var _selected_target_id: String = ""
var _listed_item_ids: Array[StringName] = []
var _item_buttons: Array[Button] = []
var _target_buttons: Array[Button] = []


func _ready() -> void:
	use_button.pressed.connect(use_selected_item)
	close_button.pressed.connect(close_menu)
	hide()
	set_process_unhandled_input(true)


func open_menu(
	catalog: ContentCatalog,
	inventory: Inventory,
	collection: CreatureCollection,
	preferred_target_id: String = "",
	preferences: PlayerPreferences = null
) -> void:
	_catalog = catalog
	_inventory = inventory
	_collection = collection
	_preferences = preferences
	_field_items = FieldItemUseService.new(_catalog)
	_selected_target_id = preferred_target_id
	feedback_label.text = "Choose an object and a conscious creature."
	_rebuild_item_buttons()
	_rebuild_target_buttons()
	_apply_preferences()
	show()
	_focus_selection()


func close_menu() -> void:
	if not visible:
		return
	hide()
	menu_closed.emit()


func choose_item(item_id: StringName) -> bool:
	if not _listed_item_ids.has(item_id):
		return false
	_selected_item_id = item_id
	feedback_label.text = "Choose a target, then use the object."
	_refresh_item_buttons()
	_refresh_details()
	return true


func choose_target(instance_id: String) -> bool:
	if _collection == null or _collection.find_instance(instance_id) == null:
		return false
	_selected_target_id = instance_id
	feedback_label.text = "Ready to use the selected object."
	_refresh_target_buttons()
	_refresh_details()
	return true


func use_selected_item() -> bool:
	if _field_items == null:
		return false
	var target := _collection.find_instance(_selected_target_id) \
		if _collection != null else null
	var item := _catalog.get_item(_selected_item_id) if _catalog != null else null
	var result := _field_items.use_on_creature(
		_inventory,
		_selected_item_id,
		target
	)
	if not result.success:
		feedback_label.text = "Cannot use object: %s." % _humanize(result.reason)
		_refresh_details()
		return false
	var used_item_id := _selected_item_id
	var used_name := item.display_name
	var target_display_name := _display_name(target)
	_rebuild_item_buttons()
	_rebuild_target_buttons()
	feedback_label.text = "%s restored %d HP to %s." % [
		used_name,
		result.healing_applied,
		target_display_name,
	]
	object_used.emit(used_item_id, target.instance_id, result.healing_applied)
	return true


func set_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_apply_preferences()


func get_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_listed_item_ids)
	return result


func get_target_instance_ids() -> Array[String]:
	var result: Array[String] = []
	if _collection == null:
		return result
	for creature in _collection.get_all_creatures():
		result.append(creature.instance_id)
	return result


func get_selected_item_id() -> StringName:
	return _selected_item_id


func get_selected_target_id() -> String:
	return _selected_target_id


func get_item_button(item_id: StringName) -> Button:
	for button in _item_buttons:
		if StringName(str(button.get_meta("item_id", ""))) == item_id:
			return button
	return null


func get_target_button(instance_id: String) -> Button:
	for button in _target_buttons:
		if str(button.get_meta("instance_id", "")) == instance_id:
			return button
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_B, KEY_ESCAPE]:
		close_menu()
		get_viewport().set_input_as_handled()


func _rebuild_item_buttons() -> void:
	for child in item_list.get_children():
		child.free()
	_item_buttons.clear()
	_listed_item_ids = _ordered_owned_item_ids()
	count_label.text = "%d OBJECT TYPES" % _listed_item_ids.size()
	if not _listed_item_ids.has(_selected_item_id):
		_selected_item_id = _listed_item_ids[0] if not _listed_item_ids.is_empty() else &""
	for item_id in _listed_item_ids:
		var item := _catalog.get_item(item_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(380, 62)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.set_meta("item_id", item_id)
		button.text = "%s\n%s  ·  x%d" % [
			item.display_name,
			str(item.category).replace("_", " ").to_upper(),
			_inventory.get_quantity(item_id),
		]
		button.pressed.connect(choose_item.bind(item_id))
		item_list.add_child(button)
		_item_buttons.append(button)
	_refresh_item_buttons()
	_refresh_details()


func _ordered_owned_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if _inventory == null:
		return result
	for item_id in POTION_PRIORITY:
		if _inventory.has(item_id):
			result.append(item_id)
	var remaining: Array[StringName] = []
	for raw_item_id in _inventory.quantities_by_item_id.keys():
		var item_id := StringName(str(raw_item_id))
		if not result.has(item_id) and _catalog.get_item(item_id) != null:
			remaining.append(item_id)
	remaining.sort_custom(func(first: StringName, second: StringName) -> bool:
		return _catalog.get_item(first).display_name.naturalnocasecmp_to(
			_catalog.get_item(second).display_name
		) < 0
	)
	result.append_array(remaining)
	return result


func _rebuild_target_buttons() -> void:
	for child in target_grid.get_children():
		child.free()
	_target_buttons.clear()
	var creatures := _collection.get_all_creatures() if _collection != null else []
	if _collection == null or _collection.find_instance(_selected_target_id) == null:
		_selected_target_id = creatures[0].instance_id if not creatures.is_empty() else ""
	for creature in creatures:
		var maximum := _maximum_hp(creature)
		var button := Button.new()
		button.custom_minimum_size = Vector2(265, 58)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.set_meta("instance_id", creature.instance_id)
		button.text = "%s   Lv. %d\nHP %d / %d" % [
			_display_name(creature),
			creature.level,
			clampi(creature.current_hp, 0, maximum),
			maximum,
		]
		button.pressed.connect(choose_target.bind(creature.instance_id))
		target_grid.add_child(button)
		_target_buttons.append(button)
	_refresh_target_buttons()
	_refresh_details()


func _refresh_item_buttons() -> void:
	for button in _item_buttons:
		button.button_pressed = StringName(str(button.get_meta("item_id", ""))) \
			== _selected_item_id


func _refresh_target_buttons() -> void:
	for button in _target_buttons:
		button.button_pressed = str(button.get_meta("instance_id", "")) \
			== _selected_target_id


func _refresh_details() -> void:
	if not is_node_ready():
		return
	var item := _catalog.get_item(_selected_item_id) if _catalog != null else null
	var target := _collection.find_instance(_selected_target_id) \
		if _collection != null else null
	if item == null:
		item_name.text = "NO OBJECTS"
		item_description.text = "Your bag is empty."
		potency_label.text = ""
		use_button.text = "USE OBJECT"
		use_button.disabled = true
		return
	item_name.text = item.display_name
	item_description.text = item.description
	potency_label.text = "RESTORES %d HP" % item.healing_amount \
		if item.is_healing_item() else "NOT USABLE FROM THIS MENU"
	if target == null:
		target_name.text = "NO CREATURE TARGET"
		health_bar.value = 0.0
		health_label.text = "HP unavailable"
		use_button.disabled = true
		return
	var maximum := _maximum_hp(target)
	var current := clampi(target.current_hp, 0, maximum)
	target_name.text = "TARGET  ·  %s" % _display_name(target)
	health_bar.value = float(current) / float(maxi(maximum, 1)) * 100.0
	health_label.text = "HP  %d / %d" % [current, maximum]
	use_button.text = "USE %s" % item.display_name.to_upper()
	use_button.disabled = not item.is_healing_item() \
		or _inventory.get_quantity(item.item_id) <= 0 \
		or current <= 0 \
		or current >= maximum


func _maximum_hp(creature: CreatureInstance) -> int:
	var species := _catalog.get_species(creature.species_id)
	return maxi(StatCalculator.new().calculate_for_instance(species, creature).hp, 1)


func _display_name(creature: CreatureInstance) -> String:
	if not creature.nickname.strip_edges().is_empty():
		return creature.nickname.strip_edges()
	var species := _catalog.get_species(creature.species_id)
	return species.display_name if species != null else str(creature.species_id)


func _focus_selection() -> void:
	var button := get_item_button(_selected_item_id)
	if button != null:
		button.grab_focus()


func _apply_preferences() -> void:
	if not is_node_ready():
		return
	var text_scale := _preferences.text_scale if _preferences != null else 1.0
	var high_contrast := _preferences != null and _preferences.high_contrast
	title_label.add_theme_font_size_override("font_size", int(round(24.0 * text_scale)))
	count_label.add_theme_font_size_override("font_size", int(round(12.0 * text_scale)))
	item_name.add_theme_font_size_override("font_size", int(round(22.0 * text_scale)))
	item_description.add_theme_font_size_override("font_size", int(round(13.0 * text_scale)))
	potency_label.add_theme_font_size_override("font_size", int(round(13.0 * text_scale)))
	target_name.add_theme_font_size_override("font_size", int(round(15.0 * text_scale)))
	health_label.add_theme_font_size_override("font_size", int(round(12.0 * text_scale)))
	feedback_label.add_theme_font_size_override("font_size", int(round(12.0 * text_scale)))
	for button in _item_buttons + _target_buttons:
		button.add_theme_font_size_override("font_size", int(round(14.0 * text_scale)))
	var primary := Color.WHITE if high_contrast else Color("e2f0ef")
	item_description.add_theme_color_override("font_color", primary)
	health_label.add_theme_color_override("font_color", primary)
	feedback_label.add_theme_color_override(
		"font_color",
		Color("fff176") if high_contrast else Color("84e1ca")
	)


func _humanize(value: Variant) -> String:
	return str(value).replace("_", " ")
