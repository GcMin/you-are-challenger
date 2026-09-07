extends SceneTree

var scene: Node3D
var session: RunSession
var player: ChallengerPlayer
var boss: ArenaBoss
var passed: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failures.append(label)
		push_error(label)

func fresh(start: bool = true) -> void:
	scene.reset_training()
	scene.close_menu()
	if start:
		scene.start_run()
	player.controls_enabled = false

func death(id: StringName) -> void:
	player.revive_protection_left = 0.0
	player.vitals.dodge_invulnerable = false
	player.vitals.protection_left = 0.0
	player.vitals.take_damage(DamageData.new(id, 1000))

func inside_cage() -> bool:
	for side: int in range(8):
		var normal := Vector3(sin(side * TAU / 8.0), 0, cos(side * TAU / 8.0))
		if player.position.dot(normal) > 10.25:
			return false
	return true

func run() -> void:
	scene = (load("res://run/run_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	session = scene.session
	player = scene.player
	boss = scene.boss
	scene.snapshot_path = "res://test_output/test_chest.json"
	scene.result_path = "res://test_output/test_run_result.json"
	session.set_physics_process(false)
	player.set_physics_process(false)
	boss.set_physics_process(false)
	await physics_frame
	check(session.stage == RunSession.Stage.PREPARE and session.revives == 2, "Preparation has two run-wide revives")
	check(scene.chest_node == null and not boss.engaged, "Preparation has no inheritance chest or attacking Boss")
	check(not boss.vitals.take_damage(DamageData.new(&"prep_hit", 100)), "Preparation practice swings cannot pre-damage Boss")
	check(session.inventory.weapon != null and session.inventory.items.size() == 2, "Exactly one weapon and two item slots")
	check(scene.pickups.get_child_count() == 3, "Three static peripheral supplies exist")
	scene.start_run()
	check(session.stage == RunSession.Stage.BATTLE, "Start button enters battle")
	check(scene.cage_bodies.all(func(body: StaticBody3D) -> bool: return body.collision_layer == 1), "Battle locks the eight arena edges")
	check(not boss.engaged, "Opening gives one second of safe entry")
	session.tick(1.01)
	check(boss.engaged and session.elapsed > 1, "Boss and hard clock run after entry buffer")
	check(not session.start() and session.elapsed > 1, "Repeated start cannot reset the clock")
	for frame: int in range(180):
		await physics_frame
		player.tick(1.0 / 60.0, Vector3.RIGHT)
	check(inside_cage(), "Battle cage prevents walking outside")
	player.request_action(&"roll", Vector3.RIGHT)
	for frame: int in range(40):
		await physics_frame
		player.tick(1.0 / 60.0, Vector3.RIGHT)
	check(inside_cage(), "Roll cannot bypass battle cage")

	fresh()
	boss.vitals.take_damage(DamageData.new(&"boss_wound", 120))
	session.tick(5)
	death(&"first_death")
	check(not scene.hud.notice.text.contains("失败") and not scene.hud.notice.text.contains("R"), "Pending first death never announces defeat or retry")
	session.tick(0.016)
	check(session.stage == RunSession.Stage.DOWNED and session.revives == 1 and session.deaths == 1, "First death consumes one revive once")
	check(scene.hud.notice.text.contains("自动复活") and scene.hud.notice.text.contains("1") and not scene.hud.notice.text.contains("R"), "First downed notice explains automatic revival and remaining charge")
	var retry := InputEventKey.new()
	retry.pressed = true
	retry.physical_keycode = KEY_R
	scene._input(retry)
	check(session.stage == RunSession.Stage.DOWNED and session.deaths == 1, "R cannot restart during automatic revival")
	check(not boss.engaged and boss.vitals.current == 480, "Downed transition stops attacks but preserves Boss damage")
	var before_time := session.elapsed
	session.tick(1.21)
	check(session.stage == RunSession.Stage.BATTLE and session.elapsed > before_time + 1, "Clock continues throughout revival")
	check(player.vitals.current == 50 and player.stamina == 100, "Revival restores half HP and full stamina")
	check(not scene.hud.notice.text.contains("失败") and not scene.hud.notice.text.contains("R"), "Successful revival clears downed feedback without false defeat")
	check(player.velocity == Vector3.ZERO and player.position.distance_to(boss.position) > 8, "Revival clears momentum and selects distant safe marker")
	check(player.revive_protection_left == 2 and not player.vitals.take_damage(DamageData.new(&"protected", 30)), "Revival grants two-second protection")
	player.request_action(&"light")
	check(player.revive_protection_left == 0 and not player.vitals.dodge_invulnerable, "Active attack ends revival protection")
	death(&"second_death")
	session.tick(0.016)
	check(session.revives == 0 and session.stage == RunSession.Stage.DOWNED, "Second death uses last revive")
	check(scene.hud.notice.text.contains("自动复活") and scene.hud.notice.text.contains("0") and not scene.hud.notice.text.contains("失败"), "Second downed notice still announces automatic revival")
	session.tick(1.21)
	death(&"third_death")
	session.tick(0.016)
	check(session.stage == RunSession.Stage.RESULT and not session.won and session.deaths == 3, "Third death fails the same run")
	check(scene.hud.notice.text.contains("挑战失败") and scene.hud.notice.text.contains("R"), "Only exhausted revives produce defeat and retry notice")
	check(scene.chest_node == null and session.revives == 0, "Revive exhaustion creates no reward chest")
	var ended_time := session.elapsed
	session.tick(10)
	check(session.elapsed == ended_time, "Result stops the battle clock")

	fresh()
	session.time_limit = 0.05
	session.tick(0.06)
	check(session.stage == RunSession.Stage.RESULT and session.reason == "挑战超时", "Hard time limit produces timeout failure")
	check(not boss.engaged and not boss.marker.visible and scene.chest_node == null, "Timeout stops AI, active marker and reward generation")
	check(not player.vitals.take_damage(DamageData.new(&"after_timeout", 100)), "Timeout disables residual player damage")
	session.time_limit = 180

	fresh(false)
	var inventory := session.inventory
	var potion_id := inventory.items[0].uid
	check(not scene.use_item(0) and inventory.items[0].uid == potion_id, "Full HP retains potion instead of wasting it")
	player.vitals.restore_health(80)
	check(scene.use_item(0) and player.vitals.current == 100 and inventory.items[0] == null, "Potion heals once and clamps to maximum")
	player.stamina = 30
	check(scene.use_item(1) and player.stamina == 80 and inventory.items[1] == null, "Drink restores fifty stamina and consumes one item")
	check(not scene.use_item(1), "Empty slot cannot consume twice")
	fresh(false)
	player.position = Vector3(13, 0.05, 0)
	var ground := scene.nearest_pickup() as WorldPickup
	var ground_id := ground.item.uid
	var old_id := inventory.items[0].uid
	check(not scene.pickup_nearest() and ground.available, "Full item slots reject pickup without deleting ground item")
	check(scene.pickup_nearest(0) and inventory.items[0].uid == ground_id, "Explicit slot replacement picks up chosen item")
	check(scene.pickups.get_children().any(func(node: WorldPickup) -> bool: return node.item.uid == old_id), "Replacement leaves old item on ground")
	check(inventory.store(0) and inventory.chest[0].uid == ground_id, "Newly collected item can be stored with its original identity")
	check(inventory.withdraw(0) and inventory.items[0].uid == ground_id, "Collected item withdraws without changing its identity")
	player.position = Vector3(0, 0.05, -13)
	var old_weapon := inventory.weapon.uid
	check(scene.pickup_nearest(), "Second weapon replaces the single weapon slot")
	check(scene.pickups.get_children().any(func(node: WorldPickup) -> bool: return node.item.uid == old_weapon), "Weapon swap drops previous sword instead of hiding it")

	fresh()
	session._drop_left = 0.01
	session.tick(0.02)
	var drop := scene.pickups.get_child(3) as WorldPickup
	check(session.drops == 1 and drop.position.length() <= 8.01 and not drop.available, "Airdrop is announced at a reachable interior point before landing")
	var retained_id := drop.item.uid
	boss.vitals.take_damage(DamageData.new(&"victory", 1000))
	check(session.stage == RunSession.Stage.LOOT and session.won, "Boss death opens unlimited looting")
	check(scene.chest_node != null and scene.chest_node.position == Vector3.ZERO, "Victory creates chest at arena center")
	var chest_id: int = scene.chest_node.get_instance_id()
	session.boss_died()
	check(scene.chest_node.get_instance_id() == chest_id, "Victory cannot create a duplicate chest")
	check(scene.cage_bodies.all(func(body: StaticBody3D) -> bool: return body.collision_layer == 0), "Victory releases all battle barriers")
	check(not player.vitals.take_damage(DamageData.new(&"after_win", 100)), "Victory disables residual damage")
	ended_time = session.elapsed
	session.tick(500)
	check(session.stage == RunSession.Stage.LOOT and session.elapsed == ended_time and session.drops == 1, "Looting has no countdown and creates no new airdrops")
	drop._process(2.0)
	check(drop.available and drop.item.uid == retained_id, "Announced airdrop lands and remains collectible after victory")
	player.position = Vector3(8, 0.05, 0)
	for frame: int in range(70):
		await physics_frame
		player.tick(1.0 / 60.0, Vector3.RIGHT)
	check(player.position.x > 12, "Player can walk to peripheral supplies after victory")
	check(scene.pickups.get_child_count() == 4, "Static supplies and uncollected airdrop survive victory")

	check(inventory.store(-1) and inventory.store(0), "Initial weapon and initial potion each occupy one chest slot")
	check(not inventory.store(1) and inventory.items[1] != null, "Third deposit is rejected without deleting the item")
	check(not player.has_weapon and not player.request_action(&"light"), "Stored weapon disables attacks and visible equipment")
	check(inventory.withdraw(0) and player.has_weapon, "Sword can be withdrawn to the weapon slot")
	check(inventory.store(-1), "Withdrawn sword can be deposited again")
	var snapshot := inventory.snapshot()
	check(scene.save_snapshot(), "Chest snapshot writes successfully")
	var items_before := inventory.carried_labels()
	var count_before: int = scene.pickups.get_child_count()
	session.request_finish()
	check(session.stage == RunSession.Stage.CONFIRM and scene.run_hud.modal.visible, "Finishing opens explicit discard confirmation")
	session.cancel_finish()
	check(session.stage == RunSession.Stage.LOOT and inventory.carried_labels() == items_before and scene.pickups.get_child_count() == count_before, "Cancel preserves carried and ground items")
	var remaining := session.revives
	check(scene.restore_snapshot(), "Saved chest snapshot restores successfully")
	check(inventory.snapshot() == snapshot and inventory.weapon == null and inventory.items == [null, null] and scene.pickups.get_child_count() == 0, "Snapshot roundtrip preserves exact IDs with no extra inventory or ground items")
	check(session.revives == remaining and session.elapsed == ended_time, "Snapshot restore does not refresh revives or clock")
	check(not inventory.restore_snapshot({"version":1,"items":[{"uid":"x","kind":"sword"},{"uid":"x","kind":"potion"}]}) and inventory.snapshot() == snapshot, "Duplicate snapshot IDs are rejected without mutating inventory")
	session.request_finish()
	scene.finish_run()
	check(session.stage == RunSession.Stage.RESULT and session.won, "Confirmed finish records victory exactly once")
	check(FileAccess.file_exists(scene.result_path), "Result report is persisted")
	scene.reset_training()
	await process_frame
	check(session.revives == 2 and session.elapsed == 0 and session.deaths == 0 and player.vitals.current == 100, "New run resets counters and player health")
	check(boss.vitals.current == 600 and scene.chest_node == null and scene.pickups.get_child_count() == 3 and inventory.chest.is_empty(), "New run has no old Boss damage, chest, airdrops or inherited hidden items")
	fresh()
	death(&"mutual_player")
	boss.vitals.take_damage(DamageData.new(&"mutual_boss", 1000))
	session.tick(0.016)
	check(session.won and session.stage == RunSession.Stage.LOOT and session.revives == 2, "Legal Boss death takes priority over pending same-step player death")
	fresh()
	session.time_limit = 0.5
	death(&"timeout_downed")
	session.tick(0.02)
	session.tick(0.5)
	check(session.stage == RunSession.Stage.RESULT and session.reason == "挑战超时" and session.revives == 1, "Time can expire during revival without resetting or granting another revive")
	session.time_limit = 180
	fresh()
	for attempt: int in range(5):
		session._drop_left = 0.0
		session.tick(0.016)
	check(session.drops == 3 and scene.pickups.get_child_count() == 6, "One run is limited to three airdrops")
	fresh()
	session.set_physics_process(true)
	scene.set_paused(true)
	ended_time = session.elapsed
	await create_timer(0.08, true).timeout
	check(session.elapsed == ended_time and not player.controls_enabled, "Pause freezes session clock and input")
	scene._restart_requested()
	await create_timer(0.05, true).timeout
	check(paused and session.elapsed == ended_time and scene.run_hud.modal.visible, "Restart confirmation keeps combat paused")
	scene.cancel_restart()
	check(not paused and session.stage == RunSession.Stage.BATTLE, "Cancelling restart returns to the same battle")
	scene.set_paused(false)
	session.set_physics_process(false)
	var report := {"passed": passed, "failed": failures.size(), "failures": failures, "engine": Engine.get_version_info().string}
	FileAccess.open("res://test_output/p0_3_results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("P0_3_TEST_RESULT ", JSON.stringify(report))
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
