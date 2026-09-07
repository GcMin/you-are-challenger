class_name ChallengerPlayer
extends CharacterBody3D

signal status_changed(state_text: String, stamina: float, maximum: float, invulnerable: bool)
signal feedback(message: String)
signal attack_connected(heavy: bool)
signal attacked(heavy: bool)

enum State { MOVE, LIGHT, HEAVY, ROLL, ROLL_RECOVER, HIT, DEAD }
@export var tuning: CombatTuning
var state: State = State.MOVE
var state_time: float = 0.0
var stamina: float = 100.0
var stamina_delay: float = 0.0
var vitals: CombatVitals
var visual: ActorVisual
var hurtbox: CombatHurtbox
var camera_yaw: Node3D
var camera_pitch: Node3D
var spring: SpringArm3D
var camera: Camera3D
var debug_volume: MeshInstance3D
var debug_enabled: bool = false
var controls_enabled: bool = true
var has_weapon: bool = true
var revive_protection_left: float = 0.0
var aim_target: Node3D
var direction: Vector3 = Vector3.FORWARD
var roll_direction: Vector3
var _movement: Vector3
var _sequence: int = 0
var _attack: DamageData
var _seen: Dictionary = {}
var _hit_any: bool = false
var _requested: StringName = &""
var _hit_velocity: Vector3
var _physics_ready: bool = false

func _ready() -> void:
	# Direct project startup reaches physics before initial body transforms sync.
	# Defer the first movement until the startup message queue has been flushed.
	call_deferred("_enable_physics")
	tuning = tuning.duplicate() as CombatTuning
	stamina = tuning.stamina_max
	vitals = CombatVitals.new()
	add_child(vitals)
	vitals.damaged.connect(_on_damage)
	vitals.evaded.connect(func(_data: DamageData) -> void: feedback.emit("闪避成功"))
	visual = ActorVisual.new()
	add_child(visual)
	hurtbox = CombatHurtbox.new()
	hurtbox.vitals = vitals
	hurtbox.collision_layer = 4
	add_child(hurtbox)
	hurtbox.position.y = 0.85
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	shape.shape = capsule
	hurtbox.add_child(shape)
	camera_yaw = Node3D.new()
	add_child(camera_yaw)
	camera_yaw.position.y = 1.5
	camera_pitch = Node3D.new()
	camera_yaw.add_child(camera_pitch)
	camera_pitch.position.x = 0.55
	camera_pitch.rotation.x = -0.3
	spring = SpringArm3D.new()
	camera_pitch.add_child(spring)
	spring.spring_length = 5.0
	spring.margin = 0.2
	spring.collision_mask = 1
	spring.add_excluded_object(get_rid())
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.22
	spring.shape = camera_shape
	camera = Camera3D.new()
	spring.add_child(camera)
	camera.fov = 65.0
	camera.near = 0.08
	camera.current = true
	debug_volume = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = attack_size(false)
	debug_volume.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.9, 0.7, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_volume.material_override = material
	add_child(debug_volume)
	debug_volume.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw.rotation.y -= event.relative.x * 0.0025
		camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - event.relative.y * 0.0025, -0.9, 0.25)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for action: StringName in [&"roll", &"light", &"heavy"]:
		if event.is_action_pressed(action) and not event.is_echo():
			queue_action(action)

func queue_action(action: StringName) -> bool:
	# P0 has no combo queue. Busy clicks are discarded instead of firing on recovery exit.
	if _requested != &"":
		return false
	var early_roll: bool = action == &"roll" and state in [State.LIGHT, State.HEAVY] and state_time <= tuning.early_cancel_end
	if state != State.MOVE and not early_roll:
		return false
	_requested = action
	return true

func _enable_physics() -> void:
	_physics_ready = true

func _physics_process(delta: float) -> void:
	if not _physics_ready:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled else Vector2.ZERO
	_movement = camera_yaw.basis * Vector3(input.x, 0.0, input.y)
	tick(delta, _movement)

