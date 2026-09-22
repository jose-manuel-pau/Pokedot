class_name InteractionResult
extends RefCounted

var success: bool = false
var reason: StringName = &""
var interaction_type: StringName = &""
var npc_id: StringName
var speaker_name: String
var dialogue: Array[String] = []
var chest_id: StringName
var item_id: StringName
var quantity: int = 0
var quantity_after: int = 0
var gift_id: StringName
var choice_group_id: StringName
var species_id: StringName
var creature_instance_id: String
var collection_destination: StringName
