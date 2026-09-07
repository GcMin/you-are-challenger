extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := (load("res://boss/boss_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var boss: ArenaBoss = scene.boss
	var player: ChallengerPlayer = scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.controls_enabled = false
	player.hurtbox.collision_layer = 0
	boss.begin()
	var max_boss_y: float = 0.0
	var max_player_y: float = 0.0
	# Reproduce the reported elevated state and verify correction during an attack.
	boss.position.y = 1.8
	boss.start_attack(ArenaBoss.Move.SLAM)
	await physics_frame
	boss.tick(1.0 / 60.0)
	var recovered: bool = boss.position.y < 0.1
	for frame: int in range(3600):
		await physics_frame
		if frame % 180 == 0:
			boss.reset_training()
			boss.begin()
			player.position = Vector3(0, 0.05, 4.5)
			boss.start_attack(ArenaBoss.Move.DASH)
		if frame % 180 == 39:
			player.request_action(&"roll", Vector3.FORWARD)
		var toward := boss.position - player.position
		toward.y = 0.0
		player.tick(1.0 / 60.0, toward.normalized())
		boss.tick(1.0 / 60.0)
		max_boss_y = maxf(max_boss_y, boss.position.y)
		max_player_y = maxf(max_player_y, player.position.y)
	var report := {"boss_max_y": max_boss_y, "player_max_y": max_player_y, "elevated_attack_recovers": recovered, "seconds": 60, "passed": recovered and max_boss_y < 0.1 and max_player_y < 0.1}
	print("GROUNDING_RESULT ", JSON.stringify(report))
	FileAccess.open("res://test_output/grounding_results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	scene.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
