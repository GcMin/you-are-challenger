class_name ArenaBoss
extends CharacterBody3D

signal telegraph_changed(text: String, progress: float)
signal feedback(text: String)
signal struck
signal impact(move: int)

enum State { WAIT, CHASE, WINDUP, ACTIVE, RECOVERY, DEAD }
enum Move { SWEEP, SLAM, DASH }
const MOVE_NAMES: Array[String] = ["横扫", "延迟重砸", "短距突进"]
@export var tuning: BossTuning = preload("res://boss/default_tuning.tres")
var state: State = State.WAIT
var move: Move = Move.SWEEP
var elapsed: float = 0.0
var engaged: bool = false
var ai_enabled: bool = true
var player: ChallengerPlayer
var vitals: CombatVitals
var visual: ActorVisual
var hurtbox: CombatHurtbox
var direction: Vector3 = Vector3.BACK
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var attack_origin: Vector3
var history: Array[int] = []
var rng := RandomNumberGenerator.new()
var _sequence: int = 0
var _attack: DamageData
var _seen: Dictionary = {}
var _physics_ready: bool = false

func _ready() -> void:
	# Match the player's startup barrier before querying or moving physics bodies.
	call_deferred("_enable_physics")
	tuning = tuning.duplicate() as BossTuning
	rng.randomize()
	collision_layer = 2
	collision_mask = 3
	var collision := CollisionShape3D.new()
	# Flat sides prevent actor bodies from acting as ramps during close contact.
	var capsule := CylinderShape3D.new()
	capsule.radius = 0.48
	capsule.height = 2.4
	collision.shape = capsule
	collision.position.y = 1.2
	add_child(collision)
	vitals = CombatVitals.new()
	vitals.maximum = tuning.health
	add_child(vitals)
	visual = ActorVisual.new()
	visual.armor_color = Color(0.38, 0.17, 0.065)
	visual.scale = Vector3.ONE * 1.35
	add_child(visual)
	visual.rotation.y = PI
	hurtbox = CombatHurtbox.new()
	hurtbox.vitals = vitals
	hurtbox.collision_layer = 8
	hurtbox.position.y = 1.2
	add_child(hurtbox)
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = capsule.duplicate()
	hurtbox.add_child(hurt_shape)
	vitals.damaged.connect(_on_damage)
	marker = MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	marker_material = StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_material
	add_child(marker)
	marker.visible = false

func begin() -> void:
	if ai_enabled and state == State.WAIT and vitals.current > 0.0:
		engaged = true
		_enter(State.CHASE)

func _enable_physics() -> void:
	_physics_ready = true

func _physics_process(delta: float) -> void:
	if not _physics_ready:
		return
	tick(delta)

func tick(delta: float) -> void:
	_ground_on_arena()
	vitals.tick(delta)
	if state == State.DEAD:
		elapsed += delta
		visual.tick(delta, minf(elapsed / 1.1, 1.0))
		return
	if not is_instance_valid(player) or player.vitals.current <= 0.0:
		engaged = false
		_enter(State.WAIT)
	var remaining: float = delta
	# Consume phase boundaries explicitly, including coarse ticks; never skip damage.
	while remaining > 0.00001:
		if state in [State.WAIT, State.CHASE]:
			elapsed += remaining
			velocity = Vector3.ZERO
			if state == State.CHASE:
				var offset := player.global_position - global_position
				offset.y = 0.0
				if offset.length() > 0.01:
					direction = offset.normalized()
					visual.rotation.y = atan2(-direction.x, -direction.z)
				if offset.length() <= tuning.melee_range:
					start_attack(choose_attack(offset.length()))
				elif offset.length() <= tuning.dash_range and elapsed >= 0.25 and (history.is_empty() or history.back() != Move.DASH):
					start_attack(Move.DASH)
				else:
					velocity = direction * tuning.chase_speed
			_move_body()
			if state in [State.WAIT, State.CHASE]:
				visual.play(&"run" if velocity.length() > 0.5 else &"idle")
				visual.tick(remaining)
				telegraph_changed.emit("追击中 · 留意起手" if engaged else "Enter 开始 Boss 对练", 0.0)
			remaining = 0.0
		else:
			var duration := phase_duration()
			var step := minf(remaining, maxf(0.0, duration - elapsed))
			if state == State.ACTIVE:
				if move == Move.DASH:
					# Sample the travelled segment so a dash cannot tunnel through a hurtbox.
					var start := global_position
					velocity = direction * tuning.dash_speed
					var motion := direction * tuning.dash_speed * step
					move_and_collide(motion)
					var end := global_position
					var samples := maxi(1, ceili(start.distance_to(end) / 0.25))
					for sample: int in range(samples + 1):
						_strike(start.lerp(end, float(sample) / samples))
				else:
					_strike(attack_origin)
			elapsed += step
			remaining -= step
			_sample_pose()
			telegraph_changed.emit(phase_label(), minf(elapsed / duration, 1.0))
			if elapsed >= duration - 0.00001:
				if state == State.WINDUP:
					_enter(State.ACTIVE)
					impact.emit(move)
				elif state == State.ACTIVE:
					_enter(State.RECOVERY)
				else:
					_enter(State.CHASE)
	visual.tick_flash(delta)
	_ground_on_arena()

func _ground_on_arena() -> void:
	# This non-jumping Boss belongs to a flat arena. Ground against world geometry,
	# never another actor's head; apply during attacks/death as well as locomotion.
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 5.0, global_position - Vector3.UP * 20.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = (hit.position as Vector3).y + 0.001
		velocity.y = 0.0

