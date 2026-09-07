extends SceneTree

var scene: Node3D
var player: ChallengerPlayer
var target: TrainingTarget
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
	for i: int in range(frames):
		await physics_frame
		player.tick(1.0 / 60.0, movement)
		target.vitals.tick(1.0 / 60.0)

func fresh(distance: float = 2.1) -> void:
	player.reset_training()
	target.reset_training()
	player.position = Vector3(0.0, 0.05, distance)

func run() -> void:
	scene = (load("res://training/training_ground.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	player = scene.player
	target = scene.target
	player.set_physics_process(false)
	target.set_physics_process(false)
	player.controls_enabled = false
	await physics_frame
	check(player.visual.animation != null, "Imported model has AnimationPlayer")
	for clip: StringName in [&"idle", &"run", &"light", &"heavy", &"roll", &"recover", &"hit", &"death"]:
		player.visual.play(clip)
		check(player.visual.active_clip == clip, "UAL clip available: " + str(clip))

	fresh()
	check(player.request_action(&"light"), "Light attack starts")
	check(is_equal_approx(player.stamina, 90.0), "Light attack pays 10 stamina once")
	await advance(16)
	check(is_equal_approx(target.vitals.current, 578.0), "Light deals exactly 22 across overlapping hurtboxes")
	var normalized_pose: float = player.visual.animation.current_animation_position / player.visual.animation.current_animation_length
	check(absf(normalized_pose - player.state_time / player.tuning.duration(false)) < 0.001, "Hit feedback does not desynchronize attack pose and damage clock")
	await advance(12)
	check(is_equal_approx(target.vitals.current, 578.0), "Active frames cannot redamage same target")
	check(not player.request_action(&"heavy"), "Recovery blocks a new attack")
	check(not player.request_action(&"roll"), "Recovery blocks roll cancel")
	await advance(20)
	check(player.state == ChallengerPlayer.State.MOVE, "Light returns to locomotion")

	fresh()
	check(player.request_action(&"heavy"), "Heavy starts with sufficient stamina")
	check(is_equal_approx(player.stamina, 80.0), "Heavy pays 20 once")
	await advance(30)
	check(is_equal_approx(target.vitals.current, 600.0), "Heavy windup deals no damage")
	await advance(18)
	check(is_equal_approx(target.vitals.current, 552.0), "Heavy deals 48 once")
	check(not player.request_action(&"roll"), "Heavy active/recovery cannot be cancelled")
	await advance(38)
	check(player.state == ChallengerPlayer.State.MOVE, "Heavy completes after 1.38 seconds")

	fresh()
	player.request_action(&"heavy")
	await advance(3)
	check(player.request_action(&"roll", Vector3.RIGHT), "Early windup permits paid dodge cancel")
	check(is_equal_approx(player.stamina, 55.0), "Cancel preserves heavy cost and charges roll")
	await advance(40)
	check(is_equal_approx(target.vitals.current, 600.0), "Cancelled attack cannot later damage")

	fresh()
	player.request_action(&"roll")
	await advance(3)
	check(not player.vitals.dodge_invulnerable, "Roll startup before 0.08s is vulnerable")
	check(player.vitals.take_damage(DamageData.new(&"roll_early", 18.0)), "Early roll takes damage")
	check(player.state == ChallengerPlayer.State.HIT, "Early hit interrupts rolling")
	fresh()
	player.request_action(&"roll")
	await advance(8)
	check(player.vitals.dodge_invulnerable, "Roll is invulnerable at 0.133s")
	check(not player.vitals.take_damage(DamageData.new(&"roll_correct", 18.0)), "Correct roll avoids attack")
	check(is_equal_approx(player.vitals.current, 100.0), "Correct roll keeps HP")
	await advance(12)
	check(not player.vitals.dodge_invulnerable, "Roll after 0.28s is vulnerable")
	check(not player.vitals.take_damage(DamageData.new(&"roll_correct", 18.0)), "Evaded attack ID cannot hit after i-frames")
	check(player.vitals.take_damage(DamageData.new(&"roll_late", 18.0)), "Different late attack damages rolling player")

	fresh(8.0)
	for roll: int in range(4):
		check(player.request_action(&"roll", Vector3.RIGHT if roll % 2 == 0 else Vector3.LEFT), "Paid roll %d" % (roll + 1))
		await advance(50)
	check(player.stamina < player.tuning.roll_cost, "Four rolls leave insufficient stamina for a fifth, including recovery regeneration")
	check(not player.request_action(&"roll"), "Fifth roll cannot run for free")
	check(player.stamina >= 0.0, "Stamina never becomes negative")
	var before: Vector3 = player.position
	await advance(8, Vector3.RIGHT)
	check(player.position.x > before.x, "Exhausted player can still move")
	player.stamina = 0.0
	check(not player.request_action(&"light"), "Exhausted player cannot attack for free")
	await advance(60)
	check(player.stamina > 0.0, "Stamina recovers while moving or resting after delay")
	check(player.request_action(&"light"), "Light attack is available after stamina recovers")

	fresh()
	player.request_action(&"light")
	for i: int in range(40):
		player.queue_action(&"heavy" if i % 2 == 0 else &"light")
		await advance(1)
	await advance(20)
	check(target.vitals.current == 578.0 and player.state == ChallengerPlayer.State.MOVE, "Busy click spam does not queue extra attacks after recovery")
	# Explicitly simulate a lingering same-name clip; a new action must restart it.
	player.visual.play(&"light", 0.75, true)
	player.visual.tick(0.0, 0.8)
	check(player.request_action(&"light"), "Second light attack starts after completed recovery")
	check(player.visual.animation.current_animation_position < 0.001, "Same attack clip always restarts at frame zero")
	await advance(18)
	normalized_pose = player.visual.animation.current_animation_position / player.visual.animation.current_animation_length
	check(absf(normalized_pose - player.state_time / player.tuning.duration(false)) < 0.001, "Repeated attack animation stays on combat timeline")

	fresh(8.0)
	player.request_action(&"roll")
	await advance(34)
	check(player.state == ChallengerPlayer.State.ROLL_RECOVER, "Roll transitions into explicit get-up phase")
	check(player.visual.active_clip == &"recover", "Get-up animation plays after roll")
	check(not player.vitals.dodge_invulnerable, "Get-up adds no extra invulnerability")
	check(not player.request_action(&"light") and not player.request_action(&"roll"), "Get-up must finish before attacking or rolling")
	var recovery_start: Vector3 = player.position
	check(is_equal_approx(player.tuning.roll_recovery, 0.05), "Get-up tuning is exactly 0.05 seconds")
	await advance(1)
	check(player.state == ChallengerPlayer.State.ROLL_RECOVER, "Get-up remains locked before 0.05 seconds")
	await advance(3)
	check(player.position.distance_to(recovery_start) < 0.02, "Get-up does not slide forward")
	check(player.state == ChallengerPlayer.State.MOVE, "Get-up returns to locomotion")

	fresh()
	player.request_action(&"heavy")
	await advance(5)
	player.vitals.take_damage(DamageData.new(&"interrupt", 18.0))
	await advance(85)
	check(is_equal_approx(target.vitals.current, 600.0), "Hitstun cancels pending damage")
	fresh()
	player.request_action(&"light")
	player.vitals.take_damage(DamageData.new(&"fatal", 100.0))
	await advance(50)
	check(player.state == ChallengerPlayer.State.DEAD, "Lethal damage enters dead state")
	check(not player.request_action(&"light") and not player.request_action(&"roll"), "Dead player cannot attack or roll")
	check(is_equal_approx(target.vitals.current, 600.0), "Death cancels attack hitbox")
	check(player.hurtbox.collision_layer == 0, "Dead hurtbox is disabled")

	fresh(5.0)
	player.request_action(&"light")
	await advance(50)
	check(is_equal_approx(target.vitals.current, 600.0), "Out-of-range attacks miss")
	fresh()
	player.aim_target = null
	player.direction = Vector3.BACK
	player.request_action(&"light")
	await advance(50)
	check(is_equal_approx(target.vitals.current, 600.0), "Attacks behind player miss")
	player.aim_target = target
	fresh()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	col.shape = box
	wall.add_child(col)
	scene.add_child(wall)
	wall.position = Vector3(0, 1.5, 1.0)
	await physics_frame
	player.request_action(&"light")
	await advance(50)
	check(is_equal_approx(target.vitals.current, 600.0), "World geometry blocks melee damage")
	wall.queue_free()
	await physics_frame

	fresh(8.0)
	var start: Vector3 = player.position
	await advance(60, Vector3.RIGHT)
	var straight: float = player.position.distance_to(start)
	fresh(8.0)
	start = player.position
	await advance(60, Vector3(1, 0, 1))
	var diagonal: float = player.position.distance_to(start)
	check(absf(straight - diagonal) < 0.2, "Diagonal movement is normalized")
	fresh(8.0)
	player.position.x = 15.0
	player.request_action(&"roll", Vector3.RIGHT)
	await advance(34)
	check(player.position.x < 16.0, "Roll cannot pass arena boundary")

	fresh()
	player.set_physics_process(true)
	scene.set_paused(true)
	var paused_time: float = player.state_time
	for i: int in range(10):
		await process_frame
	check(is_equal_approx(paused_time, player.state_time), "Pause freezes gameplay state")
	scene.reset_training()
	player.set_physics_process(false)
	check(player.vitals.current == 100.0 and player.stamina == 100.0 and target.vitals.current == 600.0, "Reset restores independent training state")
	check(not paused, "Reset exits pause")
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.camera_yaw.rotation.y = 0.0
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200.0, 10000.0)
	player._unhandled_input(motion)
	check(is_equal_approx(player.camera_yaw.rotation.y, -0.5), "Mouse input rotates camera yaw")
	check(is_equal_approx(player.camera_pitch.rotation.x, -0.9), "Camera pitch clamps at lower limit")
	motion.relative = Vector2(0.0, -20000.0)
	player._unhandled_input(motion)
	check(is_equal_approx(player.camera_pitch.rotation.x, 0.25), "Camera pitch clamps at upper limit")
	player.camera_pitch.rotation.x = -0.3
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await advance(1)
	check(player.state == ChallengerPlayer.State.LIGHT, "Real left mouse event starts mapped light attack")
	click.pressed = false
	Input.parse_input_event(click)
	await advance(50)
	Input.action_press("move_forward")
	player.camera_yaw.rotation.y = PI / 2.0
	player.set_physics_process(true)
	var input_start: Vector3 = player.position
	for i: int in range(20):
		await physics_frame
	Input.action_release("move_forward")
	player.set_physics_process(false)
	check(player.position.x < input_start.x - 0.5, "W follows horizontal camera direction")
	fresh()
	# Put the camera boom through the existing fixture at z=-5.
	player.position = Vector3(7.0, 0.05, -3.0)
	player.camera_yaw.rotation.y = PI
	player.camera_pitch.rotation.x = -0.1
	for i: int in range(8):
		await physics_frame
	check(player.spring.get_hit_length() < 3.0, "SpringArm retracts in front of obstruction")
	check(player.spring.get_hit_length() > 0.2, "Camera keeps a usable distance at wall")

	# Shutdown while the rendering backend is still alive; no leaked scene objects.

	var report := {"passed": passed, "failed": failures.size(), "failures": failures, "engine": Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://test_output")
	var file := FileAccess.open("res://test_output/p0_1_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("P0_1_TEST_RESULT ", JSON.stringify(report))
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
