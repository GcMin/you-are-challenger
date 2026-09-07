extends SceneTree

func _initialize() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "roll": KEY_SPACE, "pause": KEY_ESCAPE, "reset_training": KEY_R, "auto_attack": KEY_T, "single_attack": KEY_Y, "debug_hitbox": KEY_F1}
	for action: String in keys:
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": [key]})
	for action: String in ["light", "heavy"]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if action == "light" else MOUSE_BUTTON_RIGHT
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": [button]})
	ProjectSettings.save()
	quit()
