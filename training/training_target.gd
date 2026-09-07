class_name TrainingTarget
extends StaticBody3D

signal telegraph_changed(text: String, progress: float)
signal feedback(text: String)
signal struck

var vitals: CombatVitals
var visual: ActorVisual
var player: ChallengerPlayer
var hurtboxes: Array[CombatHurtbox] = []
var automatic: bool = false
var phase: int = 0 # 0 idle, 1 telegraph, 2 active, 3 recovery
var elapsed: float = 0.0
var direction: Vector3 = Vector3.BACK
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var _sequence: int = 0
var _attack: DamageData
var _seen: Dictionary = {}

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 2.4
	collision.shape = shape
	add_child(collision)
	collision.position.y = 1.2
	vitals = CombatVitals.new()
	vitals.maximum = 600.0
	add_child(vitals)
	visual = ActorVisual.new()
	visual.armor_color = Color(0.32, 0.16, 0.075)
	visual.scale = Vector3.ONE * 1.35
	add_child(visual)
	visual.rotation.y = PI
	# Two hurtboxes intentionally overlap: one swing must still damage the owner once.
	for height: float in [0.85, 1.65]:
		var hurt := CombatHurtbox.new()
		hurt.vitals = vitals
		hurt.collision_layer = 8
		add_child(hurt)
		hurt.position.y = height
		var col := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.48
		capsule.height = 1.25
		col.shape = capsule
		hurt.add_child(col)
		hurtboxes.append(hurt)
	vitals.damaged.connect(_on_damage)
	marker = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 0.035, 2.8)
	marker.mesh = box
	marker_material = StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.34, 0.08, 0.35)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_material
	add_child(marker)
	marker.visible = false

func _physics_process(delta: float) -> void:
	vitals.tick(delta)
	visual.tick(delta)
	if vitals.current <= 0.0:
		return
	elapsed += delta
	match phase:
		0:
			if automatic and elapsed >= 1.4:
				start_pulse()
		1:
			telegraph_changed.emit("训练攻击 · 方向已锁定", minf(elapsed / 1.15, 1.0))
			if elapsed >= 1.15:
				phase = 2
				elapsed = 0.0
				visual.play(&"light", 0.5)
				marker_material.albedo_color = Color(1.0, 0.1, 0.06, 0.65)
		2:
			MeleeQuery.strike(get_world_3d(), Transform3D(Basis.looking_at(direction), global_position + Vector3.UP + direction * 1.45), Vector3(2.5, 2.0, 2.8), 4, _attack, _seen)
			if elapsed >= 0.18:
				phase = 3
				elapsed = 0.0
				marker.visible = false
				telegraph_changed.emit("训练靶收招 · 可以反击", 0.0)
		3:
			if elapsed >= 1.3:
				phase = 0
				elapsed = 0.0
				visual.play(&"idle")
				telegraph_changed.emit("循环训练中" if automatic else "静止训练靶", 0.0)

func start_pulse() -> void:
	if phase != 0 or vitals.current <= 0.0 or not is_instance_valid(player) or player.vitals.current <= 0.0:
		return
	direction = player.global_position - global_position
	direction.y = 0.0
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.BACK
	visual.rotation.y = atan2(-direction.x, -direction.z)
	phase = 1
	elapsed = 0.0
	_sequence += 1
	_attack = DamageData.new(StringName("training_%d" % _sequence), 18.0, global_position + Vector3.UP)
	_seen.clear()
	marker.visible = true
	marker.global_transform = Transform3D(Basis.looking_at(direction), global_position + Vector3(0, 0.04, 0) + direction * 1.45)
	marker_material.albedo_color = Color(1.0, 0.34, 0.08, 0.35)
	visual.play(&"heavy", 1.8)

func _on_damage(data: DamageData) -> void:
	visual.flash()
	struck.emit()
	feedback.emit("命中训练靶 · -%d HP · 单次结算" % int(data.amount))
	print("TARGET_DAMAGE ", data.attack_id, " hp=", vitals.current)
	if vitals.current <= 0.0:
		automatic = false
		phase = 0
		marker.visible = false
		visual.play(&"death", 1.1)
		for hurt: CombatHurtbox in hurtboxes:
			hurt.set_deferred("collision_layer", 0)
		telegraph_changed.emit("训练靶已击倒 · R 重置", 0.0)

func reset_training() -> void:
	vitals.reset()
	automatic = false
	phase = 0
	elapsed = 0.0
	marker.visible = false
	_seen.clear()
	visual.play(&"idle")
	for hurt: CombatHurtbox in hurtboxes:
		hurt.collision_layer = 8
		hurt.set_deferred("collision_layer", 8)
	telegraph_changed.emit("静止训练靶", 0.0)
