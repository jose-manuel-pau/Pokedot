class_name BattleScreen
extends Control
## Presentation adapter for a live BattleManager. Player input becomes domain
## commands; battle events become HUD, arena feedback, and readable combat log.

signal battle_closed(outcome: StringName)

const MOVE_BUTTON_PATHS := [
	"CommandPanel/Margin/Content/MoveGrid/Move1",
	"CommandPanel/Margin/Content/MoveGrid/Move2",
	"CommandPanel/Margin/Content/MoveGrid/Move3",
	"CommandPanel/Margin/Content/MoveGrid/Move4",
]

@onready var arena: BattleArena = $Arena
@onready var turn_label: Label = $TurnBadge/Margin/Turn
@onready var opponent_name: Label = $OpponentHud/Margin/Content/Name
@onready var opponent_health: ProgressBar = $OpponentHud/Margin/Content/Health
@onready var opponent_health_text: Label = $OpponentHud/Margin/Content/HealthText
@onready var opponent_status: Label = $OpponentHud/Margin/Content/Status
@onready var player_name: Label = $PlayerHud/Margin/Content/Name
@onready var player_health: ProgressBar = $PlayerHud/Margin/Content/Health
@onready var player_health_text: Label = $PlayerHud/Margin/Content/HealthText
@onready var player_status: Label = $PlayerHud/Margin/Content/Status
@onready var battle_log: RichTextLabel = $BattleLog/Margin/Log
@onready var prompt_label: Label = $CommandPanel/Margin/Content/Prompt
@onready var capture_button: Button = $CommandPanel/Margin/Content/ActionRow/Capture
@onready var item_button: Button = $CommandPanel/Margin/Content/ActionRow/Item
@onready var run_button: Button = $CommandPanel/Margin/Content/ActionRow/Run
@onready var finish_panel: PanelContainer = $FinishPanel
@onready var finish_title: Label = $FinishPanel/Margin/Content/Title
@onready var finish_detail: Label = $FinishPanel/Margin/Content/Detail
@onready var continue_button: Button = $FinishPanel/Margin/Content/Continue

var battle_manager: BattleManager

var _catalog: ContentCatalog
var _inventory: Inventory
var _ai: BattleAiController
var _preferences: PlayerPreferences
var _move_buttons: Array[Button] = []
var _move_ids: Array[StringName] = []
var _log_lines: Array[String] = []


func _ready() -> void:
	for path in MOVE_BUTTON_PATHS:
		_move_buttons.append(get_node(path) as Button)
	for index in _move_buttons.size():
		_move_buttons[index].pressed.connect(_on_move_pressed.bind(index))
	capture_button.pressed.connect(choose_capture)
	item_button.pressed.connect(choose_item)
	run_button.pressed.connect(choose_run)
	continue_button.pressed.connect(close_battle)
	finish_panel.hide()
	set_process_unhandled_input(true)


func initialize(
	catalog: ContentCatalog,
	manager: BattleManager,
	inventory: Inventory,
	preferences: PlayerPreferences = null
) -> void:
	_catalog = catalog
	battle_manager = manager
	_inventory = inventory
	_preferences = preferences
	_ai = BattleAiController.new(_catalog, SeededBattleRandomSource.new(7301))
	_log_lines.clear()
	finish_panel.hide()
	show()
	var opponent := battle_manager.get_participant(BattleConstants.SIDE_OPPONENT)
	_append_log("A wild %s appeared!" % opponent.species.display_name)
	_append_log("Choose a move, use an item, throw a capsule, or run.")
	_apply_accessibility()
	_refresh()
	_focus_first_action()


func set_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_apply_accessibility()


func choose_move(move_id: StringName) -> bool:
	return _resolve_player_command(UseMoveCommand.new(
		BattleConstants.SIDE_PLAYER,
		move_id
	))


func choose_capture() -> bool:
	return _resolve_player_command(CaptureCommand.new(
		BattleConstants.SIDE_PLAYER,
		&"basic_capsule"
	))


func choose_item() -> bool:
	var player := battle_manager.get_participant(BattleConstants.SIDE_PLAYER)
	return _resolve_player_command(UseItemCommand.new(
		BattleConstants.SIDE_PLAYER,
		&"field_tonic",
		player.creature.instance_id
	))


func choose_run() -> bool:
	return _resolve_player_command(RunCommand.new(BattleConstants.SIDE_PLAYER))


func close_battle() -> void:
	if battle_manager == null or battle_manager.phase != BattleConstants.PHASE_FINISHED:
		return
	var finished_outcome := battle_manager.outcome
	hide()
	battle_closed.emit(finished_outcome)


func get_move_button_count() -> int:
	return _move_ids.size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or battle_manager == null or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if finish_panel.visible:
		if key.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			close_battle()
			get_viewport().set_input_as_handled()
		return
	var handled := true
	match key.keycode:
		KEY_1:
			_choose_move_index(0)
		KEY_2:
			_choose_move_index(1)
		KEY_3:
			_choose_move_index(2)
		KEY_4:
			_choose_move_index(3)
		KEY_C:
			choose_capture()
		KEY_I:
			choose_item()
		KEY_R, KEY_ESCAPE:
			choose_run()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_move_pressed(index: int) -> void:
	_choose_move_index(index)


