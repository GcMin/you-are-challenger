class_name TrainingHud
extends CanvasLayer

signal resume_requested
signal restart_requested
signal quit_requested

const THEME: Theme = preload("res://ui/training_theme.tres")
var health_bar: ProgressBar
var health_text: Label
var stamina_bar: ProgressBar
var stamina_text: Label
var target_bar: ProgressBar
var target_text: Label
var phase_text: Label
var notice: Label
var telegraph: Label
var telegraph_bar: ProgressBar
var pause_panel: Control
var pause_scrim: ColorRect
var hit_flash: ColorRect
var debug_text: Label
var _notice_left: float = 0.0
var _flash_left: float = 0.0
var boss_mode: bool = false
var run_mode: bool = false
var left_panel: VBoxContainer
var right_panel: VBoxContainer
var default_notice: String = "观察起手  ·  保留精力  ·  抓住收招"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var left := _panel(top, 315)
	left_panel = left
	_label(left, "YOU ARE CHALLENGER", 20)
	_label(left, "P0-3   /   单人挑战" if run_mode else "P0-2   /   平地 Boss 对练" if boss_mode else "P0-1   /   平地训练场", 14, Color(0.49, 0.81, 0.76))
	health_text = _label(left, "生命  100 / 100")
	health_bar = _bar(left, Color(0.87, 0.36, 0.27))
	stamina_text = _label(left, "精力  100 / 100")
	stamina_bar = _bar(left, Color(0.4, 0.79, 0.64))
	phase_text = _label(left, "移动 / 待机", 15)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	var right := _panel(top, 320)
	right_panel = right
	_label(right, "01  /  铁卫 · 大剑" if boss_mode else "01  /  人形训练靶", 20)
	target_text = _label(right, "生命  600 / 600")
	target_bar = _bar(right, Color(0.78, 0.6, 0.31))
	telegraph = _label(right, "Enter 开始 Boss 对练" if boss_mode else "静止训练靶", 16)
	telegraph_bar = _bar(right, Color(0.94, 0.49, 0.19))
	telegraph_bar.value = 0.0
	_label(right, "胜利后自由搜刮与装箱" if run_mode else "Enter  开始    F2  训练靶" if boss_mode else "T  循环攻击    Y  单次攻击    F2  Boss", 14)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(space)
	notice = _label(layout, "Enter 开始 · 横扫抢轻击，重砸抓重击" if boss_mode else "靠近训练靶，练习轻击、重击与翻滚", 21)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom := _panel(layout, 0)
	_label(bottom, "WASD  移动     鼠标  镜头     左键  轻击     右键  重击     空格  翻滚", 16)
	_label(bottom, "E  拾取 / 箱子    1 / 2  使用道具    Shift+1 / 2  替换栏位    Enter  开始 / 结束    Esc  暂停" if run_mode else "R  重置训练     F1  命中范围     Esc  暂停 / 释放鼠标", 14, Color(0.65, 0.75, 0.79))
	debug_text = _label(bottom, "轻击 22 / 10 精力    重击 48 / 20 精力    翻滚 25 精力    无敌 0.08—0.28 秒", 13, Color(0.49, 0.81, 0.76))
	hit_flash = ColorRect.new()
	root.add_child(hit_flash)
	hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_flash.color = Color(0.75, 0.07, 0.025, 0.0)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_scrim = ColorRect.new()
	root.add_child(pause_scrim)
	pause_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_scrim.color = Color(0.01, 0.02, 0.025, 0.65)
	pause_scrim.visible = false
	pause_panel = CenterContainer.new()
	root.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := _panel(pause_panel, 390)
	_label(menu, "挑战已暂停" if run_mode else "训练已暂停", 28)
	_label(menu, "调整节奏，再试一次。", 17)
	_button(menu, "继续挑战" if run_mode else "继续训练", func() -> void: resume_requested.emit())
	_button(menu, "重新开始本轮…" if run_mode else "重置训练", func() -> void: restart_requested.emit())
	_button(menu, "退出", func() -> void: quit_requested.emit())
	pause_panel.visible = false
	_ignore_overlay_mouse(margin)

func _panel(parent: Node, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _label(parent: Node, text: String, font_size: int = 17, color: Color = Color(0.9, 0.94, 0.95)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	parent.add_child(label)
	return label

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 9
	bar.value = 100.0
	var style := THEME.get_stylebox("fill", "ProgressBar").duplicate() as StyleBoxFlat
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)
	parent.add_child(bar)
	return bar

func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _ignore_overlay_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_overlay_mouse(child)

func show_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "生命  %d / %d" % [ceili(current), int(maximum)]

func show_paused(value: bool) -> void:
	pause_panel.visible = value
	pause_scrim.visible = value
	if value:
		var buttons := pause_panel.find_children("*", "Button", true, false)
		if not buttons.is_empty():
			(buttons[0] as Button).grab_focus()

func show_target(current: float, maximum: float) -> void:
	target_bar.max_value = maximum
	target_bar.value = current
	target_text.text = "生命  %d / %d" % [ceili(current), int(maximum)]

func show_status(text: String, stamina: float, maximum: float, invulnerable: bool) -> void:
	phase_text.text = text
	phase_text.modulate = Color(0.4, 1.0, 0.85) if invulnerable else Color.WHITE
	stamina_bar.max_value = maximum
	stamina_bar.value = stamina
	stamina_text.text = "精力  %d / %d" % [floori(stamina), int(maximum)]

func show_notice(message: String) -> void:
	notice.text = message
	_notice_left = 3.0

func show_telegraph(text: String, progress: float) -> void:
	telegraph.text = text
	telegraph_bar.value = progress * 100.0

func damage_feedback(data: DamageData, camera_basis: Basis, player_position: Vector3) -> void:
	_flash_left = 0.2
	var relative: Vector3 = camera_basis.inverse() * (data.origin - player_position)
	var direction: String = "左侧" if relative.x < 0.0 else "右侧"
	if absf(relative.z) > absf(relative.x):
		direction = "前方" if relative.z < 0.0 else "后方"
	show_notice("来自%s的攻击 · -%d HP" % [direction, int(data.amount)])

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_notice_left = maxf(0.0, _notice_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	hit_flash.color.a = _flash_left * 0.9
	if _notice_left <= 0.0:
		notice.text = default_notice
