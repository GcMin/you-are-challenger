extends "res://boss/boss_arena.gd"

var session: RunSession
var run_hud: RunHud
var pickups: Node3D
var chest_node: Node3D
var cage: Node3D
var cage_bodies: Array[StaticBody3D] = []
var safe_points: Array[Marker3D] = []
var chest_open: bool = false
var _restart_confirm: bool = false
var snapshot_path: String = "user://p0_chest_snapshot.json"
var result_path: String = "user://p0_last_result.json"

func _make_hud() -> TrainingHud:
	return RunHud.new()

func _ready() -> void:
	super._ready()
	run_hud = hud as RunHud
	pickups = Node3D.new()
	pickups.name = "GroundItems"
	add_child(pickups)
	_build_cage()
	for spot: Vector3 in [Vector3(-7, 0.05, -7), Vector3(7, 0.05, -7), Vector3(-7, 0.05, 7), Vector3(7, 0.05, 7)]:
		var point := Marker3D.new()
		point.position = spot
		add_child(point)
		safe_points.append(point)
	session = RunSession.new()
	add_child(session)
	session.stage_changed.connect(_on_stage)
	session.ai_requested.connect(_set_ai)
	session.revive_requested.connect(_revive)
	session.airdrop_requested.connect(_airdrop)
	session.victory.connect(_victory)
	session.result_ready.connect(_record_result)
	session.inventory.changed.connect(_inventory_changed)
	player.vitals.died.connect(session.player_died)
	player.vitals.damaged.connect(func(_data: DamageData) -> void: session.received_hits += 1)
	boss.vitals.died.connect(session.boss_died)
	reset_training()
	print("P0_3_READY")
	if "--qa-default-entry" in OS.get_cmdline_user_args():
		add_child(load("res://tests/test_default_entry.gd").new())

func _on_player_died() -> void:
	# RunSession resolves revival or defeat next tick (same-step Boss kill wins).
	hud.show_notice("角色倒地 · 正在结算")

func _on_boss_died() -> void:
	# Victory and looting feedback belong to RunSession, not the practice arena.
	pass

func _input(event: InputEvent) -> void:
	if not is_instance_valid(session):
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		if _restart_confirm:
			cancel_restart()
			get_viewport().set_input_as_handled()
			return
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ENTER:
			if session.stage == RunSession.Stage.PREPARE:
				start_run()
			elif session.stage == RunSession.Stage.LOOT:
				session.request_finish()
		KEY_R:
			if session.stage in [RunSession.Stage.PREPARE, RunSession.Stage.RESULT]:
				reset_training()
		KEY_E:
			if not run_hud.modal.visible:
				interact()
		KEY_1, KEY_2:
			if not run_hud.modal.visible:
				var slot: int = 0 if event.physical_keycode == KEY_1 else 1
				if event.shift_pressed:
					pickup_nearest(slot)
				else:
					use_item(slot)
		KEY_F1:
			player.debug_enabled = not player.debug_enabled
		KEY_F9:
			if session.stage == RunSession.Stage.LOOT:
				save_snapshot()
		KEY_F10:
			if session.stage == RunSession.Stage.LOOT or (session.stage == RunSession.Stage.RESULT and session.won):
				show_restore_confirmation()

func _process(delta: float) -> void:
	if not is_instance_valid(session):
		return
	super._process(delta)
	if get_tree().paused:
		return
	run_hud.show_run(session)
	match session.stage:
		RunSession.Stage.PREPARE:
			hud.default_notice = "准备装备 · Enter 开始 180 秒挑战"
			hud.show_telegraph("准备完成后开始", 0.0)
		RunSession.Stage.BATTLE:
			hud.default_notice = "观察起手 · 保留精力 · 1 / 2 使用道具"
			if not boss.engaged:
				hud.show_telegraph("安全缓冲 · 即将出招", 0.0)
		RunSession.Stage.DOWNED:
			hud.default_notice = "正在复起 · 时钟继续 · 剩余复活 %d" % session.revives
			hud.show_telegraph("Boss 停手 · 保留残余生命", 0.0)
		RunSession.Stage.LOOT:
			hud.default_notice = "胜利 · 可离开擂台自由搜刮 · 中央 E 装箱 · Enter 结束"
			hud.show_telegraph("Boss 已击倒 · 自由搜刮", 0.0)
		RunSession.Stage.CONFIRM:
			hud.show_telegraph("Boss 已击倒 · 装箱确认", 0.0)
		RunSession.Stage.RESULT:
			hud.default_notice = session.reason + " · R 开始新一轮"
			hud.show_telegraph(session.reason, 0.0)
	var nearest := nearest_pickup()
	if chest_node and player.global_position.distance_to(chest_node.global_position) < 2.5 and session.stage == RunSession.Stage.LOOT:
		run_hud.interaction_text.text = "E  打开继承箱 · 两格"
	elif nearest:
		run_hud.interaction_text.text = "E  拾取 " + nearest.item.label()
	else:
		run_hud.interaction_text.text = ""

