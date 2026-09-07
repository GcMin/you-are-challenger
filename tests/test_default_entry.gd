extends Node
## Run the real project entry, without --script or a replacement main scene:
## godot --path . -- --qa-default-entry
## This observer is attached after normal scene setup; it never ticks actors manually.

var passed: int = 0
var failures: Array[String] = []
var minimum_height: float = INF
var arena: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = get_parent()
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
		minimum_height = minf(minimum_height, arena.player.global_position.y)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test_output/" + filename + ".png")

func _run() -> void:
	arena.result_path = "res://test_output/default_entry_result.json"
	await frames(120)
	check(get_tree().current_scene == arena and arena.scene_file_path == ProjectSettings.get_setting("application/run/main_scene"), "Observer runs the configured default entry")
	check(not get_tree().paused, "Default entry is running")
	check(minimum_height >= -0.01 and arena.player.is_on_floor(), "Player stays above the floor throughout native startup physics")
	check(arena.boss.global_position.distance_to(Vector3.ZERO) < 0.05, "Idle Boss stays at its separate central spawn")
	check(arena.player.camera.global_position.y > 2.0 and arena.player.camera.is_current(), "Active camera remains above the arena")
	var camera: Camera3D = arena.player.camera
	var boss_center: Vector3 = arena.boss.global_position + Vector3.UP
	check(not camera.is_position_behind(boss_center) and get_viewport().get_visible_rect().has_point(camera.unproject_position(boss_center)), "Boss is in the default camera frustum")
	await capture("default_entry_prepare")
	arena.start_run()
	await frames(90)
	check(arena.session.stage == RunSession.Stage.BATTLE and arena.session.elapsed > 1.0 and arena.boss.engaged, "Native default-entry battle clock and AI advance")
	check(minimum_height >= -0.01, "Starting battle does not push the player underground")
	await capture("default_entry_battle")
	arena.set_paused(true)
	var elapsed: float = arena.session.elapsed
	await frames(10)
	check(arena.session.elapsed == elapsed, "Default-entry pause freezes the battle")
	arena.set_paused(false)
	await frames(10)
	check(arena.session.elapsed > elapsed, "Default-entry resume continues the battle")
	arena.reset_training()
	await frames(60)
	check(arena.session.stage == RunSession.Stage.PREPARE and arena.player.is_on_floor() and arena.boss.position.distance_to(Vector3.ZERO) < 0.05, "Restart restores separated grounded actors")
	print("DEFAULT_ENTRY_RESULT passed=", passed, " failed=", failures.size(), " minimum_player_y=", minimum_height)
	get_tree().quit(0 if failures.is_empty() else 1)
