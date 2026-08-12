class_name ExplorationScreen
extends Node2D
## Lightweight code-drawn vertical slice. It consumes exploration events and
## contains no movement, encounter, or battle creation rules of its own.

const MAP_ID: StringName = &"mosslight_crossing"
const MAP_ORIGIN := Vector2(208.0, 88.0)

signal preferences_changed(preferences: PlayerPreferences)

@onready var title_label: Label = $Interface/Title
@onready var status_label: Label = $Interface/Status
@onready var dialogue_panel: PanelContainer = $Interface/DialoguePanel
@onready var speaker_label: Label = $Interface/DialoguePanel/Margin/Content/Speaker
@onready var dialogue_label: Label = $Interface/DialoguePanel/Margin/Content/Dialogue
@onready var battle_panel: PanelContainer = $Interface/BattlePanel
@onready var battle_label: Label = $Interface/BattlePanel/Margin/Content/BattleText
@onready var controls_label: Label = $Interface/Controls
@onready var accessibility_label: Label = $Interface/AccessibilityStatus
@onready var help_panel: PanelContainer = $Interface/HelpPanel
@onready var help_label: Label = $Interface/HelpPanel/Margin/Scroll/HelpText
@onready var audio_feedback: ProceduralAudioFeedback = $ProceduralAudioFeedback

var session: ExplorationSession
var active_battle: BattleManager

var _catalog: ContentCatalog
var _battle_factory: WildBattleFactory
var _player_party: Array[CreatureInstance] = []
var _inventory := Inventory.new()
var _collection := CreatureCollection.new()
var _dialogue_lines: Array[String] = []
var _dialogue_index: int = 0
var _preferences_service: PlayerPreferencesService
var _feedback_router := ExplorationFeedbackRouter.new()
var _active_feedback: FeedbackCue
var _feedback_remaining: float = 0.0
var _feedback_total: float = 0.0


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
	status_label.text = "Explore the grass and mistferns. Talk to Ranger Mira."
	queue_redraw()


func _ready() -> void:
	dialogue_panel.hide()
	battle_panel.hide()
	help_panel.show()
	set_process_unhandled_input(true)
	set_process(true)


func _process(delta: float) -> void:
	if _feedback_remaining <= 0.0:
		return
	_feedback_remaining = maxf(_feedback_remaining - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if session == null or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _handle_preference_shortcut(key.keycode):
		return
	if help_panel.visible:
		if key.keycode in [KEY_ENTER, KEY_ESCAPE, KEY_SPACE]:
			help_panel.hide()
		return
	if battle_panel.visible:
		if key.keycode in [KEY_ENTER, KEY_ESCAPE, KEY_SPACE]:
			battle_panel.hide()
			active_battle = null
			session.resume_after_battle()
			status_label.text = "Returned to the field. Encounter cooldown: %d steps." % session.state.encounter_cooldown_steps
			queue_redraw()
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
	for npc in map.npcs:
		_draw_npc(map, npc)
	_draw_player(map)
	_draw_feedback()


func _draw_tile(map: ExplorationMapDefinition, cell: Vector2i) -> void:
	var tile_size := float(map.tile_size)
	var rect := Rect2(MAP_ORIGIN + Vector2(cell) * tile_size, Vector2.ONE * tile_size)
	var code := map.get_tile_code(cell)
	var color := Color("fff1a8") if _is_high_contrast() else Color("dccb91")
	if code == ExplorationMapDefinition.TILE_WALL:
		color = Color("20272b") if _is_high_contrast() else Color("344b4b")
	elif code == "g":
		color = Color("8bdf63") if _is_high_contrast() else Color("75a95a")
	elif code == "f":
		color = Color("4ed6b0") if _is_high_contrast() else Color("4b8e79")
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.18), false, 1.0)
	if code in ["g", "f"]:
		var base := rect.position + Vector2(9, tile_size - 8)
		for offset in [0.0, 12.0, 24.0]:
			draw_line(base + Vector2(offset, 0), base + Vector2(offset + 3, -10), Color("d6e681"), 2.0)


func _draw_npc(map: ExplorationMapDefinition, npc: NpcDefinition) -> void:
	var center := MAP_ORIGIN + (Vector2(npc.grid_position) + Vector2(0.5, 0.5)) * map.tile_size
	draw_circle(center + Vector2(0, -8), 9, Color("fff0a6") if _is_high_contrast() else Color("f4c986"))
	draw_rect(Rect2(center + Vector2(-11, 1), Vector2(22, 20)), Color("ff684f") if _is_high_contrast() else Color("dd765d"))
	draw_circle(center + Vector2(npc.facing) * 13, 3, Color("fff2c4"))


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
	var result := session.attempt_move(direction)
	if result.moved:
		status_label.text = "Step %d — position %s" % [session.state.step_count, session.state.player_position]
	else:
		status_label.text = "Path blocked (%s)." % result.reason
	queue_redraw()
	if result.encounter != null:
		_begin_battle_transition(result.encounter)


func _interact() -> void:
	var result := session.interact()
	if not result.success:
		status_label.text = "There is nothing to interact with here."
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
		_player_party,
		_inventory,
		_collection
	)
	if not transition.success:
		status_label.text = "Battle transition failed: %s" % transition.reason
		session.resume_after_battle()
		return
	active_battle = transition.battle_manager
	var species := _catalog.get_species(request.species_id)
	battle_label.text = "WILD ENCOUNTER\n\n%s  ·  Level %d\n%s\n\nBattle state: %s\n5 Basic Capsules available\n\nPress Enter, Space, or Escape to return to exploration." % [
		species.display_name,
		request.level,
		_catalog.get_map(request.map_id).get_zone_for_cell(request.grid_position).display_name,
		active_battle.phase,
	]
	battle_panel.show()


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
	starter.current_hp = 999999
	starter.learned_move_ids = species.available_moves_at_level(starter.level)
	_player_party.append(starter)
	_collection.party.append(starter)
	InventoryService.new(_catalog).add(_inventory, &"basic_capsule", 5)


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
	queue_redraw()


func _is_high_contrast() -> bool:
	return _preferences_service != null and _preferences_service.preferences.high_contrast