func start_run() -> void:
	if session.stage != RunSession.Stage.PREPARE:
		return
	player.reset_training()
	player.position = Vector3(0, 0.05, 5.5)
	_inventory_changed()
	session.start()
	hud.show_notice("挑战开始 · 180 秒 · 本轮共两次复活")

func _on_stage() -> void:
	var fighting: bool = session.stage in [RunSession.Stage.BATTLE, RunSession.Stage.DOWNED]
	player.vitals.damage_enabled = fighting
	boss.vitals.damage_enabled = fighting
	set_cage_locked(fighting)
	chest_open = false
	run_hud.close_menu()
	match session.stage:
		RunSession.Stage.PREPARE:
			run_hud.open_menu("单人挑战", "180 秒击败铁卫，本轮有两次复活。初始携带大剑、恢复药与精力饮料。胜利后可无限时搜刮并整理两格继承箱。")
			run_hud.action("开始挑战", start_run)
			run_hud.action("先自由准备", close_menu)
		RunSession.Stage.DOWNED:
			hud.show_notice("倒地 · 即将自动复活 · 此次复活后剩余 %d 次" % session.revives)
		RunSession.Stage.CONFIRM:
			run_hud.open_menu("确认结束本轮", "仅箱内 %d 件物品保存为测试快照。\n未装箱随身物品：%s\n地面还有 %d 件，也会舍弃。可取消继续整理。" % [session.inventory.chest.size(), session.inventory.carried_labels(), pickups.get_child_count()])
			run_hud.action("保存箱内物品并结束", finish_run)
			run_hud.action("取消，继续搜刮", session.cancel_finish)
		RunSession.Stage.RESULT:
			hud.show_notice(("挑战成功" if session.won else "挑战失败 · " + session.reason) + " · R 开始新一轮")
			run_hud.open_menu("挑战成功" if session.won else session.reason, "战斗 %.1f 秒 · 倒地 %d 次\n受击 %d 次 · 使用复活 %d / 2\n%s" % [session.elapsed, session.deaths, session.received_hits, 2 - session.revives, "箱内快照已保存。F10 可验证还原，不会刷新本轮复活。" if session.won else "本轮未生成胜利箱。"])
			run_hud.action("开始新一轮", reset_training)
	_sync_controls()

func _sync_controls() -> void:
	var controllable: bool = not get_tree().paused and not run_hud.modal.visible and session.stage in [RunSession.Stage.PREPARE, RunSession.Stage.BATTLE, RunSession.Stage.LOOT]
	player.controls_enabled = controllable
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if controllable else Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	chest_open = false
	run_hud.close_menu()
	_sync_controls()

func _restart_requested() -> void:
	set_paused(false)
	_restart_confirm = true
	get_tree().paused = true
	run_hud.open_menu("重新开始本轮？", "当前战斗进度、随身物品和地面物资将清除，未保存的箱内物品也会丢失。已保存的测试快照不受影响。")
	run_hud.action("确认重开", reset_training)
	run_hud.action("取消，返回当前挑战", cancel_restart)
	_sync_controls()

func cancel_restart() -> void:
	_restart_confirm = false
	set_paused(false)
	_on_stage()

func set_paused(value: bool) -> void:
	super.set_paused(value)
	if is_instance_valid(session):
		session.process_mode = Node.PROCESS_MODE_PAUSABLE
		pickups.process_mode = Node.PROCESS_MODE_PAUSABLE
		_sync_controls()

func _set_ai(enabled: bool) -> void:
	boss.ai_enabled = enabled
	if enabled:
		boss.begin()
	else:
		boss.engaged = false
		boss.velocity = Vector3.ZERO
		if boss.state != ArenaBoss.State.DEAD:
			boss._enter(ArenaBoss.State.WAIT)

func _revive() -> void:
	var point := safe_points[0]
	for candidate: Marker3D in safe_points:
		if candidate.global_position.distance_squared_to(boss.global_position) > point.global_position.distance_squared_to(boss.global_position):
			point = candidate
	player.revive_at(point.global_position)
	_inventory_changed()
	hud.show_notice("复起 · 50 生命 / 满精力 · 保护 2 秒，主动攻击会结束保护")