func tick(delta: float, movement: Vector3) -> void:
	vitals.tick(delta)
	revive_protection_left = maxf(0.0, revive_protection_left - delta)
	state_time += delta
	stamina_delay = maxf(0.0, stamina_delay - delta)
	if stamina_delay <= 0.0 and state not in [State.ROLL, State.ROLL_RECOVER, State.LIGHT, State.HEAVY, State.DEAD]:
		stamina = minf(tuning.stamina_max, stamina + tuning.stamina_recovery * delta)
	if _requested != &"":
		var action: StringName = _requested
		_requested = &""
		request_action(action, movement)
	vitals.dodge_invulnerable = revive_protection_left > 0.0 or (state == State.ROLL and state_time >= tuning.invulnerable_start and state_time < tuning.invulnerable_end)
	var horizontal := Vector3.ZERO
	match state:
		State.MOVE:
			if movement.length_squared() > 0.001:
				direction = movement.normalized()
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 18.0))
			horizontal = movement.limit_length() * tuning.move_speed
			visual.play(&"run" if movement.length() > 0.1 else &"idle")
		State.LIGHT, State.HEAVY:
			var heavy: bool = state == State.HEAVY
			var windup: float = tuning.heavy_windup if heavy else tuning.light_windup
			var active: float = tuning.heavy_active if heavy else tuning.light_active
			# Intersect the elapsed interval so low frame rates cannot skip the active window.
			if state_time >= windup and state_time - delta < windup + active:
				var hits := MeleeQuery.strike(get_world_3d(), attack_transform(heavy), attack_size(heavy), 8, _attack, _seen)
				if hits > 0:
					_hit_any = true
					attack_connected.emit(heavy)
			if state_time >= tuning.duration(heavy):
				if not _hit_any:
					feedback.emit("挥击落空 · 检查距离、朝向与遮挡")
				_enter(State.MOVE)
		State.ROLL:
			horizontal = roll_direction * tuning.roll_speed
			if state_time >= tuning.roll_duration:
				horizontal = Vector3.ZERO
				velocity.x = 0.0
				velocity.z = 0.0
				_enter(State.ROLL_RECOVER)
				visual.play(&"recover", tuning.roll_recovery, true)
		State.ROLL_RECOVER:
			if state_time >= tuning.roll_recovery:
				_enter(State.MOVE)
		State.HIT:
			horizontal = _hit_velocity * maxf(0.0, 1.0 - state_time / 0.3)
			if state_time >= 0.32:
				_enter(State.MOVE)
		State.DEAD:
			horizontal = Vector3.ZERO
	if state == State.MOVE:
		velocity.x = move_toward(velocity.x, horizontal.x, tuning.acceleration * delta)
		velocity.z = move_toward(velocity.z, horizontal.z, tuning.acceleration * delta)
	else:
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	velocity.y = -0.1 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	var action_progress: float = -1.0
	match state:
		State.LIGHT, State.HEAVY:
			action_progress = state_time / tuning.duration(state == State.HEAVY)
		State.ROLL:
			action_progress = state_time / tuning.roll_duration
		State.ROLL_RECOVER:
			action_progress = state_time / tuning.roll_recovery
		State.HIT:
			action_progress = state_time / 0.32
		State.DEAD:
			action_progress = minf(state_time / 0.9, 1.0)
	visual.tick(delta, action_progress)
	var heavy_now: bool = state == State.HEAVY
	debug_volume.visible = debug_enabled and state in [State.LIGHT, State.HEAVY]
	if debug_volume.visible:
		(debug_volume.mesh as BoxMesh).size = attack_size(heavy_now)
		debug_volume.global_transform = attack_transform(heavy_now)
	status_changed.emit(state_label(), stamina, tuning.stamina_max, vitals.dodge_invulnerable)

