class_name BalanceAnalyzer
extends RefCounted
## Lightweight tuning guardrails. Threshold breaches are visible without
## embedding balance policy into combat formulas or content resources.

const MIN_BASE_STAT_TOTAL := 280
const MAX_BASE_STAT_TOTAL := 360
const MIN_DAMAGING_MOVE_POWER := 35
const MAX_DAMAGING_MOVE_POWER := 90
const MAX_ENCOUNTER_WEIGHT_SHARE := 0.70


func analyze(catalog: ContentCatalog) -> BalanceReport:
	var report := BalanceReport.new()
	if catalog == null:
		_add_issue(report, ValidationIssue.Severity.ERROR, &"missing_balance_catalog", "balance", "A content catalog is required.")
		return report
	_analyze_species(catalog, report)
	_analyze_moves(catalog, report)
	_analyze_encounters(catalog, report)
	return report


func _analyze_species(catalog: ContentCatalog, report: BalanceReport) -> void:
	var totals: Dictionary = {}
	var catch_rates: Dictionary = {}
	var reward_ratios: Dictionary = {}
	for species_id in _sorted_ids(catalog.species_by_id):
		var species := catalog.get_species(species_id)
		var total := species.base_stats.sum()
		totals[str(species_id)] = total
		catch_rates[str(species_id)] = species.catch_rate
		reward_ratios[str(species_id)] = snappedf(float(species.experience_yield) / float(total), 0.001)
		if total < MIN_BASE_STAT_TOTAL or total > MAX_BASE_STAT_TOTAL:
			_add_issue(
				report,
				ValidationIssue.Severity.WARNING,
				&"base_stat_total_outlier",
				"species.%s.base_stats" % species_id,
				"Base-stat total %d is outside the production target %d-%d." % [total, MIN_BASE_STAT_TOTAL, MAX_BASE_STAT_TOTAL]
			)
	report.metrics["species_count"] = totals.size()
	report.metrics["base_stat_totals"] = totals
	report.metrics["catch_rates"] = catch_rates
	report.metrics["experience_per_base_stat"] = reward_ratios


func _analyze_moves(catalog: ContentCatalog, report: BalanceReport) -> void:
	var damaging_moves_by_type: Dictionary = {}
	for type_id in _sorted_ids(catalog.types_by_id):
		damaging_moves_by_type[str(type_id)] = 0
	var powers: Dictionary = {}
	for move_id in _sorted_ids(catalog.moves_by_id):
		var move := catalog.get_move(move_id)
		if move.category == "status":
			continue
		powers[str(move_id)] = move.power
		var type_key := str(move.element_type_id)
		damaging_moves_by_type[type_key] = int(damaging_moves_by_type.get(type_key, 0)) + 1
		if move.power < MIN_DAMAGING_MOVE_POWER or move.power > MAX_DAMAGING_MOVE_POWER:
			_add_issue(
				report,
				ValidationIssue.Severity.WARNING,
				&"move_power_outlier",
				"moves.%s.power" % move_id,
				"Power %d is outside the production target %d-%d." % [move.power, MIN_DAMAGING_MOVE_POWER, MAX_DAMAGING_MOVE_POWER]
			)
	for raw_type_id in damaging_moves_by_type.keys():
		if int(damaging_moves_by_type[raw_type_id]) == 0:
			_add_issue(
				report,
				ValidationIssue.Severity.ERROR,
				&"type_without_damaging_move",
				"types.%s" % raw_type_id,
				"Every element needs at least one damaging move for coverage."
			)
	report.metrics["damaging_move_powers"] = powers
	report.metrics["damaging_moves_by_type"] = damaging_moves_by_type


func _analyze_encounters(catalog: ContentCatalog, report: BalanceReport) -> void:
	var appearance_counts: Dictionary = {}
	var weight_shares: Dictionary = {}
	for species_id in _sorted_ids(catalog.species_by_id):
		appearance_counts[str(species_id)] = 0
	for map_id in _sorted_ids(catalog.maps_by_id):
		var map := catalog.get_map(map_id)
		for zone in map.encounter_zones:
			var total_weight := zone.total_weight()
			if total_weight <= 0:
				continue
			for entry in zone.entries:
				var species_key := str(entry.species_id)
				appearance_counts[species_key] = int(appearance_counts.get(species_key, 0)) + 1
				var path := "%s.%s.%s" % [map_id, zone.zone_id, entry.species_id]
				var share := float(entry.weight) / float(total_weight)
				weight_shares[path] = snappedf(share, 0.001)
				if share > MAX_ENCOUNTER_WEIGHT_SHARE:
					_add_issue(
						report,
						ValidationIssue.Severity.WARNING,
						&"dominant_encounter_entry",
						"maps.%s.encounter_zones.%s" % [map_id, zone.zone_id],
						"Species '%s' owns %.1f%% of this encounter table." % [entry.species_id, share * 100.0]
					)
	for raw_species_id in appearance_counts.keys():
		if int(appearance_counts[raw_species_id]) == 0:
			_add_issue(
				report,
				ValidationIssue.Severity.ERROR,
				&"species_not_obtainable",
				"species.%s" % raw_species_id,
				"Every production species must appear in an encounter table."
			)
	report.metrics["encounter_appearances"] = appearance_counts
	report.metrics["encounter_weight_shares"] = weight_shares


func _sorted_ids(source: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw_id in source.keys():
		ids.append(StringName(str(raw_id)))
	ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return str(left) < str(right)
	)
	return ids


func _add_issue(
	report: BalanceReport,
	severity: ValidationIssue.Severity,
	code: StringName,
	path: String,
	message: String
) -> void:
	report.issues.append(ValidationIssue.create(severity, code, path, message))
