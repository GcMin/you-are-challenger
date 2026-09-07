extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://training/training_ground.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i: int in range(15):
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://test_output")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/idle.png")
	print("CAPTURE_IDLE")
	scene.player.global_position = Vector3(0, 0.03, 2.1)
	scene.player.request_action(&"light")
	await create_timer(0.29).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/light.png")
	await create_timer(0.6).timeout
	scene.player.request_action(&"heavy")
	await create_timer(0.64).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/heavy.png")
	await create_timer(0.9).timeout
	scene.target.start_pulse()
	await create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/telegraph.png")
	scene.set_paused(true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/paused.png")
	scene.set_paused(false)
	scene.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene.target.reset_training()
	scene.target.visible = false
	scene.player.reset_training()
	scene.player.position = Vector3(0, 0.05, 4)
	scene.player.camera_yaw.rotation.y = PI
	scene.player.spring.spring_length = 3.0
	scene.player.camera_pitch.position.x = 0.0
	scene.player.camera_pitch.rotation.x = -0.12
	scene.hud.visible = false
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/grip.png")
	scene.player.request_action(&"roll", Vector3.RIGHT)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/roll.png")
	await create_timer(0.32).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/recover.png")
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test_output/recovered.png")
	print("CAPTURES_COMPLETE")
	quit()
