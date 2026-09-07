class_name MeleeQuery
extends RefCounted

## The visible debug box and the actual physics query share these dimensions.
static func strike(world: World3D, transform: Transform3D, size: Vector3, mask: int, data: DamageData, seen: Dictionary) -> int:
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var count: int = 0
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 32):
		var hurt := result.collider as CombatHurtbox
		if hurt == null or hurt.vitals == null or seen.has(hurt.vitals.get_instance_id()):
			continue
		var ray := PhysicsRayQueryParameters3D.create(data.origin, hurt.global_position, 1)
		if not world.direct_space_state.intersect_ray(ray).is_empty():
			continue
		seen[hurt.vitals.get_instance_id()] = true
		if hurt.receive(data):
			count += 1
	return count
