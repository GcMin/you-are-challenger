extends Node3D

@export var camera_fixture: bool = true

func _build_ground() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.16, 0.22, 0.27)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.7, 0.81, 0.9)
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.87, 0.72)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	_box(Vector3(32, 0.5, 32), Vector3(0, -0.25, 0), Color(0.08, 0.12, 0.14), true)
	# The test area is entirely flat; low edges plus invisible colliders contain rolls.
	for axis: int in [-1, 1]:
		_box(Vector3(32, 0.18, 0.18), Vector3(0, 0.09, axis * 16), Color(0.59, 0.69, 0.67), false)
		_box(Vector3(0.18, 0.18, 32), Vector3(axis * 16, 0.09, 0), Color(0.59, 0.69, 0.67), false)
		_wall(Vector3(33, 5, 0.3), Vector3(0, 2, axis * 16.2))
		_wall(Vector3(0.3, 5, 33), Vector3(axis * 16.2, 2, 0))
	# Sparse metre grid and one flush practice ring give reliable scale cues.
	for index: int in range(-7, 8):
		_box(Vector3(30, 0.008, 0.018), Vector3(0, 0.006, index * 2), Color(0.12, 0.18, 0.20), false)
		_box(Vector3(0.018, 0.008, 30), Vector3(index * 2, 0.006, 0), Color(0.12, 0.18, 0.20), false)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 3.05
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.79, 0.64, 0.36)
	ring.material_override = material
	add_child(ring)
	# A separate camera/occlusion fixture, away from the combat ring.
	if camera_fixture:
		_box(Vector3(5, 3, 0.35), Vector3(7, 1.5, -5), Color(0.32, 0.43, 0.47), true)

func _box(size: Vector3, position_value: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position = position_value
	add_child(mesh)
	if solid:
		_wall(size, position_value)

func _wall(size: Vector3, position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
