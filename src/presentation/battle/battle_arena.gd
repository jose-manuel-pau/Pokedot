class_name BattleArena
extends Control
## Code-drawn battle arena and original creature silhouettes. This gives every
## catalog creature a readable in-game representation without coupling combat
## rules to art assets. Finished sprite sheets can replace this view later.

const TYPE_COLORS := {
	&"ember": Color("f06449"),
	&"stone": Color("9b8b72"),
	&"tide": Color("55b9dc"),
	&"grove": Color("71bd63"),
	&"gale": Color("b5e5e8"),
}

const PLAYER_CREATURE_CENTER := Vector2(355.0, 540.0)
const OPPONENT_CREATURE_CENTER := Vector2(866.0, 292.0)
const PLAYER_PLATFORM_CENTER := Vector2(355.0, 640.0)
const OPPONENT_PLATFORM_CENTER := Vector2(866.0, 388.0)
const PLAYER_CREATURE_SCALE := 1.28
const OPPONENT_CREATURE_SCALE := 1.0

# Conservative local-space silhouette bounds include line widths, antlers,
# wings, tails, legs, and spikes. Presentation tests use them to guarantee that
# every current creature remains inside the viewport and clear of every HUD.
const CREATURE_LOCAL_BOUNDS := {
	&"cindermite": Rect2(-76.0, -66.0, 152.0, 108.0),
	&"reedling": Rect2(-72.0, -84.0, 144.0, 150.0),
	&"gustlet": Rect2(-82.0, -64.0, 164.0, 112.0),
	&"aurorook": Rect2(-108.0, -78.0, 216.0, 148.0),
	&"cairnback": Rect2(-84.0, -72.0, 168.0, 138.0),
}
const GENERIC_LOCAL_BOUNDS := Rect2(-72.0, -58.0, 144.0, 112.0)

var player: BattleParticipant
var opponent: BattleParticipant
var high_contrast: bool = false
var reduced_motion: bool = false
var _impact_side: StringName = &""
var _impact_remaining: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func present(
	player_participant: BattleParticipant,
	opponent_participant: BattleParticipant
) -> void:
	player = player_participant
	opponent = opponent_participant
	queue_redraw()


func set_accessibility(use_high_contrast: bool, use_reduced_motion: bool) -> void:
	high_contrast = use_high_contrast
	reduced_motion = use_reduced_motion
	queue_redraw()


func show_impact(target_side: StringName) -> void:
	_impact_side = target_side
	_impact_remaining = 0.0 if reduced_motion else 0.28
	queue_redraw()


func get_creature_screen_bounds(
	side: StringName,
	species_id: StringName
) -> Rect2:
	var local_bounds: Rect2 = CREATURE_LOCAL_BOUNDS.get(
		species_id,
		GENERIC_LOCAL_BOUNDS
	)
	var center := PLAYER_CREATURE_CENTER \
		if side == BattleConstants.SIDE_PLAYER else OPPONENT_CREATURE_CENTER
	var scale_factor := PLAYER_CREATURE_SCALE \
		if side == BattleConstants.SIDE_PLAYER else OPPONENT_CREATURE_SCALE
	return Rect2(
		center + local_bounds.position * scale_factor,
		local_bounds.size * scale_factor
	)


