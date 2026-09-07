extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := (load("res://boss/boss_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.player.controls_enabled = false
	scene.boss.set_physics_process(false)
	scene.player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(0.2).timeout
	await capture("boss_ready")
	for attack: int in range(3):
		scene.reset_training()
		scene.player.controls_enabled = false
		scene.player.position = Vector3(0, 0.05, 4.5)
		scene.player.camera_pitch.rotation.x = -0.4
		scene.boss.begin()
		scene.boss.start_attack(attack as ArenaBoss.Move)
		scene.hud.show_notice("观察起手 · 绕侧躲横扫，别被重砸骗滚")
		scene.boss.tick(scene.boss.tuning.windup(attack) * 0.85)
		await capture("boss_windup_%d" % attack)
		scene.boss.tick(scene.boss.tuning.windup(attack) * 0.15 + scene.boss.tuning.active(attack) + 0.1)
		await capture("boss_recovery_%d" % attack)
	print("BOSS_CAPTURES_COMPLETE")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/%s.png" % filename)
