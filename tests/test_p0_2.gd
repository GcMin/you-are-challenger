extends SceneTree

var scene: Node3D
var boss: ArenaBoss
var player: ChallengerPlayer
var passed: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS ", description)
	else:
		failures.append(description)
		push_error("FAIL " + description)

func advance(frames: int, movement: Vector3 = Vector3.ZERO) -> void:
	for frame: int in range(frames):
		await physics_frame
		player.tick(1.0 / 60.0, movement)
		boss.tick(1.0 / 60.0)

func fresh(distance: float = 2.0) -> void:
	scene.reset_training()
	player.controls_enabled = false
	player.position = Vector3(0, 0.05, distance)
	boss.begin()

func run() -> void:
	scene = (load("res://boss/boss_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	boss = scene.boss
	player = scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.controls_enabled = false
	await physics_frame
	check(boss.state == ArenaBoss.State.WAIT, "Boss waits for explicit practice start")
	boss.vitals.take_damage(DamageData.new(&"opening_hit", 22))
	check(boss.engaged and boss.state == ArenaBoss.State.CHASE, "Attacking a waiting Boss also engages combat")
	check(not scene.camera_fixture, "Boss arena is flat and free of camera test obstacles")
	check(player.tuning.roll_recovery == 0.05, "Roll get-up is 0.05 seconds in Boss arena")
	boss.visual.play(&"boss_dash", 0.0, true)
	check(boss.visual.active_clip == &"boss_dash", "Imported two-handed dash clip available")

	fresh(12.0)
	await advance(20)
	check(boss.position.z > 1.0 and boss.state == ArenaBoss.State.CHASE, "Boss chases distant player")
	fresh(6.0)
	await advance(20)
	check(boss.move == ArenaBoss.Move.DASH and boss.state == ArenaBoss.State.WINDUP, "Mid-range selects gap-closing dash")
	var travel_origin := boss.position
	await advance(70)
	check(boss.position.distance_to(travel_origin) <= boss.tuning.dash_speed * boss.tuning.dash_active + 0.1, "Dash travel is bounded by speed and active duration")

	for attack: int in range(3):
		fresh()
		check(boss.start_attack(attack as ArenaBoss.Move), "Start move %d" % attack)
		var locked := boss.direction
		await advance(int(boss.tuning.windup(attack) * 60) - 2)
		check(player.vitals.current == 100, "No windup damage for move %d" % attack)
		player.position = Vector3(6, 0.05, -2)
		await advance(4)
		check(boss.direction.is_equal_approx(locked), "Direction does not snap to circling player for move %d" % attack)
		check(player.vitals.current == 100, "Sidestep avoids locked attack %d" % attack)
		check(not boss.start_attack(ArenaBoss.Move.SWEEP), "Busy Boss cannot restart move %d" % attack)
		fresh()
		boss.start_attack(attack as ArenaBoss.Move)
		await advance(ceili((boss.tuning.windup(attack) + boss.tuning.active(attack)) * 60) + 1)
		check(player.vitals.current == 100 - boss.tuning.damage(attack), "One hit only across active frames for move %d" % attack)
		check(boss.state == ArenaBoss.State.RECOVERY and not boss.marker.visible, "Move %d opens safe recovery with no marker" % attack)
		var hp := player.vitals.current
		await advance(12)
		check(player.vitals.current == hp, "Recovery causes no lingering damage for move %d" % attack)

	fresh()
	boss.start_attack(ArenaBoss.Move.SLAM)
	await advance(64)
	player.request_action(&"roll", Vector3.RIGHT)
	await advance(13)
	check(player.vitals.current == 100, "Timed roll avoids delayed slam")

	fresh(10.0)
	boss.rng.seed = 42
	var repeated := false
	var selected: Dictionary = {}
	for attempt: int in range(90):
		var attack := boss.choose_attack(2.2)
		repeated = repeated or (not boss.history.is_empty() and boss.history.back() == attack)
		selected[attack] = true
		boss.history.append(attack)
	check(not repeated and selected.size() == 3, "Selection covers all three moves without immediate repetitions")
	check(boss.tuning.sweep_recovery >= player.tuning.duration(false) and boss.tuning.sweep_recovery < player.tuning.duration(true), "Sweep recovery fits a light attack but not a full heavy")
	check(boss.tuning.slam_recovery > player.tuning.duration(true), "Slam recovery fits a full heavy attack")

	# Real player queries and stamina, no damage injection: punish successive locked slams.
	# Repositioning represents successful sidesteps; this proves equipment/damage feasibility,
	# not the difficulty or enjoyment of a complete human playthrough.
	fresh()
	var punish_hits: int = 0
	for turn: int in range(13):
		boss.state = ArenaBoss.State.CHASE
		player.position = Vector3(0, 0.05, 2.0)
		boss.start_attack(ArenaBoss.Move.SLAM)
		player.position = Vector3(4, 0.05, -1)
		await advance(86)
		player.position = Vector3(0, 0.05, 2.0)
		player.direction = Vector3.FORWARD
		var before := boss.vitals.current
		if player.request_action(&"heavy"):
			await advance(85)
			if boss.vitals.current < before:
				punish_hits += 1
		if boss.vitals.current <= 0:
			break
	check(punish_hits == 13 and boss.vitals.current == 0, "Thirteen paid basic heavy punishes defeat 600 HP Boss without items")
	check(player.vitals.current == 100, "Slam counterattacks complete safely inside recovery")
	check(boss.state == ArenaBoss.State.DEAD and not boss.engaged, "Boss death ends AI and attack volumes")
	await process_frame
	check(boss.hurtbox.collision_layer == 0, "Dead Boss hurtbox disabled")
	scene.reset_training()
	await process_frame
	check(boss.vitals.current == 600 and player.vitals.current == 100 and player.stamina == 100, "Retry restores both combatants and stamina")
	check(boss.hurtbox.collision_layer == 8, "Retry restores hurtbox after deferred death collision change")
	check(boss.history.is_empty() and boss.state == ArenaBoss.State.WAIT, "Retry clears selection history and waits for start")
	fresh()
	boss.start_attack(ArenaBoss.Move.SLAM)
	player.vitals.take_damage(DamageData.new(&"fatal_test", 100))
	await advance(90)
	check(boss.state == ArenaBoss.State.WAIT and not boss.marker.visible, "Player death cancels pending Boss damage")
	scene.reset_training()
	scene.set_paused(true)
	var position_before := boss.position
	await create_timer(0.05, true).timeout
	check(boss.position == position_before and not player.controls_enabled, "Pause freezes Boss and disables player input")
	scene.set_paused(false)
	var report := {"passed": passed, "failed": failures.size(), "failures": failures, "engine": Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://test_output")
	FileAccess.open("res://test_output/p0_2_results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("P0_2_TEST_RESULT ", JSON.stringify(report))
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
