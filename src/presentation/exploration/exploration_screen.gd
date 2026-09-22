class_name ExplorationScreen
extends Node2D
## Lightweight code-drawn vertical slice. It consumes exploration events and
## contains no movement, encounter, or battle creation rules of its own.

const MAP_ID: StringName = &"mosslight_crossing"
const MAP_ORIGIN := Vector2(208.0, 88.0)
const MAP_TRANSITION_DURATION := 0.28
const REDUCED_MAP_TRANSITION_DURATION := 0.05

enum MapTransitionStage {
	NONE,
	FADING_OUT,
	FADING_IN,
}

signal preferences_changed(preferences: PlayerPreferences)

@onready var title_label: Label = $Interface/Title
@onready var status_label: Label = $Interface/Status
@onready var dialogue_panel: PanelContainer = $Interface/DialoguePanel
@onready var speaker_label: Label = $Interface/DialoguePanel/Margin/Content/Speaker
@onready var dialogue_label: Label = $Interface/DialoguePanel/Margin/Content/Dialogue
@onready var battle_screen: BattleScreen = $Interface/BattleScreen
@onready var creature_roster_menu: CreatureRosterMenu = $Interface/CreatureRosterMenu
@onready var object_menu: ObjectMenu = $Interface/ObjectMenu
@onready var controls_label: Label = $Interface/Controls
@onready var accessibility_label: Label = $Interface/AccessibilityStatus
@onready var help_panel: PanelContainer = $Interface/HelpPanel
@onready var help_label: Label = $Interface/HelpPanel/Margin/Scroll/HelpText
@onready var map_transition_overlay: ColorRect = $Interface/MapTransitionOverlay
@onready var audio_feedback: ProceduralAudioFeedback = $ProceduralAudioFeedback

var session: ExplorationSession
var active_battle: BattleManager

var _catalog: ContentCatalog
var _battle_factory: WildBattleFactory
var _inventory := Inventory.new()
var _collection := CreatureCollection.new()
var _selected_battle_creature_id: String = ""
var _dialogue_lines: Array[String] = []
var _dialogue_index: int = 0
var _preferences_service: PlayerPreferencesService
var _feedback_router := ExplorationFeedbackRouter.new()
var _active_feedback: FeedbackCue
var _feedback_remaining: float = 0.0
var _feedback_total: float = 0.0
var _last_object_message: String = ""
var _map_transition_stage: MapTransitionStage = MapTransitionStage.NONE
var _map_transition_elapsed: float = 0.0


func initialize(
	catalog: ContentCatalog,
	preferences: PlayerPreferences = null
) -> void:
	_catalog = catalog
	_preferences_service = PlayerPreferencesService.new(preferences)
	_preferences_service.preferences_changed.connect(_on_preferences_changed)
	_apply_preferences()
	_create_demo_player()
	_battle_factory = WildBattleFactory.new(_catalog)
	session = ExplorationSession.new(
		_catalog,
		SeededExplorationRandomSource.new(4401)
	)
	session.event_emitted.connect(_on_exploration_event)
	if not session.start(MAP_ID):
		status_label.text = "Exploration failed: %s" % session.last_error
		return
	title_label.text = session.get_current_map().display_name
	status_label.text = "Follow the trails to Lumenstead, enter the research house, and meet Professor Lumen."
	queue_redraw()


func _ready() -> void:
	dialogue_panel.hide()
	battle_screen.hide()
	battle_screen.battle_closed.connect(_on_battle_closed)
	creature_roster_menu.hide()
	creature_roster_menu.lead_selected.connect(_on_battle_lead_selected)
	creature_roster_menu.roster_closed.connect(_on_creature_roster_closed)
	object_menu.hide()
	object_menu.object_used.connect(_on_object_used)
	object_menu.menu_closed.connect(_on_object_menu_closed)
	help_panel.show()
	map_transition_overlay.hide()
	set_process_unhandled_input(true)
	set_process(true)