func _move_body() -> void:
	velocity.y = -0.1 if is_on_floor() else -2.0
	move_and_slide()

func choose_attack(distance: float) -> Move:
	if distance > tuning.melee_range and (history.is_empty() or history.back() != Move.DASH):
		return Move.DASH
	# Never repeat immediately; close range alternates sweep/slam with occasional dash.
	var choices: Array[int] = [Move.SWEEP, Move.SLAM]
	if distance > 1.8:
		choices.append(Move.DASH)
	if not history.is_empty():
		choices.erase(history.back())
	return choices[rng.randi_range(0, choices.size() - 1)] as Move

func start_attack(next: Move) -> bool:
	if state != State.CHASE or not engaged or not is_instance_valid(player) or player.vitals.current <= 0.0:
		return false
	move = next
	var offset := player.global_position - global_position
	offset.y = 0.0
	direction = offset.normalized() if offset.length() > 0.01 else direction
	visual.rotation.y = atan2(-direction.x, -direction.z)
	attack_origin = global_position
	velocity = Vector3.ZERO
	history.append(move)
	if history.size() > 32:
		history.pop_front()
	_sequence += 1
	_attack = DamageData.new(StringName("boss_%d_%d" % [get_instance_id(), _sequence]), tuning.damage(move), attack_origin + Vector3.UP)
	_seen.clear()
	visual.play([&"light", &"boss_slam", &"boss_dash"][move], 0.0, true)
	_enter(State.WINDUP)
	_update_marker()
	_sample_pose()
	return true

func phase_duration() -> float:
	return tuning.windup(move) if state == State.WINDUP else tuning.active(move) if state == State.ACTIVE else tuning.recovery(move)

func _sample_pose() -> void:
	# Map each gameplay phase onto the authored clip's corresponding phase.
	var boundaries: Vector2 = Vector2(0.25 / 0.75, 0.37 / 0.75)
	if move == Move.SLAM:
		boundaries = Vector2(0.6 / 1.38, 0.78 / 1.38)
	elif move == Move.DASH:
		boundaries = Vector2(0.3, 0.65)
	var progress := clampf(elapsed / phase_duration(), 0.0, 1.0)
	var pose_time := lerpf(0.0, boundaries.x, progress) if state == State.WINDUP else lerpf(boundaries.x, boundaries.y, progress) if state == State.ACTIVE else lerpf(boundaries.y, 1.0, progress)
	visual.tick(0.0, pose_time)

func attack_size() -> Vector3:
	return [Vector3(4.4, 2.6, 2.5), Vector3(2.2, 2.6, 3.4), Vector3(1.8, 2.6, 1.8)][move]

func attack_transform(origin: Vector3) -> Transform3D:
	var reach: float = [1.5, 1.9, 0.9][move]
	return Transform3D(Basis.looking_at(direction), origin + Vector3.UP * 1.2 + direction * reach)

func _strike(origin: Vector3) -> void:
	_attack.origin = origin + Vector3.UP
	MeleeQuery.strike(get_world_3d(), attack_transform(origin), attack_size(), 4, _attack, _seen)

func _update_marker() -> void:
	var size := attack_size()
	var marker_transform := attack_transform(attack_origin)
	if move == Move.DASH:
		var travel := tuning.dash_speed * tuning.dash_active
		size.z += travel
		marker_transform.origin += direction * travel * 0.5
	size.y = 0.035
	marker_transform.origin.y = 0.04
	(marker.mesh as BoxMesh).size = size
	marker.global_transform = marker_transform

func _enter(next: State) -> void:
	state = next
	elapsed = 0.0
	marker.visible = state in [State.WINDUP, State.ACTIVE]
	marker_material.albedo_color = Color(1.0, 0.12, 0.06, 0.65) if state == State.ACTIVE else Color(1.0, 0.57, 0.12, 0.3)
	if state in [State.WAIT, State.CHASE]:
		visual.play(&"idle")
	elif state == State.RECOVERY:
		velocity = Vector3.ZERO
		telegraph_changed.emit(phase_label(), 0.0)

func phase_label() -> String:
	if state == State.RECOVERY:
		return "重砸收招 · 重击反击" if move == Move.SLAM else "横扫收招 · 轻击反击" if move == Move.SWEEP else "突进收招 · 追上反击"
	return MOVE_NAMES[move] + (" · 方向已锁定" if state == State.WINDUP else " · 生效")

func _on_damage(data: DamageData) -> void:
	if state == State.WAIT and vitals.current > 0.0:
		begin()
	visual.flash()
	struck.emit()
	feedback.emit("命中 Boss · -%d HP" % int(data.amount))
	if vitals.current <= 0.0:
		engaged = false
		_enter(State.DEAD)
		velocity = Vector3.ZERO
		hurtbox.set_deferred("collision_layer", 0)
		visual.play(&"death", 1.1, true)
		telegraph_changed.emit("Boss 已击倒 · R 再次挑战", 0.0)

func reset_training() -> void:
	vitals.reset()
	engaged = false
	history.clear()
	_seen.clear()
	position = Vector3.ZERO
	velocity = Vector3.ZERO
	direction = Vector3.BACK
	visual.rotation.y = PI
	hurtbox.collision_layer = 8
	hurtbox.set_deferred("collision_layer", 8)
	_enter(State.WAIT)
	visual.play(&"idle", 0.0, true)
	telegraph_changed.emit("Enter 开始 Boss 对练", 0.0)