func _process(delta: float) -> void:
	if _impact_remaining <= 0.0:
		return
	_impact_remaining = maxf(_impact_remaining - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var sky := Color("071921") if high_contrast else Color("173843")
	var horizon := Color("135f62") if high_contrast else Color("3c7568")
	var ground := Color("163927") if high_contrast else Color("6d8a5c")
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 230), Vector2(170, 125), Vector2(330, 235),
		Vector2(515, 92), Vector2(730, 230), Vector2(940, 118),
		Vector2(size.x, 245), Vector2(size.x, 430), Vector2(0, 430),
	]), horizon)
	draw_rect(Rect2(0, 375, size.x, size.y - 375), ground)
	_draw_grass()
	_draw_platform(OPPONENT_PLATFORM_CENTER, Vector2(205, 48))
	_draw_platform(PLAYER_PLATFORM_CENTER, Vector2(245, 58))
	if opponent != null:
		_draw_creature(
			opponent,
			OPPONENT_CREATURE_CENTER,
			OPPONENT_CREATURE_SCALE,
			false
		)
	if player != null:
		_draw_creature(
			player,
			PLAYER_CREATURE_CENTER,
			PLAYER_CREATURE_SCALE,
			true
		)
	if _impact_remaining > 0.0:
		var center := PLAYER_CREATURE_CENTER \
			if _impact_side == BattleConstants.SIDE_PLAYER \
			else OPPONENT_CREATURE_CENTER
		var alpha := _impact_remaining / 0.28
		draw_circle(center, 82.0 + (1.0 - alpha) * 24.0, Color(1.0, 0.92, 0.45, alpha * 0.38), false, 8.0)


func _draw_grass() -> void:
	var grass_color := Color("b8ef79") if high_contrast else Color("a9c66d")
	for index in range(32):
		var x := float((index * 83 + 29) % 1280)
		var y := float(400 + (index * 47) % 270)
		draw_line(Vector2(x, y), Vector2(x + 5, y - 14), grass_color, 2.0)
		draw_line(Vector2(x + 5, y), Vector2(x + 2, y - 11), grass_color.darkened(0.12), 2.0)


func _draw_platform(center: Vector2, platform_size: Vector2) -> void:
	var shadow := Color(0.02, 0.08, 0.08, 0.48)
	draw_set_transform(center, 0.0, platform_size)
	draw_circle(Vector2.ZERO, 1.0, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_creature(
	participant: BattleParticipant,
	center: Vector2,
	scale_factor: float,
	facing_right: bool
) -> void:
	var species := participant.species
	var primary := _species_color(species, 0)
	var secondary := _species_color(species, 1).lightened(0.12)
	var outline := Color("071013") if high_contrast else primary.darkened(0.58)
	var direction := 1.0 if facing_right else -1.0
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	match species.species_id:
		&"cindermite":
			_draw_cindermite(primary, secondary, outline, direction)
		&"reedling":
			_draw_reedling(primary, secondary, outline, direction)
		&"gustlet":
			_draw_gustlet(primary, secondary, outline, direction)
		&"aurorook":
			_draw_aurorook(primary, secondary, outline, direction)
		&"cairnback":
			_draw_cairnback(primary, secondary, outline, direction)
		_:
			_draw_generic(primary, secondary, outline, direction)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cindermite(primary: Color, secondary: Color, outline: Color, direction: float) -> void:
	_draw_body(Vector2.ZERO, Vector2(58, 37), primary, outline)
	for index in range(4):
		var x := -31.0 + index * 20.0
		var spike := PackedVector2Array([Vector2(x, -29), Vector2(x + 8, -56 - absf(x) * 0.18), Vector2(x + 16, -27)])
		draw_colored_polygon(spike, secondary)
		draw_polyline(spike, outline, 4.0)
	draw_circle(Vector2(48 * direction, -3), 24, primary.lightened(0.12))
	draw_arc(Vector2(48 * direction, -3), 24, 0, TAU, 24, outline, 4.0)
	_draw_eye(Vector2(58 * direction, -10), outline)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(-34, side * 20), Vector2(-62, side * 34), outline, 7.0)


func _draw_reedling(primary: Color, secondary: Color, outline: Color, direction: float) -> void:
	_draw_body(Vector2(-8 * direction, 8), Vector2(51, 35), primary, outline)
	draw_circle(Vector2(39 * direction, -20), 27, secondary)
	draw_arc(Vector2(39 * direction, -20), 27, 0, TAU, 24, outline, 4.0)
	for side in [-1.0, 1.0]:
		var base := Vector2(28 * direction, -41)
		draw_line(base, Vector2((29 + 18 * side) * direction, -76), outline, 6.0)
		draw_line(Vector2((29 + 11 * side) * direction, -62), Vector2((42 + 20 * side) * direction, -78), secondary, 5.0)
	_draw_eye(Vector2(49 * direction, -25), outline)
	for x in [-30.0, 18.0]:
		draw_line(Vector2(x, 31), Vector2(x - 3, 61), outline, 9.0)


