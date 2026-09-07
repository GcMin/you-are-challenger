extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := (load("res://run/run_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.2).timeout
	await capture("run_prepare")
	scene.start_run()
	scene.player.controls_enabled = false
	await create_timer(0.6).timeout
	await capture("run_battle")
	scene.boss.vitals.take_damage(DamageData.new(&"capture_victory", 1000))
	scene.player.position = Vector3(0, 0.05, 2.0)
	await create_timer(0.3).timeout
	await capture("run_loot")
	scene.open_chest()
	await capture("run_chest")
	scene.session.inventory.store(-1)
	scene.session.inventory.store(0)
	scene.session.request_finish()
	await capture("run_confirm")
	scene.session.cancel_finish()
	print("RUN_CAPTURES_COMPLETE")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/%s.png" % name)
