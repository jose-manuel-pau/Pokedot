class_name CreatureRosterMenu
extends Control
## Explorer-accessible view over the complete captured collection. It emits a
## stable instance ID; exploration remains responsible for battle transitions.

signal lead_selected(instance_id: String)
signal roster_closed

@onready var count_label: Label = $Shade/Panel/Margin/Content/Header/Count
@onready var creature_grid: GridContainer = $Shade/Panel/Margin/Content/Body/List/Scroll/CreatureGrid
@onready var detail_name: Label = $Shade/Panel/Margin/Content/Body/Details/DetailMargin/DetailContent/Name
@onready var detail_meta: Label = $Shade/Panel/Margin/Content/Body/Details/DetailMargin/DetailContent/Meta
@onready var detail_description: Label = $Shade/Panel/Margin/Content/Body/Details/DetailMargin/DetailContent/Description
@onready var detail_moves: Label = $Shade/Panel/Margin/Content/Body/Details/DetailMargin/DetailContent/Moves
@onready var selection_label: Label = $Shade/Panel/Margin/Content/Selection
@onready var close_button: Button = $Shade/Panel/Margin/Content/Header/Close

var _catalog: ContentCatalog
var _collection: CreatureCollection
var _lead_instance_id: String = ""
var _preferences: PlayerPreferences
var _entry_buttons: Array[Button] = []


func _ready() -> void:
	close_button.pressed.connect(close_roster)
	hide()
	set_process_unhandled_input(true)


func open_roster(
	catalog: ContentCatalog,
	collection: CreatureCollection,
	lead_instance_id: String,
	preferences: PlayerPreferences = null
) -> void:
	_catalog = catalog
	_collection = collection
	_lead_instance_id = lead_instance_id
	_preferences = preferences
	_rebuild_entries()
	_apply_preferences()
	show()
	call_deferred("_focus_lead")


func close_roster() -> void:
	if not visible:
		return
	hide()
	roster_closed.emit()


func choose_creature(instance_id: String) -> bool:
	if _collection == null:
		return false
	var creature := _collection.find_instance(instance_id)
	if creature == null:
		return false
	_lead_instance_id = instance_id
	_refresh_entry_buttons()
	_show_details(creature)
	selection_label.text = "%s will lead the next wild battle." % _display_name(creature)
	lead_selected.emit(instance_id)
	return true


func set_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_apply_preferences()


func get_entry_instance_ids() -> Array[String]:
	var ids: Array[String] = []
	if _collection == null:
		return ids
	for creature in _collection.get_all_creatures():
		ids.append(creature.instance_id)
	return ids


func get_selected_instance_id() -> String:
	return _lead_instance_id


func get_entry_button(instance_id: String) -> Button:
	for button in _entry_buttons:
		if str(button.get_meta("instance_id", "")) == instance_id:
			return button
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_P, KEY_ESCAPE]:
		close_roster()
		get_viewport().set_input_as_handled()


func _rebuild_entries() -> void:
	for child in creature_grid.get_children():
		child.free()
	_entry_buttons.clear()
	if _collection == null:
		count_label.text = "0 CAPTURED"
		return
	var creatures := _collection.get_all_creatures()
	count_label.text = "%d CAPTURED" % creatures.size()
	for creature in creatures:
		var button := Button.new()
		button.custom_minimum_size = Vector2(300, 92)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.set_meta("instance_id", creature.instance_id)
		button.pressed.connect(choose_creature.bind(creature.instance_id))
		creature_grid.add_child(button)
		_entry_buttons.append(button)
	_refresh_entry_buttons()
	var selected := _collection.find_instance(_lead_instance_id)
	if selected == null and not creatures.is_empty():
		selected = creatures[0]
		_lead_instance_id = selected.instance_id
	if selected != null:
		_show_details(selected)
		selection_label.text = "%s is ready for the next wild battle." % _display_name(selected)


func _refresh_entry_buttons() -> void:
	if _collection == null:
		return
	for button in _entry_buttons:
		var instance_id := str(button.get_meta("instance_id", ""))
		var creature := _collection.find_instance(instance_id)
		if creature == null:
			continue
		var species := _catalog.get_species(creature.species_id)
		var location := str(_collection.get_location(instance_id)).to_upper()
		var marker := "★ NEXT FIGHTER" if instance_id == _lead_instance_id else location
		button.text = "%s   Lv. %d\n%s  ·  %s" % [
			_display_name(creature),
			creature.level,
			_type_names(species),
			marker,
		]
		button.button_pressed = instance_id == _lead_instance_id


func _show_details(creature: CreatureInstance) -> void:
	var species := _catalog.get_species(creature.species_id)
	var stats := StatCalculator.new().calculate_for_instance(species, creature)
	var maximum_hp := maxi(stats.hp, 1)
	var shown_hp := clampi(creature.current_hp, 0, maximum_hp)
	detail_name.text = _display_name(creature)
	detail_meta.text = "LEVEL %d  ·  %s\nHP %d / %d  ·  %s" % [
		creature.level,
		_type_names(species),
		shown_hp,
		maximum_hp,
		str(_collection.get_location(creature.instance_id)).to_upper(),
	]
	detail_description.text = species.description
	var move_names: Array[String] = []
	for move_id in creature.learned_move_ids:
		var move := _catalog.get_move(move_id)
		if move != null:
			move_names.append(move.display_name)
	detail_moves.text = "MOVES\n%s" % (", ".join(move_names) if not move_names.is_empty() else "None")


func _focus_lead() -> void:
	var lead_button := get_entry_button(_lead_instance_id)
	if lead_button != null:
		lead_button.grab_focus()
	elif not _entry_buttons.is_empty():
		_entry_buttons[0].grab_focus()


func _display_name(creature: CreatureInstance) -> String:
	if not creature.nickname.strip_edges().is_empty():
		return creature.nickname.strip_edges()
	var species := _catalog.get_species(creature.species_id)
	return species.display_name if species != null else str(creature.species_id)


func _type_names(species: CreatureSpeciesDefinition) -> String:
	var names: Array[String] = []
	for type_id in species.element_types:
		var definition := _catalog.get_type(type_id)
		names.append((definition.display_name if definition != null else str(type_id)).to_upper())
	return " / ".join(names)


func _apply_preferences() -> void:
	if not is_node_ready():
		return
	var text_scale := _preferences.text_scale if _preferences != null else 1.0
	var high_contrast := _preferences != null and _preferences.high_contrast
	count_label.add_theme_font_size_override("font_size", int(round(15.0 * text_scale)))
	detail_name.add_theme_font_size_override("font_size", int(round(28.0 * text_scale)))
	detail_meta.add_theme_font_size_override("font_size", int(round(16.0 * text_scale)))
	detail_description.add_theme_font_size_override("font_size", int(round(16.0 * text_scale)))
	detail_moves.add_theme_font_size_override("font_size", int(round(15.0 * text_scale)))
	selection_label.add_theme_font_size_override("font_size", int(round(16.0 * text_scale)))
	for button in _entry_buttons:
		button.add_theme_font_size_override("font_size", int(round(15.0 * text_scale)))
	var primary := Color.WHITE if high_contrast else Color("e2f0ef")
	detail_meta.add_theme_color_override("font_color", primary)
	detail_description.add_theme_color_override("font_color", primary)
	selection_label.add_theme_color_override(
		"font_color",
		Color("fff176") if high_contrast else Color("84e1ca")
	)
