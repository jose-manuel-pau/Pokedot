class_name BattleParty
extends RefCounted
## Ordered team with one active member. BattleParticipant objects retain HP,
## move uses, and persistent statuses while on the bench.

const MAX_MEMBERS := 6

var side: StringName
var members: Array[BattleParticipant] = []
var active_index: int = 0


func get_active() -> BattleParticipant:
	if active_index < 0 or active_index >= members.size():
		return null
	return members[active_index]


func get_member(instance_id: String) -> BattleParticipant:
	for member in members:
		if member.creature.instance_id == instance_id:
			return member
	return null


func can_switch_to(instance_id: String) -> bool:
	var target := get_member(instance_id)
	return target != null and target != get_active() and not target.is_defeated()


func switch_to(instance_id: String) -> bool:
	if not can_switch_to(instance_id):
		return false
	for index in members.size():
		if members[index].creature.instance_id == instance_id:
			active_index = index
			return true
	return false


func get_available_bench() -> Array[BattleParticipant]:
	var available: Array[BattleParticipant] = []
	var active := get_active()
	for member in members:
		if member != active and not member.is_defeated():
			available.append(member)
	return available


func first_available_bench() -> BattleParticipant:
	var available := get_available_bench()
	return available[0] if not available.is_empty() else null


func has_usable_members() -> bool:
	for member in members:
		if not member.is_defeated():
			return true
	return false

