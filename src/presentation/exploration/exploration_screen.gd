class_name ExplorationScreen
extends Node2D
## Lightweight code-drawn vertical slice. It consumes exploration events and
## contains no movement, encounter, or battle creation rules of its own.

const MAP_ID: StringName = &"mosslight_crossing"
const MAP_ORIGIN := Vector2(208.0, 88.0)

@onready var title_label: Label = $Interface/Title
@onready var status_label: Label = $Interface/Status
@onready var dialogue_panel: PanelContainer = $Interface/DialoguePanel
@onready var speaker_label: Label = $Interface/DialoguePanel/Margin/Content/Speaker
@onready var dialogue_label: Label = $Interface/DialoguePanel/Margin/Content/Dialogue
@onready var battle_panel: PanelContainer = $Interface/BattlePanel
@onready var battle_label: Label = $Interface/BattlePanel/Margin/Content/BattleText

var session: ExplorationSession
var active_battle: BattleManager

var _catalog: ContentCatalog
var _battle_factory: WildBattleFactory
var _player_party: Array[CreatureInstance] = []
var _inventory := Inventory.new()
var _collection := CreatureCollection.new()
var _dialogue_lines: Array[String] = []
var _dialogue_index: int = 0


func initialize(catalog: ContentCatalog) -> void:
	_catalog = catalog
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
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if session == null or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
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
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("18252f"))
	if session == null or session.get_current_map() == null:
		return
	var map := session.get_current_map()
	for y in map.get_height():
		for x in map.get_width():
			_draw_tile(map, Vector2i(x, y))
	for npc in map.npcs:
		_draw_npc(map, npc)
	_draw_player(map)


func _draw_tile(map: ExplorationMapDefinition, cell: Vector2i) -> void:
	var tile_size := float(map.tile_size)
	var rect := Rect2(MAP_ORIGIN + Vector2(cell) * tile_size, Vector2.ONE * tile_size)
	var code := map.get_tile_code(cell)
	var color := Color("dccb91")
	if code == ExplorationMapDefinition.TILE_WALL:
		color = Color("344b4b")
	elif code == "g":
		color = Color("75a95a")
	elif code == "f":
		color = Color("4b8e79")
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.18), false, 1.0)
	if code in ["g", "f"]:
		var base := rect.position + Vector2(9, tile_size - 8)
		for offset in [0.0, 12.0, 24.0]:
			draw_line(base + Vector2(offset, 0), base + Vector2(offset + 3, -10), Color("d6e681"), 2.0)


func _draw_npc(map: ExplorationMapDefinition, npc: NpcDefinition) -> void:
	var center := MAP_ORIGIN + (Vector2(npc.grid_position) + Vector2(0.5, 0.5)) * map.tile_size
	draw_circle(center + Vector2(0, -8), 9, Color("f4c986"))
	draw_rect(Rect2(center + Vector2(-11, 1), Vector2(22, 20)), Color("dd765d"))
	draw_circle(center + Vector2(npc.facing) * 13, 3, Color("fff2c4"))


func _draw_player(map: ExplorationMapDefinition) -> void:
	var center := MAP_ORIGIN + (Vector2(session.state.player_position) + Vector2(0.5, 0.5)) * map.tile_size
	draw_circle(center, 15, Color("5bc0eb"))
	draw_circle(center, 10, Color("276f91"))
	var facing := Vector2(session.state.facing)
	var perpendicular := Vector2(-facing.y, facing.x)
	var tip := center + facing * 21
	var points := PackedVector2Array([
		tip,
		center + facing * 8 + perpendicular * 6,
		center + facing * 8 - perpendicular * 6,
	])
	draw_colored_polygon(points, Color("f7de73"))


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


func _on_exploration_event(_event: ExplorationEvent) -> void:
	# Presentation currently reads immediate command results. The signal remains
	# connected as the stable seam for future audio, analytics, and quest systems.
	pass
