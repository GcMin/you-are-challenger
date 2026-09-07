class_name RunItem
extends RefCounted

const NAMES: Dictionary = {&"sword": "双手大剑", &"potion": "恢复药", &"drink": "精力饮料"}
var uid: String
var kind: StringName

func _init(type: StringName = &"sword", identity: String = "") -> void:
	kind = type
	uid = identity if not identity.is_empty() else "%s_%s" % [Time.get_ticks_usec(), get_instance_id()]

func label() -> String:
	return NAMES.get(kind, "未知物品")

func serialize() -> Dictionary:
	return {"uid": uid, "kind": str(kind)}