func _victory() -> void:
	if player.vitals.current <= 0.0:
		player.revive_at(safe_points[0].global_position)
	_spawn_chest()
	hud.show_notice("击败铁卫 · 禁出已解除 · 中央出现继承箱")

func _inventory_changed() -> void:
	run_hud.show_inventory(session.inventory)
	player.equip_weapon(session.inventory.weapon != null)
	if chest_open:
		open_chest()

func use_item(slot: int) -> bool:
	if session.stage not in [RunSession.Stage.PREPARE, RunSession.Stage.BATTLE, RunSession.Stage.LOOT] or player.state != ChallengerPlayer.State.MOVE or slot not in [0, 1]:
		return false
	var item := session.inventory.items[slot]
	if item == null:
		hud.show_notice("该道具栏为空")
		return false
	var restored: float = 0.0
	if item.kind == &"potion":
		restored = player.vitals.heal(30.0)
	elif item.kind == &"drink":
		var before := player.stamina
		player.stamina = minf(player.tuning.stamina_max, player.stamina + 50.0)
		restored = player.stamina - before
	if restored <= 0.0:
		hud.show_notice("当前已满，保留道具")
		return false
	session.inventory.items[slot] = null
	session.inventory.changed.emit()
	hud.show_notice("%s · 恢复 %d · 已消耗" % [item.label(), int(restored)])
	return true

func nearest_pickup() -> WorldPickup:
	var nearest: WorldPickup
	var distance: float = 2.1
	for child: Node in pickups.get_children():
		var pickup := child as WorldPickup
		if pickup.available and pickup.global_position.distance_to(player.global_position) < distance:
			nearest = pickup
			distance = pickup.global_position.distance_to(player.global_position)
	return nearest

func interact() -> void:
	if session.stage == RunSession.Stage.LOOT and chest_node and player.global_position.distance_to(chest_node.global_position) < 2.5:
		open_chest()
	else:
		pickup_nearest()

func pickup_nearest(replace_slot: int = -1) -> bool:
	if session.stage not in [RunSession.Stage.PREPARE, RunSession.Stage.BATTLE, RunSession.Stage.LOOT] or player.state != ChallengerPlayer.State.MOVE:
		return false
	var pickup := nearest_pickup()
	if pickup == null:
		return false
	var result := session.inventory.pickup(pickup.item, replace_slot)
	if not result.accepted:
		hud.show_notice("道具栏已满 · Shift+1 / Shift+2 交换对应栏，旧物落地")
		return false
	pickup.available = false
	var location := pickup.position
	pickups.remove_child(pickup)
	pickup.queue_free()
	if result.replaced:
		spawn_pickup(result.replaced, location + Vector3(0.5, 0, 0))
	hud.show_notice("拾取成功 · 已交换的旧物保留在地面" if result.replaced else "拾取成功")
	return true

func spawn_pickup(item: RunItem, location: Vector3, airborne: bool = false) -> WorldPickup:
	var pickup := WorldPickup.new()
	pickup.item = item
	pickup.position = location
	pickup.falling_left = 1.5 if airborne else 0.0
	pickup.available = not airborne
	pickups.add_child(pickup)
	return pickup

func _airdrop() -> void:
	var angle := session.rng.randf_range(0.0, TAU)
	var radius := session.rng.randf_range(3.0, 8.0)
	var location := Vector3(cos(angle), 0.0, sin(angle)) * radius
	spawn_pickup(RunItem.new(&"potion" if session.rng.randf() < 0.5 else &"drink"), location, true)
	hud.show_notice("空投已标记 · 1.5 秒后落地 · 未拾取物资战后保留")

func open_chest() -> void:
	if session.stage != RunSession.Stage.LOOT or chest_node == null:
		return
	chest_open = true
	var inventory := session.inventory
	run_hud.open_menu("中央继承箱  %d / 2" % inventory.chest.size(), "一件一格。仅箱内物品进入快照；取出需有对应空栏。F9 保存，F10 还原测试。")
	for slot: int in [-1, 0, 1]:
		var item := inventory.weapon if slot == -1 else inventory.items[slot]
		if item:
			run_hud.action("存入 %s%s" % ["武器 · " if slot == -1 else "道具%d · " % (slot + 1), item.label()], func() -> void:
				if not inventory.store(slot):
					hud.show_notice("继承箱已满 · 请先取出一件")
			)
	for index: int in range(inventory.chest.size()):
		run_hud.action("取出 %d · %s" % [index + 1, inventory.chest[index].label()], func() -> void:
			if not inventory.withdraw(index):
				hud.show_notice("对应栏位已满 · 先空出栏位")
		)
	run_hud.action("继续搜刮", close_menu)
	run_hud.action("结束本轮…", session.request_finish)
	_sync_controls()

