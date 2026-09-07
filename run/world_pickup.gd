class_name WorldPickup
extends Node3D

var item: RunItem
var falling_left: float = 0.0
var available: bool = true
var mesh: Node3D

func _ready() -> void:
	if item.kind == &"sword":
		mesh = (load("res://assets/weapons/greatsword.glb") as PackedScene).instantiate() as Node3D
		mesh.rotation.x = PI * 0.5
		mesh.position.y = 0.25
	else:
		var bottle := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.12
		shape.bottom_radius = 0.18
		shape.height = 0.5
		bottle.mesh = shape
		var bottle_material := StandardMaterial3D.new()
		bottle_material.albedo_color = Color(0.93, 0.23, 0.17) if item.kind == &"potion" else Color(0.18, 0.9, 0.63)
		bottle_material.emission_enabled = true
		bottle_material.emission = bottle_material.albedo_color * 0.25
		bottle.material_override = bottle_material
		bottle.position.y = 0.3
		mesh = bottle
	add_child(mesh)
	var label := Label3D.new()
	label.text = item.label()
	label.font_size = 40
	label.pixel_size = 0.005
	label.position.y = 0.9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var beacon := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.42
	beacon.mesh = ring
	beacon.position.y = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.93, 0.7, 0.26)
	beacon.material_override = material
	add_child(beacon)

func _process(delta: float) -> void:
	if falling_left > 0.0:
		falling_left = maxf(0.0, falling_left - delta)
		mesh.position.y = 0.3 + 3.5 * falling_left / 1.5
		available = falling_left <= 0.0
