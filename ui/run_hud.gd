class_name RunHud
extends TrainingHud

var run_text: Label
var inventory_text: Label
var interaction_text: Label
var modal: CenterContainer
var menu: VBoxContainer
var _modal_before_pause: bool = false
var _pause_active: bool = false

func _ready() -> void:
	run_mode = true
	super._ready()
	run_text = _label(right_panel, "准备 · 剩余复活 2", 16, Color(0.5, 0.9, 0.8))
	inventory_text = _label(left_panel, "", 14)
	interaction_text = _label(left_panel, "", 14, Color(1.0, 0.8, 0.4))
	modal = CenterContainer.new()
	modal.theme = THEME
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu = _panel(modal, 460)
	modal.visible = false

func show_run(session: RunSession) -> void:
	var names: Array[String] = ["准备", "战斗", "倒地复起", "自由搜刮", "装箱确认", "结果"]
	var seconds := ceili(maxf(0.0, session.time_limit - session.elapsed))
	run_text.text = "%s  %02d:%02d\n剩余复活 %d / 2" % [names[session.stage], floori(seconds / 60.0), seconds % 60, session.revives]
	if session.stage in [RunSession.Stage.LOOT, RunSession.Stage.CONFIRM]:
		run_text.text = "自由搜刮 · 不限时\n战斗 %.1f 秒 · 复活已用 %d" % [session.elapsed, 2 - session.revives]

func show_inventory(inventory: RunInventory) -> void:
	inventory_text.text = "武器  %s\n1  %s    2  %s" % [inventory.weapon.label() if inventory.weapon else "空", inventory.items[0].label() if inventory.items[0] else "空", inventory.items[1].label() if inventory.items[1] else "空"]

func open_menu(title: String, description: String) -> void:
	for child: Node in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	_label(menu, title, 26)
	var text := _label(menu, description, 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 420
	modal.visible = true

func action(text: String, callback: Callable) -> void:
	_button(menu, text, callback)

func close_menu() -> void:
	modal.visible = false

func show_paused(value: bool) -> void:
	super.show_paused(value)
	if _pause_active == value:
		return
	_pause_active = value
	if is_instance_valid(modal):
		if value:
			_modal_before_pause = modal.visible
			modal.visible = false
		elif _modal_before_pause:
			modal.visible = true
			_modal_before_pause = false