func save_snapshot() -> bool:
	var file := FileAccess.open(snapshot_path, FileAccess.WRITE)
	if file == null:
		hud.show_notice("快照保存失败，请检查文件是否可写")
		return false
	file.store_string(JSON.stringify(session.inventory.snapshot(), "\t"))
	hud.show_notice("两格箱内快照已保存")
	return true

func show_restore_confirmation() -> void:
	run_hud.open_menu("还原快照测试", "将清空当前随身、地面和箱内物品，仅恢复上次保存的箱内清单。本轮复活余量与用时保持原值。")
	run_hud.action("还原已保存快照", restore_snapshot)
	run_hud.action("取消", _on_stage)
	_sync_controls()

func restore_snapshot() -> bool:
	if session.stage != RunSession.Stage.LOOT and not (session.stage == RunSession.Stage.RESULT and session.won):
		return false
	if not FileAccess.file_exists(snapshot_path):
		hud.show_notice("尚无快照，先保存箱内物品")
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
	if not data is Dictionary or not session.inventory.restore_snapshot(data):
		hud.show_notice("快照内容无效，当前物品保持不变")
		return false
	_clear_pickups()
	session.stage = RunSession.Stage.LOOT
	_spawn_chest()
	_on_stage()
	hud.show_notice("快照已还原 · 仅箱内清单 · 复活与用时未刷新")
	return true

func finish_run() -> void:
	if session.stage != RunSession.Stage.CONFIRM or not save_snapshot():
		return
	session.inventory.weapon = null
	session.inventory.items = [null, null]
	session.inventory.changed.emit()
	_clear_pickups()
	session.confirm_finish()

func _record_result() -> void:
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session.report(), "\t"))

func _clear_pickups() -> void:
	for child: Node in pickups.get_children():
		pickups.remove_child(child)
		child.queue_free()

func reset_training() -> void:
	if not is_instance_valid(session):
		return
	_restart_confirm = false
	chest_open = false
	_clear_pickups()
	if is_instance_valid(chest_node):
		remove_child(chest_node)
		chest_node.queue_free()
	chest_node = null
	player.reset_training()
	player.position = Vector3(0, 0.05, 5.5)
	boss.reset_training()
	session.reset()
	spawn_pickup(RunItem.new(&"potion"), Vector3(13, 0, 0))
	spawn_pickup(RunItem.new(&"drink"), Vector3(-13, 0, 0))
	spawn_pickup(RunItem.new(&"sword"), Vector3(0, 0, -13))
	set_paused(false)
	_sync_controls()
	hud.show_notice("新一轮 · 满生命精力 · 两次复活 · 初始物品已发放")

func set_cage_locked(locked: bool) -> void:
	for body: StaticBody3D in cage_bodies:
		body.collision_layer = 1 if locked else 0
		body.set_deferred("collision_layer", 1 if locked else 0)
	cage.visible = locked

func _build_cage() -> void:
	cage = Node3D.new()
	cage.name = "BattleBoundary"
	add_child(cage)
	for side: int in range(8):
		var angle := side * TAU / 8.0
		var body := StaticBody3D.new()
		body.position = Vector3(sin(angle), 0, cos(angle)) * 10.5
		body.rotation.y = angle
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.8, 4.0, 0.18)
		shape.shape = box
		shape.position.y = 2.0
		body.add_child(shape)
		cage.add_child(body)
		cage_bodies.append(body)
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(8.8, 0.06, 0.18)
		rail.mesh = rail_mesh
		rail.position.y = 0.85
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.85, 0.48, 0.15)
		material.emission_enabled = true
		material.emission = Color(0.3, 0.12, 0.02)
		rail.material_override = material
		body.add_child(rail)

func _spawn_chest() -> void:
	if is_instance_valid(chest_node):
		return
	chest_node = Node3D.new()
	chest_node.name = "InheritanceChest"
	add_child(chest_node)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.7, 0.7)
	mesh.mesh = box
	mesh.position.y = 0.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.49, 0.13)
	mesh.material_override = material
	chest_node.add_child(mesh)
	var label := Label3D.new()
	label.text = "继承箱 · 两格\nE 整理"
	label.position.y = 1.25
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chest_node.add_child(label)