func _process(delta: float) -> void:
	var needs_redraw := false
	if _feedback_remaining > 0.0:
		_feedback_remaining = maxf(_feedback_remaining - delta, 0.0)
		needs_redraw = true
	if is_map_transitioning():
		_advance_map_transition(delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if session == null or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if is_map_transitioning():
		return
	if _handle_preference_shortcut(key.keycode):
		return
	if help_panel.visible:
		if key.keycode in [KEY_ENTER, KEY_ESCAPE, KEY_SPACE]:
			help_panel.hide()
		return
	if battle_screen.visible:
		return
	if creature_roster_menu.visible:
		return
	if object_menu.visible:
		return
	if dialogue_panel.visible:
		if key.keycode in [KEY_E, KEY_ENTER, KEY_ESCAPE, KEY_SPACE]:
			_advance_dialogue()
		return
	match key.keycode:
		KEY_W, KEY_UP:
			_move(Vector2i.UP)
		KEY_S, KEY_DOWN:
			_move(Vector2i.DOWN)
		KEY_A, KEY_LEFT:
			_move(Vector2i.LEFT)
		KEY_D, KEY_RIGHT:
			_move(Vector2i.RIGHT)
		KEY_E, KEY_SPACE, KEY_ENTER:
			_interact()
		KEY_P:
			open_creature_roster()
		KEY_B:
			open_object_menu()


func _draw() -> void:
	var high_contrast := _is_high_contrast()
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(1280, 720)),
		Color("05090c") if high_contrast else Color("18252f")
	)
	if session == null or session.get_current_map() == null:
		return
	var map := session.get_current_map()
	for y in map.get_height():
		for x in map.get_width():
			_draw_tile(map, Vector2i(x, y))
	for map_exit in map.map_exits:
		if map_exit.transition_style == MapExitDefinition.STYLE_DOOR:
			_draw_door(map, map_exit)
	for chest in map.treasure_chests:
		_draw_treasure_chest(map, chest)
	for gift in map.creature_gifts:
		_draw_creature_gift(map, gift)
	for npc in map.npcs:
		_draw_npc(map, npc)
	_draw_player(map)
	_draw_feedback()


func _draw_tile(map: ExplorationMapDefinition, cell: Vector2i) -> void:
	var tile_size := float(map.tile_size)
	var rect := Rect2(MAP_ORIGIN + Vector2(cell) * tile_size, Vector2.ONE * tile_size)
	var code := map.get_tile_code(cell)
	var is_dewstone := map.map_id == &"dewstone_vale"
	var is_lumenstead := map.map_id == &"lumenstead_village"
	var is_house := map.map_id == &"lumen_research_house"
	var color := Color("fff1a8") if _is_high_contrast() else (
		Color("b9d6a5") if is_lumenstead else (
			Color("cbbd9d") if is_house else (
				Color("bad0bd") if is_dewstone else Color("dccb91")
			)
		)
	)
	if code == ExplorationMapDefinition.TILE_WALL:
		color = Color("20272b") if _is_high_contrast() else (
			Color("563f34") if is_house else (
				Color("30434b") if is_dewstone else Color("344b4b")
			)
		)
	elif code == ExplorationMapDefinition.TILE_BUILDING_WALL:
		color = Color("47302b") if _is_high_contrast() else Color("8e4f43")
	elif code == "g":
		color = Color("8bdf63") if _is_high_contrast() else (
			Color("5d9f75") if is_dewstone else Color("75a95a")
		)
	elif code == "f":
		color = Color("4ed6b0") if _is_high_contrast() else (
			Color("557d91") if is_dewstone else Color("4b8e79")
		)
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.18), false, 1.0)
	if code in ["g", "f"]:
		var base := rect.position + Vector2(9, tile_size - 8)
		for offset in [0.0, 12.0, 24.0]:
			draw_line(base + Vector2(offset, 0), base + Vector2(offset + 3, -10), Color("d6e681"), 2.0)
	elif code in [
		ExplorationMapDefinition.TILE_FENCE_HORIZONTAL,
		ExplorationMapDefinition.TILE_FENCE_VERTICAL,
	]:
		_draw_fence(rect, code)
	elif code == ExplorationMapDefinition.TILE_BUILDING_WALL:
		var roof_color := Color("ff785f") if _is_high_contrast() else Color("c76655")
		draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), roof_color)
		draw_line(rect.position + Vector2(4, 8), rect.end - Vector2(4, 8), roof_color.lightened(0.18), 3.0)