func _choose_move_index(index: int) -> void:
	if index < 0 or index >= _move_ids.size():
		return
	choose_move(_move_ids[index])


func _resolve_player_command(command: BattleCommand) -> bool:
	if battle_manager == null \
		or battle_manager.phase != BattleConstants.PHASE_AWAITING_COMMANDS:
		return false
	var event_cursor := battle_manager.event_history.size()
	if not battle_manager.submit_command(command):
		_append_log("That action cannot be used: %s." % _humanize(battle_manager.last_error))
		_refresh()
		return false
	if not battle_manager.submit_ai_command(_ai):
		_append_log("The wild creature could not choose an action.")
		_refresh()
		return false
	if not battle_manager.resolve_turn():
		_append_log("The turn could not resolve: %s." % _humanize(battle_manager.last_error))
		_refresh()
		return false
	_present_events_from(event_cursor)
	_refresh()
	if battle_manager.phase == BattleConstants.PHASE_FINISHED:
		_show_finish()
	return true


func _refresh() -> void:
	if battle_manager == null:
		return
	var player := battle_manager.get_participant(BattleConstants.SIDE_PLAYER)
	var opponent := battle_manager.get_participant(BattleConstants.SIDE_OPPONENT)
	arena.present(player, opponent)
	turn_label.text = "TURN %d" % battle_manager.turn_number
	_update_hud(player, player_name, player_health, player_health_text, player_status)
	_update_hud(opponent, opponent_name, opponent_health, opponent_health_text, opponent_status)
	_rebuild_move_buttons(player)
	var accepts_commands := battle_manager.phase == BattleConstants.PHASE_AWAITING_COMMANDS
	var capsule_count := _inventory.get_quantity(&"basic_capsule") if _inventory != null else 0
	var tonic_count := _inventory.get_quantity(&"field_tonic") if _inventory != null else 0
	capture_button.text = "[C] CAPSULE  x%d" % capsule_count
	item_button.text = "[I] TONIC  x%d" % tonic_count
	capture_button.disabled = not accepts_commands or capsule_count <= 0
	item_button.disabled = not accepts_commands \
		or tonic_count <= 0 \
		or player.current_hp >= player.get_max_hp() \
		or player.is_defeated()
	run_button.disabled = not accepts_commands
	prompt_label.text = "Choose your action" if accepts_commands else "Battle complete"


func _update_hud(
	participant: BattleParticipant,
	name_label: Label,
	health_bar: ProgressBar,
	health_label: Label,
	status_label: Label
) -> void:
	name_label.text = "%s   Lv. %d" % [
		participant.species.display_name,
		participant.creature.level,
	]
	var maximum := maxi(participant.get_max_hp(), 1)
	health_bar.value = float(participant.current_hp) / float(maximum) * 100.0
	health_label.text = "HP  %d / %d" % [participant.current_hp, maximum]
	var status_names: Array[String] = []
	for raw_status_id in participant.active_statuses_by_id.keys():
		var definition := _catalog.get_status(StringName(str(raw_status_id)))
		status_names.append(definition.display_name if definition != null else _humanize(raw_status_id))
	status_names.sort()
	status_label.text = "STATUS  —" if status_names.is_empty() else "STATUS  %s" % ", ".join(status_names)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _health_color(health_bar.value)
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6
	health_bar.add_theme_stylebox_override("fill", fill)


func _rebuild_move_buttons(player: BattleParticipant) -> void:
	_move_ids.clear()
	for raw_move_id in player.move_slots_by_id.keys():
		_move_ids.append(StringName(str(raw_move_id)))
	_move_ids.sort()
	var accepts_commands := battle_manager.phase == BattleConstants.PHASE_AWAITING_COMMANDS
	for index in _move_buttons.size():
		var button := _move_buttons[index]
		if index >= _move_ids.size():
			button.text = "—"
			button.disabled = true
			continue
		var move_id := _move_ids[index]
		var move := _catalog.get_move(move_id)
		var slot := player.get_move_slot(move_id)
		button.text = "[%d] %s\n%s · %d/%d" % [
			index + 1,
			move.display_name,
			str(move.element_type_id).to_upper(),
			slot.remaining_uses,
			slot.maximum_uses,
		]
		button.disabled = not accepts_commands or not slot.can_use()


