class_name RunInventory
extends RefCounted

signal changed
var weapon: RunItem
var items: Array[RunItem] = [null, null]
var chest: Array[RunItem] = []

func reset() -> void:
	weapon = RunItem.new(&"sword")
	items = [RunItem.new(&"potion"), RunItem.new(&"drink")]
	chest.clear()
	changed.emit()

func pickup(item: RunItem, replace_slot: int = -1) -> Dictionary:
	var replaced: RunItem
	if item.kind == &"sword":
		replaced = weapon
		weapon = item
	else:
		var slot := items.find(null)
		if slot < 0:
			slot = replace_slot
		if slot < 0 or slot >= 2:
			return {"accepted": false, "replaced": null}
		replaced = items[slot]
		items[slot] = item
	changed.emit()
	return {"accepted": true, "replaced": replaced}

func store(slot: int) -> bool:
	var item: RunItem = weapon if slot == -1 else items[slot] if slot in [0, 1] else null
	if chest.size() >= 2 or item == null:
		return false
	chest.append(item)
	if slot == -1:
		weapon = null
	else:
		items[slot] = null
	changed.emit()
	return true

func withdraw(index: int) -> bool:
	if index < 0 or index >= chest.size():
		return false
	var item := chest[index]
	if (item.kind == &"sword" and weapon != null) or (item.kind != &"sword" and not items.has(null)):
		return false
	chest.remove_at(index)
	pickup(item)
	return true

func carried_labels() -> String:
	var labels := PackedStringArray()
	if weapon:
		labels.append(weapon.label())
	for item: RunItem in items:
		if item:
			labels.append(item.label())
	return "、".join(labels) if not labels.is_empty() else "无"

func snapshot() -> Dictionary:
	var contents: Array[Dictionary] = []
	for item: RunItem in chest:
		contents.append(item.serialize())
	return {"version": 1, "items": contents}

func restore_snapshot(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("items") is Array or data.items.size() > 2:
		return false
	var restored: Array[RunItem] = []
	var seen: Dictionary = {}
	for raw: Variant in data.items:
		if not raw is Dictionary or not raw.get("uid") is String or raw.uid.is_empty() or not raw.get("kind") is String:
			return false
		if not RunItem.NAMES.has(StringName(raw.kind)) or seen.has(raw.uid):
			return false
		seen[raw.uid] = true
		restored.append(RunItem.new(StringName(raw.kind), raw.uid))
	weapon = null
	items = [null, null]
	chest = restored
	changed.emit()
	return true
