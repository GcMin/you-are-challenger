class_name DamageData
extends RefCounted

var attack_id: StringName
var amount: float
var origin: Vector3
var knockback: float = 2.5

func _init(id: StringName = &"", damage: float = 0.0, source: Vector3 = Vector3.ZERO) -> void:
	attack_id = id
	amount = damage
	origin = source