func _present_events_from(first_index: int) -> void:
	for index in range(first_index, battle_manager.event_history.size()):
		var event := battle_manager.event_history[index]
		match event.event_type:
			BattleConstants.EVENT_MOVE_USED:
				var actor := battle_manager.get_participant(event.payload["side"])
				var move := _catalog.get_move(event.payload["move_id"])
				_append_log("%s used %s!" % [actor.species.display_name, move.display_name])
			BattleConstants.EVENT_MOVE_MISSED:
				_append_log("The attack missed!")
			BattleConstants.EVENT_DAMAGE_DEALT:
				_append_log("It dealt %d damage.%s" % [
					event.payload["damage"],
					_effectiveness_text(float(event.payload["type_multiplier"])),
				])
				arena.show_impact(event.payload["target_side"])
			BattleConstants.EVENT_STATUS_APPLIED:
				var status := _catalog.get_status(event.payload["status_id"])
				var target := battle_manager.get_participant(event.payload["side"])
				_append_log("%s became %s!" % [
					target.species.display_name,
					status.display_name if status != null else _humanize(event.payload["status_id"]),
				])
			BattleConstants.EVENT_STATUS_BLOCKED_ACTION:
				_append_log("A status condition prevented the action!")
			BattleConstants.EVENT_STATUS_DAMAGE:
				_append_log("The status condition dealt %d damage." % event.payload["damage"])
				arena.show_impact(event.payload["side"])
			BattleConstants.EVENT_ITEM_USED:
				var item := _catalog.get_item(event.payload["item_id"])
				_append_log("Used %s and restored %d HP." % [item.display_name, event.payload["healing_applied"]])
			BattleConstants.EVENT_CAPTURE_ATTEMPTED:
				if bool(event.payload["success"]):
					_append_log("The capsule synchronized — capture successful!")
				else:
					_append_log("The wild creature broke free!")
			BattleConstants.EVENT_ESCAPE_ATTEMPTED:
				_append_log("You safely withdrew from the encounter.")
			BattleConstants.EVENT_CREATURE_DEFEATED:
				var defeated_species := _catalog.get_species(event.payload["species_id"])
				_append_log("%s was defeated." % defeated_species.display_name)


func _show_finish() -> void:
	var opponent := battle_manager.get_participant(BattleConstants.SIDE_OPPONENT)
	match battle_manager.outcome:
		BattleConstants.OUTCOME_PLAYER_VICTORY:
			finish_title.text = "VICTORY"
			finish_detail.text = "The wild %s was defeated." % opponent.species.display_name
		BattleConstants.OUTCOME_OPPONENT_CAPTURED:
			finish_title.text = "CREATURE CAPTURED"
			finish_detail.text = "%s joined your collection." % opponent.species.display_name
		BattleConstants.OUTCOME_PLAYER_ESCAPED:
			finish_title.text = "SAFE RETREAT"
			finish_detail.text = "You returned to the trail without taking another hit."
		BattleConstants.OUTCOME_OPPONENT_VICTORY:
			finish_title.text = "YOUR CREATURE FAINTED"
			finish_detail.text = "Your companion will recover when you return to exploration."
		_:
			finish_title.text = "BATTLE ENDED"
			finish_detail.text = "The encounter is over."
	finish_panel.show()
	continue_button.grab_focus()


func _apply_accessibility() -> void:
	if not is_node_ready():
		return
	var high_contrast := _preferences != null and _preferences.high_contrast
	var reduced_motion := _preferences != null and _preferences.reduced_motion
	var text_scale := _preferences.text_scale if _preferences != null else 1.0
	arena.set_accessibility(high_contrast, reduced_motion)
	_set_scaled_font(turn_label, 18, text_scale)
	_set_scaled_font(opponent_name, 21, text_scale)
	_set_scaled_font(opponent_health_text, 14, text_scale)
	_set_scaled_font(opponent_status, 13, text_scale)
	_set_scaled_font(player_name, 21, text_scale)
	_set_scaled_font(player_health_text, 14, text_scale)
	_set_scaled_font(player_status, 13, text_scale)
	_set_scaled_font(prompt_label, 18, text_scale)
	battle_log.add_theme_font_size_override("normal_font_size", int(round(16.0 * text_scale)))
	for button in _move_buttons:
		button.add_theme_font_size_override("font_size", int(round(15.0 * text_scale)))
	for button in [capture_button, item_button, run_button]:
		button.add_theme_font_size_override("font_size", int(round(14.0 * text_scale)))
	_set_scaled_font(finish_title, 30, text_scale)
	_set_scaled_font(finish_detail, 18, text_scale)
	continue_button.add_theme_font_size_override("font_size", int(round(17.0 * text_scale)))


func _set_scaled_font(label: Label, base_size: int, scale_factor: float) -> void:
	label.add_theme_font_size_override("font_size", int(round(base_size * scale_factor)))


func _focus_first_action() -> void:
	for button in _move_buttons:
		if not button.disabled:
			button.grab_focus()
			return


func _append_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 7:
		_log_lines.pop_front()
	if is_node_ready():
		battle_log.text = "\n".join(_log_lines)


func _health_color(percent: float) -> Color:
	if percent <= 25.0:
		return Color("ed5b55")
	if percent <= 50.0:
		return Color("f2c94c")
	return Color("65d67e")


func _effectiveness_text(multiplier: float) -> String:
	if multiplier > 1.0:
		return " It was highly effective!"
	if multiplier < 1.0:
		return " It was resisted."
	return ""


func _humanize(value: Variant) -> String:
	return str(value).replace("_", " ")