func _draw_door(map: ExplorationMapDefinition, map_exit: MapExitDefinition) -> void:
	var tile_size := float(map.tile_size)
	var rect := Rect2(
		MAP_ORIGIN + Vector2(map_exit.grid_position) * tile_size,
		Vector2.ONE * tile_size
	)
	var frame := Color("fff0b0") if _is_high_contrast() else Color("5b3528")
	var panel := Color("202020") if _is_high_contrast() else Color("9b6040")
	draw_rect(Rect2(rect.position + Vector2(7, 3), Vector2(tile_size - 14, tile_size - 3)), frame)
	draw_rect(Rect2(rect.position + Vector2(11, 7), Vector2(tile_size - 22, tile_size - 7)), panel)
	draw_circle(rect.position + Vector2(tile_size - 15, tile_size * 0.56), 2.5, Color("ffe269"))


func _draw_creature_gift(
	map: ExplorationMapDefinition,
	gift: CreatureGiftDefinition
) -> void:
	var center := MAP_ORIGIN + (Vector2(gift.grid_position) + Vector2(0.5, 0.5)) \
		* map.tile_size
	var claimed_gift_id := session.state.get_claimed_creature_gift(gift.choice_group_id)
	var unavailable := not claimed_gift_id.is_empty() and claimed_gift_id != gift.gift_id
	var selected := claimed_gift_id == gift.gift_id
	var shell := Color("686868") if unavailable else Color("fff4d6")
	var accent := Color("d6d6d6") if unavailable else _gift_accent_color(gift.species_id)
	var outline := Color.WHITE if _is_high_contrast() else Color("3f3540")
	if selected:
		draw_arc(center + Vector2(0, 8), 15.0, 0.05, PI - 0.05, 16, shell, 7.0)
		draw_polyline(PackedVector2Array([
			center + Vector2(-13, 3),
			center + Vector2(-6, -3),
			center,
			center + Vector2(6, -3),
			center + Vector2(13, 3),
		]), outline, 2.0)
		return
	var egg_points := PackedVector2Array()
	for point_index in 24:
		var angle := TAU * float(point_index) / 24.0
		egg_points.append(center + Vector2(cos(angle) * 14.0, sin(angle) * 19.0))
	draw_colored_polygon(egg_points, shell)
	draw_polyline(egg_points, outline, 2.0)
	draw_circle(center + Vector2(-5, -2), 4.0, accent)
	draw_circle(center + Vector2(6, 6), 3.0, accent)
	draw_circle(center + Vector2(4, -10), 2.5, accent)


func _gift_accent_color(species_id: StringName) -> Color:
	match species_id:
		&"cindermite":
			return Color("f07a45")
		&"reedling":
			return Color("63b66c")
		&"gustlet":
			return Color("6caee8")
	return Color("c48ae8")


func _draw_fence(rect: Rect2, tile_code: String) -> void:
	var wood := Color("ffe27a") if _is_high_contrast() else Color("986b43")
	var shadow := Color("30190f") if _is_high_contrast() else Color("493225")
	if tile_code == ExplorationMapDefinition.TILE_FENCE_HORIZONTAL:
		for x_ratio in [1.0 / 6.0, 0.5, 5.0 / 6.0]:
			var x_offset: float = rect.size.x * x_ratio
			draw_line(
				rect.position + Vector2(x_offset, rect.size.y * 0.19),
				rect.position + Vector2(x_offset, rect.size.y * 0.83),
				shadow,
				7.0
			)
			draw_line(
				rect.position + Vector2(x_offset, rect.size.y * 0.19),
				rect.position + Vector2(x_offset, rect.size.y * 0.83),
				wood,
				4.0
			)
		for y_ratio in [0.375, 0.646]:
			var y_offset: float = rect.size.y * y_ratio
			draw_line(
				rect.position + Vector2(0, y_offset),
				rect.position + Vector2(rect.size.x, y_offset),
				shadow,
				8.0
			)
			draw_line(
				rect.position + Vector2(0, y_offset),
				rect.position + Vector2(rect.size.x, y_offset),
				wood,
				5.0
			)
		return
	for y_ratio in [1.0 / 6.0, 0.5, 5.0 / 6.0]:
		var y_offset: float = rect.size.y * y_ratio
		draw_line(
			rect.position + Vector2(rect.size.x * 0.19, y_offset),
			rect.position + Vector2(rect.size.x * 0.83, y_offset),
			shadow,
			7.0
		)
		draw_line(
			rect.position + Vector2(rect.size.x * 0.19, y_offset),
			rect.position + Vector2(rect.size.x * 0.83, y_offset),
			wood,
			4.0
		)
	for x_ratio in [0.375, 0.646]:
		var x_offset: float = rect.size.x * x_ratio
		draw_line(
			rect.position + Vector2(x_offset, 0),
			rect.position + Vector2(x_offset, rect.size.y),
			shadow,
			8.0
		)
		draw_line(
			rect.position + Vector2(x_offset, 0),
			rect.position + Vector2(x_offset, rect.size.y),
			wood,
			5.0
		)


