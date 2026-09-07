extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var full_run: bool = "--full-run" in OS.get_cmdline_user_args()
	var scene := (load("res://run/run_arena.tscn" if full_run else "res://boss/boss_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var boss: ArenaBoss = scene.boss
	var player: ChallengerPlayer = scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.controls_enabled = false
	if full_run:
		scene.session.set_physics_process(false)
	var reports: Array[Dictionary] = []
	for seed_value: int in ([7] if full_run else [7, 42, 123]):
		scene.reset_training()
		player.controls_enabled = false
		boss.rng.seed = seed_value
		if full_run:
			scene.start_run()
			scene.player.controls_enabled = false
		else:
			boss.begin()
		var frames: int = 0
		var attacks: int = 0
		while frames < 18000 and (player.vitals.current > 0 or full_run) and boss.vitals.current > 0:
			await physics_frame
			var movement := Vector3.ZERO
			var offset := boss.global_position - player.global_position
			offset.y = 0.0
			if boss.state in [ArenaBoss.State.WINDUP, ArenaBoss.State.ACTIVE]:
				var side := boss.direction.cross(Vector3.UP)
				var local := player.global_position - boss.attack_origin
				if local.dot(side) < 0:
					side = -side
				var destination := boss.attack_origin + side * (boss.attack_size().x * 0.5 + 0.65) + boss.direction * 1.2
				var to_safe := destination - player.global_position
				to_safe.y = 0.0
				if to_safe.length() > 0.08:
					movement = to_safe.normalized() * minf(1.0, to_safe.length() / 0.15)
			elif boss.state == ArenaBoss.State.RECOVERY:
				if offset.length() > 2.05:
					movement = offset.normalized()
				elif player.state == ChallengerPlayer.State.MOVE:
					var heavy: bool = boss.move == ArenaBoss.Move.SLAM
					if boss.tuning.recovery(boss.move) - boss.elapsed > player.tuning.duration(heavy) + 0.02:
						player.direction = offset.normalized()
						if player.request_action(&"heavy" if heavy else &"light"):
							attacks += 1
			elif offset.length() > 3.0:
				movement = offset.normalized()
			player.tick(1.0 / 60.0, movement)
			boss.tick(1.0 / 60.0)
			if full_run:
				scene.session.tick(1.0 / 60.0)
				if scene.session.stage == RunSession.Stage.RESULT:
					break
			frames += 1
		var report := {"seed": seed_value, "victory": boss.vitals.current <= 0, "seconds": frames / 60.0, "player_hp": player.vitals.current, "boss_hp": boss.vitals.current, "paid_attacks": attacks}
		if full_run:
			report["run_revives_used"] = 2 - scene.session.revives
			report["run_stage"] = scene.session.stage
		reports.append(report)
		print("PLAYTHROUGH ", JSON.stringify(report))
	# Feasibility requires a complete unassisted win, not a perfect win rate for this bot.
	var success: bool = reports.any(func(entry: Dictionary) -> bool: return entry.victory)
	FileAccess.open("res://test_output/run_playthrough.json" if full_run else "res://test_output/boss_playthrough.json", FileAccess.WRITE).store_string(JSON.stringify(reports, "\t"))
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if success else 1)