func _draw_gustlet(primary: Color, secondary: Color, outline: Color, direction: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 4), Vector2(-77 * direction, -28), Vector2(-49 * direction, 29)]), secondary)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 5), Vector2(61 * direction, -39), Vector2(42 * direction, 33)]), primary.lightened(0.1))
	_draw_body(Vector2.ZERO, Vector2(37, 43), primary, outline)
	draw_circle(Vector2(22 * direction, -36), 23, secondary)
	draw_arc(Vector2(22 * direction, -36), 23, 0, TAU, 20, outline, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(39 * direction, -38), Vector2(62 * direction, -31), Vector2(39 * direction, -25)]), Color("f3c95d"))
	_draw_eye(Vector2(29 * direction, -42), outline)


func _draw_aurorook(primary: Color, secondary: Color, outline: Color, direction: float) -> void:
	_draw_body(Vector2.ZERO, Vector2(42, 51), primary, outline)
	draw_circle(Vector2(25 * direction, -46), 25, secondary)
	draw_arc(Vector2(25 * direction, -46), 25, 0, TAU, 22, outline, 4.0)
	for index in range(3):
		var y := 10.0 + index * 13.0
		draw_line(Vector2(-30 * direction, y), Vector2((-82 - index * 9) * direction, y + 26), Color("9cf3e5").lerp(primary, index * 0.22), 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(44 * direction, -48), Vector2(66 * direction, -40), Vector2(44 * direction, -34)]), Color("f2d970"))
	_draw_eye(Vector2(31 * direction, -52), outline)


func _draw_cairnback(primary: Color, secondary: Color, outline: Color, direction: float) -> void:
	_draw_body(Vector2(-7 * direction, 4), Vector2(67, 43), primary, outline)
	for index in range(3):
		var rock_center := Vector2((-34 + index * 34) * direction, -30 - (index % 2) * 10)
		draw_circle(rock_center, 27, secondary.darkened(index * 0.08))
		draw_arc(rock_center, 27, 0, TAU, 16, outline, 4.0)
	draw_circle(Vector2(54 * direction, 2), 24, primary.lightened(0.08))
	draw_arc(Vector2(54 * direction, 2), 24, 0, TAU, 20, outline, 4.0)
	_draw_eye(Vector2(62 * direction, -5), outline)
	for x in [-38.0, 25.0]:
		draw_line(Vector2(x, 35), Vector2(x - 2, 57), outline, 11.0)


func _draw_generic(primary: Color, secondary: Color, outline: Color, direction: float) -> void:
	_draw_body(Vector2.ZERO, Vector2(51, 43), primary, outline)
	draw_circle(Vector2(38 * direction, -21), 27, secondary)
	draw_arc(Vector2(38 * direction, -21), 27, 0, TAU, 22, outline, 4.0)
	_draw_eye(Vector2(47 * direction, -28), outline)


func _draw_body(center: Vector2, body_scale: Vector2, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array()
	for index in range(29):
		var angle := TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * body_scale.x, sin(angle) * body_scale.y))
	draw_colored_polygon(points, fill)
	draw_polyline(points, outline, 4.0)


func _draw_eye(position: Vector2, outline: Color) -> void:
	draw_circle(position, 7.5, Color.WHITE)
	draw_circle(position + Vector2(1.5, 0), 3.6, outline)
	draw_circle(position + Vector2(2.3, -1.2), 1.2, Color.WHITE)


func _species_color(species: CreatureSpeciesDefinition, index: int) -> Color:
	if species.element_types.is_empty():
		return Color("b9c2c7")
	var type_index := mini(index, species.element_types.size() - 1)
	return TYPE_COLORS.get(species.element_types[type_index], Color("b9c2c7"))
