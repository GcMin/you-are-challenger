extends SceneTree

var visual: ActorVisual
var skeleton: Skeleton3D
var failures: Array[String] = []
var passed: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)

func sample(clip: StringName, progress: float) -> Array[Transform3D]:
	visual.play(clip, 0.0, true)
	visual.tick(0.0, progress)
	skeleton.force_update_all_bone_transforms()
	var poses: Array[Transform3D] = []
	for bone: int in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_global_pose(bone))
	return poses

func continuity(a: Array[Transform3D], b: Array[Transform3D], message: String) -> void:
	var worst_position: float = 0.0
	var worst_rotation: float = 0.0
	for bone: int in range(a.size()):
		worst_position = maxf(worst_position, a[bone].origin.distance_to(b[bone].origin))
		worst_rotation = maxf(worst_rotation, a[bone].basis.get_rotation_quaternion().angle_to(b[bone].basis.get_rotation_quaternion()))
	check(worst_position < 0.01 and worst_rotation < 0.03, message)

func run() -> void:
	visual = ActorVisual.new()
	root.add_child(visual)
	await process_frame
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var left: int = skeleton.find_bone("hand_l")
	var right: int = skeleton.find_bone("hand_r")
	check(left >= 0 and right >= 0, "Imported character contains separate left/right hand bones")
	for clip: StringName in [&"idle", &"light", &"heavy", &"boss_slam", &"boss_dash"]:
		for progress: float in [0.0, 0.35, 0.8, 1.0]:
			var poses := sample(clip, progress)
			var distance: float = poses[left].origin.distance_to(poses[right].origin)
			check(distance > 0.08 and distance < 0.23, "%s %.2f: both wrists remain at separate grip positions (%.3fm)" % [clip, progress, distance])
	var idle := sample(&"idle", 0.0)
	continuity(sample(&"light", 1.0), idle, "Light recovery ends at sword stance")
	continuity(sample(&"heavy", 1.0), idle, "Heavy recovery ends at sword stance")
	continuity(sample(&"boss_slam", 1.0), idle, "Boss slam recovery ends at two-handed stance")
	continuity(sample(&"boss_dash", 1.0), idle, "Boss dash recovery ends at two-handed stance")
	continuity(sample(&"roll", 1.0), sample(&"recover", 0.0), "Roll and get-up share an identical boundary pose")
	continuity(sample(&"recover", 1.0), idle, "Get-up ends at the same two-handed stance")
	var report := {"passed": passed, "failed": failures.size(), "failures": failures}
	var file := FileAccess.open("res://test_output/animation_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ANIMATION_RESULT ", JSON.stringify(report))
	visual.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
