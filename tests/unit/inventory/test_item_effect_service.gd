extends TestSuite

var catalog: ContentCatalog
var status_service: StatusEffectService
var service: ItemEffectService


func _init() -> void:
	super("ItemEffectService")
	catalog = BattleTestFactory.create_catalog()
	status_service = StatusEffectService.new(catalog)
	service = ItemEffectService.new(catalog, status_service)


func run() -> void:
	_test_flat_healing_and_cap()
	_test_fractional_healing_rounds_up()
	_test_healing_rejections()
	_test_remedy_removes_matching_statuses_only()
	_test_item_definition_rejections()


func _participant(hp: int = 99999) -> BattleParticipant:
	return BattleTestFactory.create_participant(
		BattleConstants.SIDE_PLAYER,
		&"cindermite",
		20,
		[&"cinder_jab"],
		catalog,
		hp
	)


func _test_flat_healing_and_cap() -> void:
	begin_case("flat healing")
	var target := _participant(1)
	var result := service.apply(&"field_tonic", target)
	assert_true(result.success)
	assert_equal(result.healing_applied, 20)
	assert_equal(target.current_hp, 21)
	assert_equal(target.creature.current_hp, 21)
	target.current_hp = target.get_max_hp() - 5
	target.creature.current_hp = target.current_hp
	result = service.apply(&"grand_tonic", target)
	assert_equal(result.healing_applied, 5)
	assert_equal(target.current_hp, target.get_max_hp())


func _test_fractional_healing_rounds_up() -> void:
	begin_case("fractional healing")
	var target := _participant(1)
	var result := service.apply(&"renewal_draught", target)
	assert_true(result.success)
	assert_equal(result.healing_applied, ceili(target.get_max_hp() * 0.5))


func _test_healing_rejections() -> void:
	begin_case("healing rejection")
	var full := _participant()
	assert_equal(service.apply(&"field_tonic", full).reason, &"target_at_full_hp")
	var defeated := _participant(0)
	assert_equal(service.apply(&"field_tonic", defeated).reason, &"target_defeated")
	assert_equal(defeated.current_hp, 0)


func _test_remedy_removes_matching_statuses_only() -> void:
	begin_case("status remedy")
	var target := _participant()
	status_service.apply_status(target, &"scorch", 1)
	status_service.apply_status(target, &"drowsy", 1)
	status_service.apply_status(target, &"rooted", 1)
	var result := service.apply(&"clarity_herb", target)
	assert_true(result.success)
	assert_equal(result.removed_status_ids, [&"drowsy", &"rooted"])
	assert_true(target.has_status(&"scorch"))
	assert_false(target.has_status(&"drowsy"))
	assert_false(target.has_status(&"rooted"))
	assert_true(target.creature.persistent_status_ids.has(&"scorch"))
	assert_false(target.creature.persistent_status_ids.has(&"drowsy"))
	assert_equal(service.apply(&"clarity_herb", target).reason, &"no_matching_status")


func _test_item_definition_rejections() -> void:
	begin_case("unsupported definitions")
	var target := _participant(1)
	assert_equal(service.apply(&"missing", target).reason, &"unknown_item")
	assert_equal(service.apply(&"survey_compass", target).reason, &"item_not_battle_usable")
	assert_equal(service.apply(&"basic_capsule", target).reason, &"unsupported_item_effect")
