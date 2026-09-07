class_name ActorVisual
extends Node3D

const MODEL: PackedScene = preload("res://assets/characters/challenger.glb")
var animation: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var flash_left: float = 0.0
var flash_material: StandardMaterial3D
var active_clip: StringName = &""
var armor_color: Color = Color(0.10, 0.29, 0.34)

func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	# glTF character convention is +Z forward; gameplay uses Godot's -Z.
	model.rotation.y = PI
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		meshes.append(mesh)
		for surface: int in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source and source.resource_name.begins_with("Armor"):
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color = armor_color
				mesh.set_surface_override_material(surface, material)
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.32, 0.16)
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if animation:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for key: StringName in animation.get_animation_list():
			if str(key).ends_with("idle") or str(key).ends_with("run"):
				animation.get_animation(key).loop_mode = Animation.LOOP_LINEAR
	play(&"idle")

func play(clip: StringName, duration: float = 0.0, restart: bool = false) -> void:
	if not animation or (not restart and active_clip == clip and animation.is_playing()):
		return
	for key: StringName in animation.get_animation_list():
		if str(key).get_slice("/", str(key).get_slice_count("/") - 1) == str(clip):
			active_clip = clip
			var speed: float = animation.get_animation(key).length / duration if duration > 0.0 else 1.0
			if restart:
				animation.stop(true)
			animation.play(key, 0.0 if restart else 0.1, speed)
			animation.advance(0.0)
			return

func tick(delta: float, action_progress: float = -1.0) -> void:
	if animation and action_progress >= 0.0:
		# Combat state and pose use the same clock. Visual hit feedback cannot delay a clip.
		var key: StringName = animation.assigned_animation
		if key == &"":
			return
		if not animation.is_playing():
			animation.play(key, 0.0)
		var clip := animation.get_animation(key)
		animation.seek(clampf(action_progress, 0.0, 1.0) * clip.length, true)
	elif animation and delta > 0.0:
		animation.advance(delta)
	tick_flash(delta)

func tick_flash(delta: float) -> void:
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - delta)
		if flash_left <= 0.0:
			for mesh: MeshInstance3D in meshes:
				mesh.material_overlay = null

func flash() -> void:
	if DisplayServer.get_name() == "headless":
		return
	flash_left = 0.12
	for mesh: MeshInstance3D in meshes:
		mesh.material_overlay = flash_material
