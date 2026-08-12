class_name TurnOrderResolver
extends RefCounted
## Orders commands by action priority, then Speed, then a deterministic random
## shuffle for exact ties. Randomness is never called inside the sort comparator.

var _random: BattleRandomSource


func _init(random_source: BattleRandomSource) -> void:
	_random = random_source


func resolve(
	commands: Array[BattleCommand],
	participants_by_side: Dictionary,
	catalog: ContentCatalog
) -> Array[BattleCommand]:
	var entries: Array[TurnOrderEntry] = []
	for command in commands:
		var participant := participants_by_side.get(command.actor_side) as BattleParticipant
		if participant != null:
			entries.append(TurnOrderEntry.create(
				command,
				command.get_priority(catalog),
				participant.get_speed()
			))
	entries.sort_custom(Callable(self, "_comes_before"))
	_shuffle_exact_ties(entries)

	var ordered: Array[BattleCommand] = []
	for entry in entries:
		ordered.append(entry.command)
	return ordered


func _comes_before(left: TurnOrderEntry, right: TurnOrderEntry) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	if left.speed != right.speed:
		return left.speed > right.speed
	return str(left.command.actor_side) < str(right.command.actor_side)


func _shuffle_exact_ties(entries: Array[TurnOrderEntry]) -> void:
	var group_start := 0
	while group_start < entries.size():
		var group_end := group_start + 1
		while group_end < entries.size() and _same_tier(entries[group_start], entries[group_end]):
			group_end += 1
		for index in range(group_end - 1, group_start, -1):
			var swap_index := group_start + _random.next_int(index - group_start + 1)
			var temporary := entries[index]
			entries[index] = entries[swap_index]
			entries[swap_index] = temporary
		group_start = group_end


func _same_tier(left: TurnOrderEntry, right: TurnOrderEntry) -> bool:
	return left.priority == right.priority and left.speed == right.speed

