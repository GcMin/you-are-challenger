extends "res://training/flat_arena.gd"

const PLAYER: PackedScene = preload("res://player/player.tscn")
var player: ChallengerPlayer
var boss: ArenaBoss
var hud: TrainingHud
var sounds: FeedbackAudio
var _shake_left: float = 0.0

func _ready() -> void:
	_build_ground()
	player = PLAYER.instantiate() as ChallengerPlayer
	add_child(player)
	player.position = Vector3(0, 0.05, 5.5)
	boss = ArenaBoss.new()
	boss.name = "IronWarden"
	add_child(boss)
	boss.player = player
	player.aim_target = boss
	hud = _make_hud()
	hud.boss_mode = true
	add_child(hud)
	sounds = FeedbackAudio.new()
	add_child(sounds)
	player.vitals.changed.connect(hud.show_health)
	player.status_changed.connect(hud.show_status)
	player.feedback.connect(hud.show_notice)
	player.vitals.damaged.connect(func(data: DamageData) -> void:
		hud.damage_feedback(data, player.camera_yaw.global_basis, player.global_position)
		sounds.play(&"hurt")
		_shake_left = 0.15
	)
	player.attacked.connect(func(_heavy: bool) -> void: sounds.play(&"swing"))
	boss.vitals.changed.connect(hud.show_target)
	boss.telegraph_changed.connect(hud.show_telegraph)
	boss.feedback.connect(hud.show_notice)
	boss.struck.connect(func() -> void: sounds.play(&"hit"))
	boss.impact.connect(func(move: int) -> void:
		sounds.play(&"hurt" if move == ArenaBoss.Move.SLAM else &"swing")
		if move == ArenaBoss.Move.SLAM and player.global_position.distance_to(boss.global_position) < 6.0:
			_shake_left = 0.12
	)
	boss.vitals.died.connect(_on_boss_died)
	player.vitals.died.connect(_on_player_died)
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.restart_requested.connect(_restart_requested)
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("P0_2_READY")

func _make_hud() -> TrainingHud:
	return TrainingHud.new()

func _on_player_died() -> void:
	hud.show_notice("挑战失败 · R 重试，观察预警再翻滚")

func _on_boss_died() -> void:
	hud.show_notice("挑战成功 · 击倒铁卫 · R 再次挑战")

func _restart_requested() -> void:
	reset_training()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER:
			boss.begin()
			hud.show_notice("观察起手 · 绕侧躲横扫，别被重砸骗滚")
		elif event.physical_keycode == KEY_F2:
			get_tree().change_scene_to_file("res://training/training_ground.tscn")
	if event.is_action_pressed("reset_training"):
		reset_training()
	elif event.is_action_pressed("debug_hitbox"):
		player.debug_enabled = not player.debug_enabled

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	player.camera.h_offset = sin(_shake_left * 170.0) * _shake_left * 0.22
	player.camera.v_offset = sin(_shake_left * 130.0) * _shake_left * 0.12
	if boss.state == ArenaBoss.State.DEAD:
		hud.default_notice = "挑战成功 · 击倒铁卫 · R 再次挑战"
	elif player.vitals.current <= 0.0:
		hud.default_notice = "挑战失败 · R 重试，观察预警再翻滚"
	elif not boss.engaged:
		hud.default_notice = "Enter 开始 · 横扫抢轻击，重砸抓重击"
	else:
		hud.default_notice = "观察起手  ·  保留精力  ·  抓住收招"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		set_paused(true)

func set_paused(value: bool) -> void:
	get_tree().paused = value
	hud.show_paused(value)
	player.controls_enabled = not value
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	sounds.process_mode = Node.PROCESS_MODE_PAUSABLE

func reset_training() -> void:
	player.reset_training()
	player.position.z = 5.5
	boss.reset_training()
	_shake_left = 0.0
	set_paused(false)
	hud.show_notice("对练已重置 · Enter 开始")
