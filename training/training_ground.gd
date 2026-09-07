extends "res://training/flat_arena.gd"

const PLAYER: PackedScene = preload("res://player/player.tscn")
var player: ChallengerPlayer
var target: TrainingTarget
var hud: TrainingHud
var sounds: FeedbackAudio

func _ready() -> void:
	_build_ground()
	player = PLAYER.instantiate() as ChallengerPlayer
	add_child(player)
	player.position = Vector3(0, 0.05, 3.5)
	target = TrainingTarget.new()
	target.name = "TrainingTarget"
	add_child(target)
	target.player = player
	player.aim_target = target
	hud = TrainingHud.new()
	add_child(hud)
	sounds = FeedbackAudio.new()
	add_child(sounds)
	player.vitals.changed.connect(hud.show_health)
	player.status_changed.connect(hud.show_status)
	player.feedback.connect(hud.show_notice)
	player.vitals.damaged.connect(func(data: DamageData) -> void:
		hud.damage_feedback(data, player.camera_yaw.global_basis, player.global_position)
		sounds.play(&"hurt")
	)
	player.attacked.connect(func(_heavy: bool) -> void: sounds.play(&"swing"))
	target.vitals.changed.connect(hud.show_target)
	target.telegraph_changed.connect(hud.show_telegraph)
	target.feedback.connect(hud.show_notice)
	target.struck.connect(func() -> void: sounds.play(&"hit"))
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.restart_requested.connect(reset_training)
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("P0_1_READY")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		get_tree().change_scene_to_file("res://boss/boss_arena.tscn")
	if event.is_action_pressed("reset_training"):
		reset_training()
	elif event.is_action_pressed("auto_attack"):
		target.automatic = not target.automatic
		hud.show_notice("循环攻击已开启 · 注意橙色预警" if target.automatic else "循环攻击已关闭")
	elif event.is_action_pressed("single_attack"):
		target.start_pulse()
	elif event.is_action_pressed("debug_hitbox"):
		player.debug_enabled = not player.debug_enabled
		hud.show_notice("命中体积显示已开启" if player.debug_enabled else "命中体积显示已关闭")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		set_paused(true)

func set_paused(value: bool) -> void:
	get_tree().paused = value
	hud.show_paused(value)
	player.controls_enabled = not value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	# Keep this coordinator responsive to Escape while physics and animations are paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	target.process_mode = Node.PROCESS_MODE_PAUSABLE
	sounds.process_mode = Node.PROCESS_MODE_PAUSABLE

func reset_training() -> void:
	player.reset_training()
	target.reset_training()
	set_paused(false)
	hud.show_notice("训练已重置 · 生命与精力恢复")
