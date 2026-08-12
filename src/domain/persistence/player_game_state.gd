class_name PlayerGameState
extends RefCounted
## Aggregate root persisted by SaveGameRepository.

var player_id: String
var player_name: String
var play_time_seconds: int = 0
var current_map_id: StringName
var player_position: Vector2i
var player_facing: Vector2i = Vector2i.DOWN
var inventory: Inventory = Inventory.new()
var collection: CreatureCollection = CreatureCollection.new()