func _draw_npc(map: ExplorationMapDefinition, npc: NpcDefinition) -> void:
	var center := MAP_ORIGIN + (Vector2(npc.grid_position) + Vector2(0.5, 0.5)) * map.tile_size
	draw_circle(center + Vector2(0, -8), 9, Color("fff0a6") if _is_high_contrast() else Color("f4c986"))
	draw_rect(Rect2(center + Vector2(-11, 1), Vector2(22, 20)), Color("ff684f") if _is_high_contrast() else Color("dd765d"))
	draw_circle(center + Vector2(npc.facing) * 13, 3, Color("fff2c4"))


func _draw_treasure_chest(
	map: ExplorationMapDefinition,
	chest: TreasureChestDefinition
) -> void:
	var center := MAP_ORIGIN + (Vector2(chest.grid_position) + Vector2(0.5, 0.5)) \
		* map.tile_size
	var opened := session.state.is_chest_open(chest.chest_id)
	var outline := Color.WHITE if _is_high_contrast() else Color("2a1d18")
	var wood := Color("a67745") if opened else Color("c78338")
	var metal := Color("d8cbb3") if opened else Color("ffd65a")
	if opened:
		draw_rect(Rect2(center + Vector2(-16, -16), Vector2(32, 9)), wood, true)
		draw_rect(Rect2(center + Vector2(-16, -16), Vector2(32, 9)), outline, false, 2.0)
		draw_rect(Rect2(center + Vector2(-17, -5), Vector2(34, 21)), Color("382d27"), true)
	else:
		draw_rect(Rect2(center + Vector2(-17, -14), Vector2(34, 13)), wood.lightened(0.08), true)
		draw_rect(Rect2(center + Vector2(-17, -14), Vector2(34, 13)), outline, false, 2.0)
		draw_circle(center + Vector2(13, -17), 3.0, metal)
	draw_rect(Rect2(center + Vector2(-17, -5), Vector2(34, 21)), wood, true)
	draw_rect(Rect2(center + Vector2(-17, -5), Vector2(34, 21)), outline, false, 2.0)
	draw_rect(Rect2(center + Vector2(-3, -5), Vector2(6, 21)), metal, true)
	if not opened:
		draw_rect(Rect2(center + Vector2(-4, 0), Vector2(8, 8)), outline, false, 2.0)


func _draw_player(map: ExplorationMapDefinition) -> void:
	var center := MAP_ORIGIN + (Vector2(session.state.player_position) + Vector2(0.5, 0.5)) * map.tile_size
	draw_circle(center, 15, Color("63e8ff") if _is_high_contrast() else Color("5bc0eb"))
	draw_circle(center, 10, Color("005a8c") if _is_high_contrast() else Color("276f91"))
	var facing := Vector2(session.state.facing)
	var perpendicular := Vector2(-facing.y, facing.x)
	var tip := center + facing * 21
	var points := PackedVector2Array([
		tip,
		center + facing * 8 + perpendicular * 6,
		center + facing * 8 - perpendicular * 6,
	])
	draw_colored_polygon(points, Color("f7de73"))


func _draw_feedback() -> void:
	if _active_feedback == null or _feedback_remaining <= 0.0 or _feedback_total <= 0.0:
		return
	var feedback_color := _active_feedback.color
	feedback_color.a = clampf(_feedback_remaining / _feedback_total, 0.0, 1.0) * 0.85
	draw_rect(Rect2(12, 12, 1256, 696), feedback_color, false, 7.0)


