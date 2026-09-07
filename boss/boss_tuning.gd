class_name BossTuning
extends Resource

@export var health: float = 600.0
@export var chase_speed: float = 4.3
@export var melee_range: float = 2.6
@export var dash_range: float = 9.0
@export var dash_speed: float = 15.0
@export var sweep_windup: float = 0.65
@export var sweep_active: float = 0.18
@export var sweep_recovery: float = 0.8
@export var sweep_damage: float = 18.0
@export var slam_windup: float = 1.25
@export var slam_active: float = 0.18
@export var slam_recovery: float = 1.65
@export var slam_damage: float = 32.0
@export var dash_windup: float = 0.7
@export var dash_active: float = 0.4
@export var dash_recovery: float = 1.0
@export var dash_damage: float = 24.0

func windup(move: int) -> float:
	return [sweep_windup, slam_windup, dash_windup][move]

func active(move: int) -> float:
	return [sweep_active, slam_active, dash_active][move]

func recovery(move: int) -> float:
	return [sweep_recovery, slam_recovery, dash_recovery][move]

func damage(move: int) -> float:
	return [sweep_damage, slam_damage, dash_damage][move]
