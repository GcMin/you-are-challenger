class_name RunSession
extends Node

signal stage_changed
signal ai_requested(enabled: bool)
signal revive_requested
signal airdrop_requested
signal victory
signal result_ready

enum Stage { PREPARE, BATTLE, DOWNED, LOOT, CONFIRM, RESULT }
var stage: Stage = Stage.PREPARE
var time_limit: float = 180.0
var elapsed: float = 0.0
var revives: int = 2
var deaths: int = 0
var received_hits: int = 0
var won: bool = false
var reason: String = ""
var inventory := RunInventory.new()
var rng := RandomNumberGenerator.new()
var drops: int = 0
var _drop_left: float = 20.0
var _revive_left: float = 0.0
var _intro_left: float = 0.0
var _pending_death: bool = false

func _ready() -> void:
	rng.randomize()
	reset()

func reset() -> void:
	stage = Stage.PREPARE
	elapsed = 0.0
	revives = 2
	deaths = 0
	received_hits = 0
	won = false
	reason = ""
	drops = 0
	_drop_left = rng.randf_range(18.0, 28.0)
	_revive_left = 0.0
	_intro_left = 0.0
	_pending_death = false
	inventory.reset()
	ai_requested.emit(false)
	stage_changed.emit()

func start() -> bool:
	if stage != Stage.PREPARE:
		return false
	stage = Stage.BATTLE
	_intro_left = 1.0
	stage_changed.emit()
	return true

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if stage not in [Stage.BATTLE, Stage.DOWNED]:
		return
	elapsed = minf(time_limit, elapsed + delta)
	if elapsed >= time_limit:
		fail("挑战超时")
		return
	if _pending_death:
		_pending_death = false
		deaths += 1
		if revives == 0:
			fail("复活机会耗尽")
			return
		revives -= 1
		stage = Stage.DOWNED
		_revive_left = 1.2
		ai_requested.emit(false)
		stage_changed.emit()
	if stage == Stage.DOWNED:
		_revive_left -= delta
		if _revive_left <= 0.0:
			revive_requested.emit()
			stage = Stage.BATTLE
			_intro_left = 0.5
			stage_changed.emit()
		return
	if _intro_left > 0.0:
		_intro_left -= delta
		if _intro_left <= 0.0:
			ai_requested.emit(true)
	_drop_left -= delta
	if _drop_left <= 0.0 and drops < 3:
		drops += 1
		_drop_left = rng.randf_range(18.0, 28.0)
		airdrop_requested.emit()

func player_died() -> void:
	if stage == Stage.BATTLE:
		# Resolve next tick so a legal Boss kill in this combat step wins first.
		_pending_death = true

func boss_died() -> void:
	if stage not in [Stage.BATTLE, Stage.DOWNED]:
		return
	_pending_death = false
	won = true
	stage = Stage.LOOT
	ai_requested.emit(false)
	victory.emit()
	stage_changed.emit()

func fail(message: String) -> void:
	if stage not in [Stage.BATTLE, Stage.DOWNED]:
		return
	reason = message
	won = false
	_pending_death = false
	stage = Stage.RESULT
	ai_requested.emit(false)
	stage_changed.emit()
	result_ready.emit()

func request_finish() -> void:
	if stage == Stage.LOOT:
		stage = Stage.CONFIRM
		stage_changed.emit()

func cancel_finish() -> void:
	if stage == Stage.CONFIRM:
		stage = Stage.LOOT
		stage_changed.emit()

func confirm_finish() -> void:
	if stage == Stage.CONFIRM:
		stage = Stage.RESULT
		reason = "挑战成功"
		stage_changed.emit()
		result_ready.emit()

func report() -> Dictionary:
	return {"won": won, "reason": reason, "seconds": elapsed, "deaths": deaths, "revives_used": 2 - revives, "received_hits": received_hits}