func _move(direction: Vector2i) -> void:
	if is_map_transitioning():
		return
	var result := session.attempt_move(direction)
	if result.moved:
		status_label.text = "Step %d — position %s" % [session.state.step_count, session.state.player_position]
	else:
		status_label.text = "Path blocked (%s)." % result.reason
	queue_redraw()
	if result.map_transition != null:
		_begin_map_transition(result.map_transition)
		return
	if result.encounter != null:
		_begin_battle_transition(result.encounter)


func _begin_map_transition(request: MapTransitionRequest) -> void:
	_map_transition_stage = MapTransitionStage.FADING_OUT
	_map_transition_elapsed = 0.0
	_set_map_transition_alpha(0.0)
	var destination := _catalog.get_map(request.destination_map_id)
	var transition_verb := "Entering" \
		if request.transition_style == MapExitDefinition.STYLE_DOOR \
		else "Following the trail to"
	status_label.text = "%s %s..." % [transition_verb,
		destination.display_name if destination != null else str(request.destination_map_id)
	]


func _advance_map_transition(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	var duration := get_map_transition_duration()
	while remaining > 0.0 and is_map_transitioning():
		var phase_remaining := duration - _map_transition_elapsed
		var step := minf(remaining, phase_remaining)
		_map_transition_elapsed += step
		remaining -= step
		if _map_transition_stage == MapTransitionStage.FADING_OUT:
			_set_map_transition_alpha(_map_transition_elapsed / duration)
			if _map_transition_elapsed >= duration:
				if not session.complete_map_transition():
					_map_transition_stage = MapTransitionStage.NONE
					_set_map_transition_alpha(0.0)
					status_label.text = "Map transition failed: %s" % session.last_error
					return
				_map_transition_stage = MapTransitionStage.FADING_IN
				_map_transition_elapsed = 0.0
				title_label.text = session.get_current_map().display_name
				status_label.text = "Arrived at %s." % session.get_current_map().display_name
		else:
			_set_map_transition_alpha(1.0 - (_map_transition_elapsed / duration))
			if _map_transition_elapsed >= duration:
				_map_transition_stage = MapTransitionStage.NONE
				_map_transition_elapsed = 0.0
				_set_map_transition_alpha(0.0)


func _set_map_transition_alpha(alpha: float) -> void:
	var overlay_color := Color.BLACK
	overlay_color.a = clampf(alpha, 0.0, 1.0)
	map_transition_overlay.color = overlay_color
	map_transition_overlay.visible = overlay_color.a > 0.0


func is_map_transitioning() -> bool:
	return _map_transition_stage != MapTransitionStage.NONE


func get_map_transition_alpha() -> float:
	return map_transition_overlay.color.a


func get_map_transition_duration() -> float:
	if _preferences_service != null and _preferences_service.preferences.reduced_motion:
		return REDUCED_MAP_TRANSITION_DURATION
	return MAP_TRANSITION_DURATION


func _interact() -> void:
	var result := session.interact(_inventory, _collection)
	if not result.success:
		match result.reason:
			&"treasure_chest_already_open":
				status_label.text = "This treasure chest is empty."
			&"inventory_full", &"stack_limit_exceeded":
				status_label.text = "The reward stays inside because your inventory cannot hold it."
			&"creature_gift_prerequisite_not_met":
				status_label.text = "Professor Lumen must explain the eggs before you choose one."
			&"creature_gift_choice_already_claimed":
				status_label.text = "You already chose an egg from this clutch."
			_:
				status_label.text = "There is nothing to interact with here."
		return
	if result.interaction_type == ExplorationConstants.INTERACTION_TREASURE_CHEST:
		var item := _catalog.get_item(result.item_id)
		status_label.text = "Treasure found: %s x%d! Inventory now holds %d." % [
			item.display_name if item != null else str(result.item_id),
			result.quantity,
			result.quantity_after,
		]
		queue_redraw()
		return
	if result.interaction_type == ExplorationConstants.INTERACTION_CREATURE_GIFT:
		var species := _catalog.get_species(result.species_id)
		_selected_battle_creature_id = result.creature_instance_id
		status_label.text = "%s hatched and joined your %s! It is now your next battle lead." % [
			species.display_name if species != null else str(result.species_id),
			str(result.collection_destination),
		]
		queue_redraw()
		return
	_dialogue_lines.assign(result.dialogue)
	_dialogue_index = 0
	speaker_label.text = result.speaker_name
	dialogue_label.text = _dialogue_lines[0]
	dialogue_panel.show()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		dialogue_panel.hide()
		return
	dialogue_label.text = _dialogue_lines[_dialogue_index]


func _begin_battle_transition(request: WildEncounterRequest) -> void:
	var transition := _battle_factory.create(
		request,
		_get_next_battle_party(),
		_inventory,
		_collection
	)
	if not transition.success:
		status_label.text = "Battle transition failed: %s" % transition.reason
		session.resume_after_battle()
		return
	active_battle = transition.battle_manager
	battle_screen.initialize(
		_catalog,
		active_battle,
		_inventory,
		_preferences_service.preferences
	)


func _on_battle_closed(outcome: StringName) -> void:
	active_battle = null
	session.resume_after_battle()
	var selected := get_selected_battle_creature()
	var lead_name := "None"
	if selected != null:
		lead_name = _catalog.get_species(selected.species_id).display_name
	status_label.text = "%s Next lead: %s. Encounter cooldown: %d steps." % [
		_battle_outcome_message(outcome),
		lead_name,
		session.state.encounter_cooldown_steps,
	]
	queue_redraw()


func _create_demo_player() -> void:
	var starter := CreatureInstance.new()
	starter.instance_id = "player-starter"
	starter.species_id = &"cindermite"
	starter.level = 8
	var species := _catalog.get_species(starter.species_id)
	starter.total_experience = ExperienceCalculator.new().total_experience_for_level(
		_catalog.get_growth_curve(species.growth_curve_id),
		starter.level
	)
	starter.learned_move_ids = species.available_moves_at_level(starter.level)
	starter.current_hp = StatCalculator.new().calculate_for_instance(
		species,
		starter
	).hp
	_collection.party.append(starter)
	_selected_battle_creature_id = starter.instance_id
	var inventory_service := InventoryService.new(_catalog)
	inventory_service.add(_inventory, &"basic_capsule", 5)
	inventory_service.add(_inventory, &"potion", 5)
	inventory_service.add(_inventory, &"mega_potion", 3)
	inventory_service.add(_inventory, &"ultra_potion", 1)
	inventory_service.add(_inventory, &"elixir", 2)


func open_creature_roster() -> void:
	if session == null \
		or session.state.phase != ExplorationConstants.PHASE_ACTIVE \
		or battle_screen.visible \
		or object_menu.visible \
		or dialogue_panel.visible \
		or help_panel.visible:
		return
	creature_roster_menu.open_roster(
		_catalog,
		_collection,
		_selected_battle_creature_id,
		_preferences_service.preferences
	)


func open_object_menu() -> void:
	if session == null \
		or session.state.phase != ExplorationConstants.PHASE_ACTIVE \
		or battle_screen.visible \
		or creature_roster_menu.visible \
		or dialogue_panel.visible \
		or help_panel.visible:
		return
	_last_object_message = ""
	object_menu.open_menu(
		_catalog,
		_inventory,
		_collection,
		_selected_battle_creature_id,
		_preferences_service.preferences
	)


func get_selected_battle_creature() -> CreatureInstance:
	var selected := _collection.find_instance(_selected_battle_creature_id)
	if selected != null:
		return selected
	if not _collection.party.is_empty():
		return _collection.party[0]
	return null


func _get_next_battle_party() -> Array[CreatureInstance]:
	var selected := get_selected_battle_creature()
	var next_party: Array[CreatureInstance] = []
	if selected != null:
		next_party.append(selected)
	return next_party


func _on_battle_lead_selected(instance_id: String) -> void:
	var selected := _collection.find_instance(instance_id)
	if selected == null:
		return
	_selected_battle_creature_id = instance_id
	var species := _catalog.get_species(selected.species_id)
	status_label.text = "%s will fight in the next wild encounter." % species.display_name


func _on_creature_roster_closed() -> void:
	var selected := get_selected_battle_creature()
	if selected == null:
		return
	var species := _catalog.get_species(selected.species_id)
	status_label.text = "Explore freely. Next battle lead: %s." % species.display_name


func _on_object_used(
	item_id: StringName,
	instance_id: String,
	healing_applied: int
) -> void:
	var item := _catalog.get_item(item_id)
	var creature := _collection.find_instance(instance_id)
	var species := _catalog.get_species(creature.species_id) if creature != null else null
	var item_name := item.display_name if item != null else str(item_id)
	var creature_name := species.display_name if species != null else instance_id
	_last_object_message = "%s revived %s with %d HP." % [
		item_name,
		creature_name,
		healing_applied,
	] if item != null and item.is_revival_item() else "%s restored %d HP to %s." % [
		item_name,
		healing_applied,
		creature_name,
	]


func _on_object_menu_closed() -> void:
	status_label.text = _last_object_message \
		if not _last_object_message.is_empty() \
		else "Objects closed. Battle damage remains until you use a restorative."


func _battle_outcome_message(outcome: StringName) -> String:
	match outcome:
		BattleConstants.OUTCOME_PLAYER_VICTORY:
			return "Victory! Returned to the field."
		BattleConstants.OUTCOME_OPPONENT_CAPTURED:
			return "Capture complete! Returned to the field."
		BattleConstants.OUTCOME_PLAYER_ESCAPED:
			return "Retreat successful. Returned to the field."
		BattleConstants.OUTCOME_OPPONENT_VICTORY:
			return "Your companion fainted. Choose another healthy fighter."
	return "Battle ended. Returned to the field."


func _on_exploration_event(event: ExplorationEvent) -> void:
	var cue := _feedback_router.route(event)
	if cue == null or _preferences_service == null:
		return
	audio_feedback.play_cue(cue, _preferences_service.preferences)
	if not _preferences_service.preferences.reduced_motion:
		_active_feedback = cue
		_feedback_total = cue.visual_duration
		_feedback_remaining = cue.visual_duration
		queue_redraw()


func _handle_preference_shortcut(keycode: Key) -> bool:
	match keycode:
		KEY_F1:
			if battle_screen.visible or creature_roster_menu.visible or object_menu.visible:
				return true
			help_panel.visible = not help_panel.visible
			return true
		KEY_F2:
			_preferences_service.toggle_high_contrast()
			return true
		KEY_F3:
			_preferences_service.cycle_text_scale()
			return true
		KEY_F4:
			_preferences_service.toggle_reduced_motion()
			return true
		KEY_M:
			_preferences_service.toggle_mute()
			return true
	return false


func _on_preferences_changed(preferences: PlayerPreferences) -> void:
	_apply_preferences()
	preferences_changed.emit(preferences)


func _apply_preferences() -> void:
	if _preferences_service == null:
		return
	var preferences := _preferences_service.preferences
	title_label.add_theme_font_size_override("font_size", int(round(26.0 * preferences.text_scale)))
	status_label.add_theme_font_size_override("font_size", int(round(16.0 * preferences.text_scale)))
	controls_label.add_theme_font_size_override("font_size", int(round(14.0 * preferences.text_scale)))
	accessibility_label.add_theme_font_size_override("font_size", int(round(13.0 * preferences.text_scale)))
	help_label.add_theme_font_size_override("font_size", int(round(17.0 * preferences.text_scale)))
	var primary_text := Color.WHITE if preferences.high_contrast else Color("d9e8ed")
	status_label.add_theme_color_override("font_color", primary_text)
	controls_label.add_theme_color_override("font_color", primary_text)
	accessibility_label.add_theme_color_override("font_color", Color("ffe56b") if preferences.high_contrast else Color("86c8bd"))
	accessibility_label.text = "Contrast: %s  ·  Text: %d%%  ·  Motion: %s  ·  Audio: %s" % [
		"High" if preferences.high_contrast else "Standard",
		int(round(preferences.text_scale * 100.0)),
		"Reduced" if preferences.reduced_motion else "Full",
		"Muted" if preferences.mute_audio else "On",
	]
	if battle_screen != null:
		battle_screen.set_preferences(preferences)
	if creature_roster_menu != null:
		creature_roster_menu.set_preferences(preferences)
	if object_menu != null:
		object_menu.set_preferences(preferences)
	queue_redraw()


func _is_high_contrast() -> bool:
	return _preferences_service != null and _preferences_service.preferences.high_contrast
