class_name CombatVitals
extends Node

signal changed(current: float, maximum: float)
signal damaged(data: DamageData)
signal evaded(data: DamageData)
signal died

@export var maximum: float = 100.0
var current: float = 100.0
var damage_enabled: bool = true
var dodge_invulnerable: bool = false
var protection_left: float = 0.0
var _seen: Dictionary = {}
var _order: Array[StringName] = []

func _ready() -> void:
	reset()

func tick(delta: float) -> void:
	protection_left = maxf(0.0, protection_left - delta)

func take_damage(data: DamageData) -> bool:
	if not damage_enabled or current <= 0.0 or data.amount <= 0.0 or _seen.has(data.attack_id):
		return false
	# A swing is resolved once, including an evasion. It cannot hit again after i-frames end.
	_seen[data.attack_id] = true
	_order.append(data.attack_id)
	if _order.size() > 128:
		_seen.erase(_order.pop_front())
	if dodge_invulnerable or protection_left > 0.0:
		evaded.emit(data)
		return false
	current = maxf(0.0, current - data.amount)
	protection_left = 0.35
	changed.emit(current, maximum)
	damaged.emit(data)
	if current <= 0.0:
		died.emit()
	return true

func reset() -> void:
	current = maximum
	protection_left = 0.0
	dodge_invulnerable = false
	_seen.clear()
	_order.clear()
	changed.emit(current, maximum)

func restore_health(value: float) -> void:
	current = clampf(value, 0.0, maximum)
	changed.emit(current, maximum)

func heal(amount: float) -> float:
	var before := current
	if current > 0.0:
		restore_health(current + amount)
	return current - before