func request_action(action: StringName, movement: Vector3 = Vector3.ZERO) -> bool:
	if state in [State.DEAD, State.HIT, State.ROLL, State.ROLL_RECOVER]:
		return false
	var can_cancel: bool = state in [State.LIGHT, State.HEAVY] and state_time <= tuning.early_cancel_end
	if state != State.MOVE and not (action == &"roll" and can_cancel):
		return false
	if action == &"roll":
		if not spend(tuning.roll_cost):
			return false
		roll_direction = movement.normalized() if movement.length_squared() > 0.01 else direction
		direction = roll_direction
		visual.rotation.y = atan2(-direction.x, -direction.z)
		_enter(State.ROLL)
		visual.play(&"roll", tuning.roll_duration, true)
		return true
	if action not in [&"light", &"heavy"]:
		return false
	if not has_weapon:
		feedback.emit("武器栏为空 · 可从地面或继承箱取回大剑")
		return false
	var heavy: bool = action == &"heavy"
	if not spend(tuning.heavy_cost if heavy else tuning.light_cost):
		return false
	revive_protection_left = 0.0
	# At most 12 degrees of assistance at windup start, then freeze facing.
	if is_instance_valid(aim_target):
		var to_target: Vector3 = aim_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() < 3.2 and to_target.length() > 0.01:
			var angle := direction.signed_angle_to(to_target.normalized(), Vector3.UP)
			if absf(angle) < deg_to_rad(35.0):
				direction = direction.rotated(Vector3.UP, clampf(angle, -deg_to_rad(12.0), deg_to_rad(12.0)))
	visual.rotation.y = atan2(-direction.x, -direction.z)
	_enter(State.HEAVY if heavy else State.LIGHT)
	_sequence += 1
	_attack = DamageData.new(StringName("player_%d_%d" % [get_instance_id(), _sequence]), tuning.heavy_damage if heavy else tuning.light_damage, global_position + Vector3.UP)
	_seen.clear()
	_hit_any = false
	visual.play(&"heavy" if heavy else &"light", tuning.duration(heavy), true)
	attacked.emit(heavy)
	return true

func spend(cost: float) -> bool:
	if stamina + 0.001 < cost:
		feedback.emit("精力不足 · 走位并等待恢复")
		return false
	stamina = maxf(0.0, stamina - cost)
	stamina_delay = tuning.stamina_delay
	return true

func _enter(next: State) -> void:
	state = next
	state_time = 0.0
	vitals.dodge_invulnerable = false
	if next == State.MOVE:
		visual.play(&"idle", 0.0, true)

func _on_damage(data: DamageData) -> void:
	visual.flash()
	var away := global_position - data.origin
	away.y = 0.0
	_hit_velocity = away.normalized() * data.knockback
	_requested = &""
	_enter(State.DEAD if vitals.current <= 0.0 else State.HIT)
	visual.play(&"death" if state == State.DEAD else &"hit", 0.9 if state == State.DEAD else 0.32, true)
	hurtbox.set_deferred("collision_layer", 0 if state == State.DEAD else 4)
	feedback.emit("%s · -%d HP" % ["倒地" if state == State.DEAD else "受到攻击", int(data.amount)])
	print("DAMAGE ", data.attack_id, " hp=", vitals.current)

func reset_training() -> void:
	revive_protection_left = 0.0
	vitals.reset()
	stamina = tuning.stamina_max
	stamina_delay = 0.0
	_requested = &""
	_enter(State.MOVE)
	hurtbox.collision_layer = 4
	hurtbox.set_deferred("collision_layer", 4)
	position = Vector3(0, 0.05, 3.5)
	direction = Vector3.FORWARD
	visual.rotation.y = 0.0
	velocity = Vector3.ZERO

func revive_at(location: Vector3) -> void:
	reset_training()
	global_position = location
	vitals.restore_health(vitals.maximum * 0.5)
	revive_protection_left = 2.0
	vitals.dodge_invulnerable = true

func equip_weapon(equipped: bool) -> void:
	has_weapon = equipped
	for mesh: MeshInstance3D in visual.meshes:
		if mesh.name.begins_with("TwoHandedGreatsword"):
			mesh.visible = equipped

func attack_size(heavy: bool) -> Vector3:
	return Vector3(1.7, 1.8, 2.3) if heavy else Vector3(2.0, 1.6, 2.0)

func attack_transform(heavy: bool) -> Transform3D:
	var attack_basis := Basis.looking_at(direction)
	return Transform3D(attack_basis, global_position + Vector3.UP + direction * (1.25 if heavy else 1.15))

func state_label() -> String:
	match state:
		State.MOVE: return "移动 / 待机"
		State.ROLL: return "翻滚 · 无敌" if vitals.dodge_invulnerable else "翻滚 · 可受击"
		State.ROLL_RECOVER: return "翻滚 · 起身收势"
		State.HIT: return "受击硬直"
		State.DEAD: return "倒地"
		State.LIGHT, State.HEAVY:
			var heavy: bool = state == State.HEAVY
			var windup: float = tuning.heavy_windup if heavy else tuning.light_windup
			var active: float = tuning.heavy_active if heavy else tuning.light_active
			return ("重击" if heavy else "轻击") + (" · 前摇" if state_time < windup else " · 生效" if state_time < windup + active else " · 收招")
	return ""
