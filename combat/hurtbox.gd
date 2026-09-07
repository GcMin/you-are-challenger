class_name CombatHurtbox
extends Area3D

var vitals: CombatVitals

func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false

func receive(data: DamageData) -> bool:
	return vitals.take_damage(data) if vitals != null else false
