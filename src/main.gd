extends Node

const CONTENT_PATH := "res://data"

@onready var exploration_screen: ExplorationScreen = $ExplorationScreen


func _ready() -> void:
	var repository := JsonContentRepository.new()
	var result := repository.load_catalog(CONTENT_PATH)

	if result.has_errors():
		for issue in result.issues:
			push_error(issue.format())
		return

	print(
		"Content ready: %d species, %d moves, %d types, %d statuses, %d growth curves, %d items, %d maps, %d art concepts"
		% [
			result.catalog.species_by_id.size(),
			result.catalog.moves_by_id.size(),
			result.catalog.types_by_id.size(),
			result.catalog.statuses_by_id.size(),
			result.catalog.growth_curves_by_id.size(),
			result.catalog.items_by_id.size(),
			result.catalog.maps_by_id.size(),
			result.catalog.creature_concepts_by_id.size(),
		]
	)
	exploration_screen.initialize(result.catalog)

