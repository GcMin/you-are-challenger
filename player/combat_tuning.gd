class_name CombatTuning
extends Resource

@export var move_speed: float = 5.5
@export var acceleration: float = 35.0
@export var stamina_max: float = 100.0
@export var stamina_recovery: float = 25.0
@export var stamina_delay: float = 0.7
@export var roll_cost: float = 25.0
@export var roll_duration: float = 0.55
@export var roll_recovery: float = 0.05
@export var roll_speed: float = 9.0
@export var invulnerable_start: float = 0.08
@export var invulnerable_end: float = 0.28
@export var light_damage: float = 22.0
@export var light_cost: float = 10.0
@export var light_windup: float = 0.25
@export var light_active: float = 0.12
@export var light_recovery: float = 0.38
@export var heavy_damage: float = 48.0
@export var heavy_cost: float = 20.0
@export var heavy_windup: float = 0.6
@export var heavy_active: float = 0.18
@export var heavy_recovery: float = 0.6
@export var early_cancel_end: float = 0.12

func duration(heavy: bool) -> float:
	return heavy_windup + heavy_active + heavy_recovery if heavy else light_windup + light_active + light_recovery
