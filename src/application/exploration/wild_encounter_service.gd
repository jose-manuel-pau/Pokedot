class_name WildEncounterService
extends RefCounted
## Resolves per-step trigger, weighted species, and inclusive level selection.

var _random: ExplorationRandomSource


func _init(random_source: ExplorationRandomSource) -> void:
	_random = random_source


func try_create(
	zone: EncounterZoneDefinition,
	map_id: StringName,
	cell: Vector2i,
	encounter_sequence: int
) -> WildEncounterRequest:
	if zone == null or zone.entries.is_empty() or zone.total_weight() <= 0:
		return null
	if _random.next_float() >= zone.encounter_rate:
		return null
	var entry := _choose_entry(zone)
	if entry == null:
		return null
	var level_range := entry.max_level - entry.min_level + 1
	var request := WildEncounterRequest.new()
	request.encounter_id = "%s_%s_%d" % [map_id, zone.zone_id, encounter_sequence]
	request.map_id = map_id
	request.zone_id = zone.zone_id
	request.grid_position = cell
	request.species_id = entry.species_id
	request.level = entry.min_level + _random.next_int(level_range)
	return request


func _choose_entry(zone: EncounterZoneDefinition) -> EncounterEntryDefinition:
	var total := zone.total_weight()
	var roll := _random.next_float() * total
	var cumulative := 0
	for entry in zone.entries:
		cumulative += entry.weight
		if roll < cumulative:
			return entry
	return zone.entries[-1]
