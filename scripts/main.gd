extends Control

const Soundscape = preload("res://scripts/soundscape.gd")
const Card = preload("res://scripts/plan_card.gd")
const Sim = preload("res://scripts/simulation_v5.gd")
const Portrait = preload("res://scripts/robot_portrait.gd")
const Board = preload("res://scripts/board.gd")
const BG = Color("080d18")
const PANEL = Color("101a2c")
const EDGE = Color("2c3d58")
const TEXT = Color("e5edfa")
const MUTED = Color("a1b2ca")
const GREEN = Color("80b9ff")
const SERIF = preload("res://assets/fonts/jetbrains-mono-bold.ttf")
const SANS = preload("res://assets/fonts/jetbrains-mono.ttf")
const SAVE_PATH = "user://silent_protocol_plan.json"
const TYPES = ["forward","backward","left","right","interact","noise","wait","send","wait_signal","timer","condition","repeat","if","while","select"]
const TYPE_LABELS = ["↑ Шаг вперёд","↓ Шаг назад","Налево · 90°","Направо · 90°","Взаимодействовать","Бросить шум","Ждать время","Сигнал да / нет","Ждать сигнал","Таймер","Ждать условие","Повторить N раз","Если / иначе","Повторять пока","Выбрать экспонат"]
const CONDITION_LABELS = ["Камера выключена","Лазер безопасен","Терминал готов","Дверь открыта","Охранник отвлечён","Охранник идёт на запад","Есть свободные предметы","Не всё доставлено","Сигнал включён","Сигнал выключен","Таймер истёк","Впереди свободно","Несу предмет","Окно камеры достаточно","Охранник в нише","Сигнал или всё доставлено","Всё доставлено","Рядом выбранный экспонат","На метке","Охранник осматривает шум","Охранник на посту","Шум готов","Плита занята","Охранник патрулирует","Охранник на паузе","Охранник возвращается","Охранник осматривает нишу","Охранник идёт на шум","Охранник смотрит на восток","Камера активна","Лазер включён","Охранник смотрит вдоль коридора"]
var stage_picker: OptionButton
var next_stage_button: Button
var chronicle_next_button: Button
var robustness_button: Button
var robust_label: Label
var target_selector: OptionButton
var target_x: SpinBox
var target_y: SpinBox
var coordinate_row: HBoxContainer
var target_values: Array = []
var chronicle: Control
var editor_panel: VBoxContainer
var steps_tab: Button
var chronicle_tab: Button
var result_mark: Control
var result_overlay: Control
var operation_title: Label
var operation_signals: Label
var operation_stage: Label
var operation_steps: Array[Label] = []
var last_outcome = "planning"
var tutorial: PanelContainer
var tutorial_title: Label
var tutorial_body: Label
var tutorial_animation: Control
var tutorial_next: Button
var tutorial_back: Button
var tutorial_page = -1
var tutorial_focus: Control
var insert_index = -1
var signal_value: CheckButton
var condition_negate: CheckButton
var level_picker: OptionButton
var lesson: Label
var timer_name: LineEdit
var level_plans: Array = [[[],[],[]],[[],[],[]],[[],[],[]],[[],[],[]],[[],[],[]],[[],[],[]],[[],[],[]],[[],[],[]],[[],[],[]]]

var sim = Sim.new()
var plan: Array = [[], [], []]
var selected = 0
var target = Vector2i(3, 3)
var accumulator = 0.0
var paused = false
var speed = 1
var replaying = false
var refreshing = false
var last_render_key = ""
var last_event_count = -1
var board: Control
var cards: VBoxContainer
var tabs: Array[Button] = []
var start_button: Button
var pause_button: Button
var reset_button: Button
var demo_button: Button
var clear_button: Button
var add_button: Button
var load_button: Button
var command_type: OptionButton
var signal_name: LineEdit
var seconds: SpinBox
var condition: OptionButton
var target_label: Label
var parameter_row: HBoxContainer
var portrait: Control
var robot_caption: Label
var time_label: Label
var phase_label: Label
var status_label: Label
var objective_label: Label
var signal_label: Label
var laser_label: Label
var log_box: RichTextLabel
var scrubber: HSlider
var scrub_label: Label
var toast: Label
var help_dialog: AcceptDialog
var save_button: Button
var modal_shade: ColorRect
var sound: Node
var composer: AcceptDialog
var action_buttons: Array[Button] = []
var action_description: Label
var editor_hint: Label
var add_step: Button
var undo_button: Button
var quick_targets: HBoxContainer
var signal_presets: OptionButton
var editing_index = -1
var picking_target = false
var history: Array = []
var card_scroll: ScrollContainer
var editor_title: Label
var composer_error: Label
var block_editor
var intro: Control
var show_intro_on_boot = true
var log_locale = ""
var records_path = "user://personal_bests.json"
var records
var coach
var reliability = preload("res://scripts/robustness_runner.gd").new()
var result_summary: Label
var result_scroll: ScrollContainer
var improve_button: Button
var result_actions: HBoxContainer
var status_scroll: ScrollContainer
var run_result: Dictionary = {}
var reference_signature = ""
var run_is_demo = false
var reliability_finished = false
var reliability_plan_signature = ""
var reliability_pause_button: Button
var reliability_stop_button: Button
var reliability_actions: HBoxContainer


func _ready() -> void:
	preload("res://scripts/localization.gd").install()
	add_child(preload("res://scripts/localization.gd").new())
	get_tree().root.gui_embed_subwindows = true
	sound = Soundscape.new()
	add_child(sound)
	records = preload("res://scripts/run_records.gd").new(records_path)
	_setup_theme()
	block_editor = preload("res://scripts/block_editor.gd").new(self)
	_build_ui()
	sim.reset(plan)
	board.sim = sim
	board.state = sim.view()
	_refresh_editor()
	_update_ui()
	_build_tutorial()
	coach = preload("res://scripts/tutorial_coach.gd").new(self)
	coach.build()
	if show_intro_on_boot and DisplayServer.get_name() != "headless" and "--demo" not in OS.get_cmdline_user_args() and "--autorun" not in OS.get_cmdline_user_args():
		_play_intro()
	# Optional reproducible UI smoke-test fixture.
	if "--demo" in OS.get_cmdline_user_args():
		_load_demo()
	if "--autorun" in OS.get_cmdline_user_args():
		_load_demo()
		_start()

func _setup_theme() -> void:
	var t = Theme.new()
	t.default_font_size = 16
	t.default_font = SANS
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("60718b"))
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _style(Color("17253d"), EDGE, 5))
		t.set_stylebox("hover", cls, _style(Color("243c5f"), Color("719ddd"), 5))
		t.set_stylebox("pressed", cls, _style(Color("244777"), GREEN, 5))
		t.set_stylebox("disabled", cls, _style(Color("101a2b"), Color("24334d"), 5))
		t.set_stylebox("focus", cls, _style(Color.TRANSPARENT, Color("a6cdff"), 5))
	t.set_stylebox("normal", "LineEdit", _style(BG, EDGE, 4))
	t.set_stylebox("focus", "LineEdit", _style(BG, GREEN, 4))
	t.set_stylebox("panel", "PopupMenu", _style(PANEL, EDGE, 6))
	t.set_stylebox("panel", "AcceptDialog", _style(PANEL, EDGE, 8))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("default_color", "RichTextLabel", MUTED)
	t.set_stylebox("slider", "HSlider", _style(Color("22334e"), EDGE, 1))
	t.set_stylebox("grabber_area", "HSlider", _style(Color("4c80c9"), GREEN, 1))
	t.set_stylebox("grabber_area_highlight", "HSlider", _style(GREEN, GREEN, 1))
	t.set_stylebox("scroll", "VScrollBar", _style(Color("0b1526"), Color("0b1526"), 1))
	t.set_stylebox("grabber", "VScrollBar", _style(Color("4f6b94"), Color("4f6b94"), 1))
	t.set_stylebox("grabber_highlight", "VScrollBar", _style(GREEN, GREEN, 1))
	t.set_stylebox("normal", "TextEdit", _style(BG, EDGE))
	t.set_stylebox("panel", "TooltipPanel", _style(PANEL, GREEN))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_selected_color", "PopupMenu", GREEN)
	t.set_stylebox("hover", "PopupMenu", _style(Color("253d5e"), GREEN))
	t.set_stylebox("separator", "HSeparator", _style(Color("253c5e"), Color("253c5e"), 0))
	# Thin metal rules rather than panel-sized default content margins.
	var rule = StyleBoxLine.new()
	rule.color = EDGE
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	for state_name in ["slider", "grabber_area", "grabber_area_highlight"]:
		var track = t.get_stylebox(state_name, "HSlider")
		track.content_margin_top = 2
		track.content_margin_bottom = 2
		track.content_margin_left = 0
		track.content_margin_right = 0
	for state_name in ["scroll", "grabber", "grabber_highlight"]:
		var track = t.get_stylebox(state_name, "VScrollBar")
		track.content_margin_left = 3
		track.content_margin_right = 3
	theme = t

func _style(fill: Color, border: Color = EDGE, radius: int = 5) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(mini(radius, 2))
	box.shadow_color = Color(0, 0, 0, 0.18)
	box.shadow_size = 3
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _label(value: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", maxi(14, font_size))
	if font_size >= 21:
		label.add_theme_font_override("font", SERIF)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String, action: Callable, min_width: float = 0) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(min_width, 36)
	b.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	b.pressed.connect(action)
	return b

func _style_dialog(dialog: Window) -> void:
	# Embedded windows keep the game's viewport scale, including in macOS fullscreen.
	var dialog_theme = theme.duplicate()
	dialog_theme.default_font = SANS
	dialog_theme.default_font_size = 18
	dialog_theme.set_font_size("title_font_size", "Window", 20)
	var frame = _style(PANEL, EDGE, 4)
	frame.content_margin_top = 32
	frame.expand_margin_top = 32
	frame.content_margin_bottom = 8
	frame.content_margin_left = 8
	frame.content_margin_right = 8
	dialog_theme.set_stylebox("embedded_border", "Window", frame)
	dialog_theme.set_stylebox("embedded_unfocused_border", "Window", frame)
	dialog_theme.set_color("title_color", "Window", TEXT)
	dialog.theme = dialog_theme
	_enlarge_dialog_text(dialog)

func _enlarge_dialog_text(node: Node) -> void:
	if node is Label:
		node.add_theme_font_size_override("font_size", maxi(18, node.get_theme_font_size("font_size")))
	elif node is RichTextLabel:
		for key in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
			node.add_theme_font_size_override(key, 18)
	elif node is Button or node is LineEdit:
		node.add_theme_font_size_override("font_size", 18)
		node.custom_minimum_size.y = maxf(42, node.custom_minimum_size.y)
	for child in node.get_children():
		_enlarge_dialog_text(child)

func _expand(node: Control) -> void:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _panel() -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL))
	return p

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var branding = VBoxContainer.new()
	_expand(branding)
	header.add_child(branding)
	branding.add_child(_label("ТИХИЙ ПРОТОКОЛ", 25))
	branding.tooltip_text = "Запрограммируйте команду. Запустите ограбление. Улучшите результат."
	level_picker = OptionButton.new()
	for i in Sim.LEVEL_NAMES.size(): level_picker.add_item("%d · %s" % [i+1, Sim.LEVEL_NAMES[i]])
	level_picker.item_selected.connect(_change_level)
	header.add_child(level_picker)
	stage_picker = OptionButton.new()
	for i in 6: stage_picker.add_item("Этап %d" % (i+1))
	stage_picker.item_selected.connect(_change_stage)
	header.add_child(stage_picker)
	var badge = _panel()
	badge.hide()
	header.add_child(badge)
	var badge_text = VBoxContainer.new()
	badge.add_child(badge_text)
	badge_text.add_child(_label("КОЛЛЕКЦИЯ  /  № 001", 10, GREEN))
	badge_text.add_child(_label("Слеза Лувра", 21))
	header.add_child(_button("Обучение", func(): _show_tutorial(-1), 100))
	header.add_child(_button("Правила", _show_help, 80))
	var audio_button = MenuButton.new()
	audio_button.text = "♫ Звук"
	audio_button.custom_minimum_size = Vector2(90, 36)
	var audio_menu = audio_button.get_popup()
	audio_menu.add_check_item("Атмосферная музыка", 0)
	audio_menu.add_check_item("Звуковые эффекты", 1)
	audio_menu.set_item_checked(0, true)
	audio_menu.set_item_checked(1, true)
	audio_menu.add_separator()
	audio_menu.add_item("Громкость: тихо", 3)
	audio_menu.add_item("Громкость: обычно", 4)
	audio_menu.id_pressed.connect(func(id):
		sound.activate()
		if id == 0:
			sound.music_enabled = not sound.music_enabled
			audio_menu.set_item_checked(0, sound.music_enabled)
		elif id == 1:
			sound.effects_enabled = not sound.effects_enabled
			audio_menu.set_item_checked(1, sound.effects_enabled)
		else:
			sound.volume = 0.35 if id == 3 else 0.65)
	header.add_child(audio_button)
	var languages = OptionButton.new()
	for language in ["Русский", "Қазақша", "English"]: languages.add_item(language)
	languages.select(maxi(0,["ru","kk","en"].find(TranslationServer.get_locale().substr(0,2))))
	languages.item_selected.connect(func(index): preload("res://scripts/localization.gd").set_language(["ru", "kk", "en"][index]))
	header.add_child(languages)
	var tool_panel = _panel()
	tool_panel.add_theme_stylebox_override("panel",_style(Color("0b1827"),Color("37626f"),3))
	root.add_child(tool_panel)
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	var desk = VBoxContainer.new()
	desk.add_theme_constant_override("separation",6)
	tool_panel.add_child(desk)
	var desk_label = _label("● SECURE LINK",12,Color("67c8be"))
	var desk_header = HBoxContainer.new()
	desk.add_child(desk_header)
	_expand(desk_label)
	desk_header.add_child(desk_label)
	desk.add_child(toolbar)
	phase_label = _label("● ПОДГОТОВКА", 12, GREEN)
	phase_label.custom_minimum_size.x = 175
	desk_header.add_child(phase_label)
	start_button = _button("▶", func():
		if sim.outcome == "running": _pause()
		else: _start(), 56)
	start_button.add_theme_stylebox_override("normal", _style(Color("153c43"), Color("70d5c2"),2))
	start_button.add_theme_color_override("font_color", Color("9cedd9"))
	toolbar.add_child(start_button)
	pause_button = _button("Ⅱ ПАУЗА", _pause, 112)
	toolbar.add_child(pause_button)
	pause_button.hide()
	reset_button = _button("", _reset, 56)
	reset_button.icon = load("res://assets/wrench.svg")
	reset_button.tooltip_text = "Изменить программу"
	toolbar.add_child(reset_button)
	var speed_button = _button("×1", func():
		speed = 2 if speed == 1 else 1
		_update_ui(), 56)
	speed_button.pressed.connect(func(): speed_button.text = "×%d" % speed)
	toolbar.add_child(speed_button)
	robustness_button = _button("Устойчивость", _check_robustness)
	toolbar.add_child(robustness_button)
	var toolbar_spacer = Control.new()
	_expand(toolbar_spacer)
	toolbar.add_child(toolbar_spacer)
	save_button = _button("Сохранить", _save_plan)
	toolbar.add_child(save_button)
	demo_button = _button("Показать решение", _run_reference)
	demo_button.tooltip_text = "Запустить готовое решение текущей карты."
	toolbar.add_child(demo_button)
	load_button = _button("Открыть", _load_plan)
	toolbar.add_child(load_button)
	time_label = _label("000.0 с", 21, TEXT)
	desk_header.add_child(time_label)
	var middle = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 14)
	root.add_child(middle)
	var left = VBoxContainer.new()
	_expand(left)
	left.add_theme_constant_override("separation", 10)
	middle.add_child(left)
	var map_panel = _panel()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(map_panel)
	var map_column = VBoxContainer.new()
	map_panel.add_child(map_column)
	var map_header = HBoxContainer.new()
	map_column.add_child(map_header)
	var map_title = _label("МУЗЕЙ", 12, MUTED)
	_expand(map_title)
	map_header.add_child(map_title)
	var routes = CheckButton.new()
	routes.text = "Путь"
	routes.tooltip_text = "Показывает запланированные шаги до первого условия или ожидания"
	routes.toggled.connect(func(value): board.show_routes = value)
	map_header.add_child(routes)
	var details = CheckButton.new()
	details.text = "Сетка"
	details.toggled.connect(func(value): board.show_details = value)
	map_header.add_child(details)
	board = Board.new()
	board.custom_minimum_size = Vector2(700, 320)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_clicked.connect(_choose_cell)
	board.robot_clicked.connect(_select_robot)
	map_column.add_child(board)
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	map_column.add_child(legend)
	legend.add_child(_label("◉ " + Sim.NAMES[0], 10, Sim.COLORS[0]))
	legend.add_child(_label("◈ " + Sim.NAMES[1], 10, Sim.COLORS[1]))
	legend.add_child(_label("▣ " + Sim.NAMES[2], 10, Sim.COLORS[2]))
	legend.add_child(_label("◆ ОХРАНА", 10, Color("ee9299")))
	var mission = _panel()
	left.add_child(mission)
	mission.hide()
	var mission_column = VBoxContainer.new()
	mission.add_child(mission_column)
	objective_label = _label("01  ЗАБРАТЬ АЛМАЗ A1        02  ВЫВЕСТИ ВСЕХ ТРОИХ", 12, TEXT)
	mission_column.add_child(objective_label)
	signal_label = _label("СИГНАЛЫ   /   пока нет сообщений", 12, MUTED)
	mission_column.add_child(signal_label)
	signal_label.hide()
	laser_label = _label("", 12)
	mission_column.add_child(laser_label)
	laser_label.hide()
	lesson = _label("", 12, MUTED)
	lesson.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(lesson)
	next_stage_button = _button("Следующий этап →", _advance_lesson)
	next_stage_button.custom_minimum_size.y = 46
	next_stage_button.add_theme_stylebox_override("normal", _style(Color("204b66"), GREEN))
	mission_column.add_child(next_stage_button)
	next_stage_button.hide()
	var right = _panel()
	right.custom_minimum_size.x = 520
	middle.add_child(right)
	var sidebar = VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 12)
	right.add_child(sidebar)
	var sidebar_tabs = HBoxContainer.new()
	sidebar.add_child(sidebar_tabs)
	steps_tab = _button("Шаги", _show_steps)
	chronicle_tab = _button("Хроника", _show_chronicle)
	for tab in [steps_tab, chronicle_tab]:
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sidebar_tabs.add_child(tab)
	steps_tab.set_pressed_no_signal(true)
	var sidebar_content = Control.new()
	sidebar_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_content.custom_minimum_size.y = 350
	sidebar.add_child(sidebar_content)
	var editor = VBoxContainer.new()
	editor_panel = editor
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.add_theme_constant_override("separation", 6)
	sidebar_content.add_child(editor)
	var editor_header = HBoxContainer.new()
	editor.add_child(editor_header)
	editor_header.hide()
	editor_title = _label("ПЛАН РОБОТА", 14, TEXT)
	_expand(editor_title)
	editor_header.add_child(editor_title)
	clear_button = _button("Очистить", _clear_robot)
	editor_header.add_child(clear_button)
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	editor.add_child(tab_row)
	for i in 3:
		var tab = _button(Sim.NAMES[i], _select_robot.bind(i))
		_expand(tab)
		tab_row.add_child(tab)
		tabs.append(tab)
	robot_caption = _label("", 12, MUTED)
	var identity = HBoxContainer.new()
	editor.add_child(identity)
	identity.hide()
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(34, 32)
	identity.add_child(portrait)
	robot_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expand(robot_caption)
	identity.add_child(robot_caption)
	var scroll = ScrollContainer.new()
	card_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 160
	editor.add_child(scroll)
	cards = VBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 2)
	_expand(cards)
	scroll.add_child(cards)
	status_label = _label("", 12, GREEN)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 34
	editor.add_child(status_label)
	var actions_row = HBoxContainer.new()
	editor.add_child(actions_row)
	add_step = _button("В конец ↓", block_editor.append_mode)
	_expand(add_step)
	actions_row.add_child(add_step)
	add_step.hide()
	undo_button = _button("↶ Отменить", _undo)
	actions_row.add_child(undo_button)
	clear_button.reparent(actions_row)
	editor_hint = _label("Линия вставки → место блока. Нажмите блок для параметров.", 11, MUTED)
	editor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(editor_hint)
	editor_hint.hide()
	modal_shade = ColorRect.new()
	modal_shade.color = Color(0.015, 0.025, 0.055, 0.55)
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.hide()
	add_child(modal_shade)
	composer = AcceptDialog.new()
	composer.title = "Добавить шаг"
	composer.get_ok_button().hide()
	composer.canceled.connect(_cancel_composer)
	add_child(composer)
	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	var form_scroll = ScrollContainer.new()
	form_scroll.custom_minimum_size = Vector2(750, 560)
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	composer.add_child(form_scroll)
	_expand(form)
	form_scroll.add_child(form)
	form.add_child(_label("Что должен сделать робот?", 20))
	var action_grid = GridContainer.new()
	action_grid.columns = 3
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	form.add_child(action_grid)
	var short_names = TYPE_LABELS
	for i in TYPES.size():
		var action = _button(short_names[i], _choose_action.bind(i), 175)
		action.custom_minimum_size.y = 32
		action_grid.add_child(action)
		action_buttons.append(action)
	action_description = _label("", 13, MUTED)
	action_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_description.custom_minimum_size = Vector2(520, 40)
	form.add_child(action_description)
	command_type = OptionButton.new()
	command_type.custom_minimum_size.y = 34
	for value in TYPE_LABELS:
		command_type.add_item(value)
	command_type.item_selected.connect(func(_index): _update_parameters())
	form.add_child(command_type)
	command_type.hide()
	parameter_row = HBoxContainer.new()
	parameter_row.custom_minimum_size.y = 34
	form.add_child(parameter_row)
	target_label = _label("", 13, Sim.COLORS[0])
	parameter_row.add_child(target_label)
	signal_name = LineEdit.new()
	signal_name.placeholder_text = "Имя сигнала, например ТЕМНО"
	signal_name.text = "ТЕМНО"
	signal_name.max_length = 24
	_expand(signal_name)
	parameter_row.add_child(signal_name)
	seconds = SpinBox.new()
	seconds.min_value = 0.1
	seconds.max_value = Sim.MAX_SECONDS
	seconds.step = 0.1
	seconds.value = 1
	seconds.suffix = "с"
	_expand(seconds)
	parameter_row.add_child(seconds)
	condition = OptionButton.new()
	condition.item_selected.connect(func(_i): _update_parameters())
	for caption in CONDITION_LABELS: condition.add_item(caption)
	_expand(condition)
	parameter_row.add_child(condition)
	condition_negate = CheckButton.new()
	condition_negate.text = "НЕ — ждать обратное состояние"
	form.add_child(condition_negate)
	signal_value = CheckButton.new()
	signal_value.text = "Включён (да)"
	signal_value.button_pressed = true
	signal_value.toggled.connect(func(value): signal_value.text = "Включён (да)" if value else "Выключен (нет)")
	form.add_child(signal_value)
	timer_name = LineEdit.new()
	timer_name.placeholder_text = "Имя личного таймера"
	timer_name.text = "T"
	form.add_child(timer_name)
	target_selector = OptionButton.new()
	target_selector.item_selected.connect(func(_i): _update_parameters())
	form.add_child(target_selector)
	coordinate_row = HBoxContainer.new()
	form.add_child(coordinate_row)
	coordinate_row.add_child(_label("X",14))
	target_x = SpinBox.new()
	target_x.max_value = 29
	coordinate_row.add_child(target_x)
	coordinate_row.add_child(_label("Y",14))
	target_y = SpinBox.new()
	target_y.max_value = 19
	coordinate_row.add_child(target_y)
	coordinate_row.add_child(_button("Выбрать на карте", _pick_on_map))
	add_button = _button("+  Добавить команду", _add_command)
	form.add_child(add_button)
	quick_targets = HBoxContainer.new()
	form.add_child(quick_targets)
	
	signal_presets = OptionButton.new()
	signal_presets.add_item("Выберите сигнал команды или введите новый выше")
	signal_presets.item_selected.connect(func(index):
		if index > 0:
			signal_name.text = signal_presets.get_item_text(index))
	form.add_child(signal_presets)
	composer_error = _label("", 12, Color("ee9384"))
	composer_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(composer_error)
	form.move_child(add_button, form.get_child_count() - 1)
	form.add_child(_button("Отмена", _cancel_composer))
	chronicle = Control.new()
	chronicle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chronicle.hide()
	sidebar_content.add_child(chronicle)
	var bottom_column = VBoxContainer.new()
	bottom_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom_column.add_theme_constant_override("separation", 8)
	chronicle.add_child(bottom_column)
	var result_row = HBoxContainer.new()
	bottom_column.add_child(result_row)
	result_mark = preload("res://scripts/result_mark.gd").new()
	result_mark.custom_minimum_size = Vector2(64,64)
	result_row.add_child(result_mark)
	operation_title = _label("Операция в эфире",20)
	operation_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expand(operation_title)
	result_row.add_child(operation_title)
	status_scroll = ScrollContainer.new()
	status_scroll.custom_minimum_size.y = 100
	status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_column.add_child(status_scroll)
	var status_column = VBoxContainer.new()
	_expand(status_column)
	status_scroll.add_child(status_column)
	for i in 3:
		var row = _label("",13,Sim.COLORS[i])
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_column.add_child(row)
		operation_steps.append(row)
	operation_stage = _label("",12,GREEN)
	operation_stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_column.add_child(operation_stage)
	robust_label = _label("",13,MUTED)
	robust_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_column.add_child(robust_label)
	operation_signals = _label("",12,MUTED)
	operation_signals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_column.add_child(operation_signals)
	result_summary = _label("", 15, TEXT)
	result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_scroll = ScrollContainer.new()
	result_scroll.custom_minimum_size.y = 130
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_column.add_child(result_scroll)
	_expand(result_summary)
	result_scroll.add_child(result_summary)
	result_scroll.hide()
	result_actions = HBoxContainer.new()
	bottom_column.add_child(result_actions)
	improve_button = _button("Улучшить программу →", _improve_program)
	_expand(improve_button)
	result_actions.add_child(improve_button)
	result_actions.hide()
	reliability_actions = HBoxContainer.new()
	bottom_column.add_child(reliability_actions)
	reliability_pause_button = _button("Ⅱ Проверка", func(): reliability.paused = not reliability.paused)
	reliability_stop_button = _button("Вернуть результат", _stop_reliability)
	reliability_actions.add_child(reliability_pause_button)
	reliability_actions.add_child(reliability_stop_button)
	reliability_actions.hide()
	bottom_column.add_child(HSeparator.new())
	var replay_row = HBoxContainer.new()
	bottom_column.add_child(replay_row)
	scrubber = HSlider.new()
	scrubber.min_value = 0
	scrubber.max_value = 1
	scrubber.step = 1
	_expand(scrubber)
	scrubber.value_changed.connect(_scrub)
	replay_row.add_child(scrubber)
	scrub_label = _label("00.0 с", 12, GREEN)
	scrub_label.custom_minimum_size.x = 70
	replay_row.add_child(scrub_label)
	replay_row.add_child(_button("В эфир", _live))
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.set_meta("localization_manual", true)
	log_box.custom_minimum_size.y = 100
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 16)
	log_box.meta_clicked.connect(func(meta):
		if sim.tick > 0:
			paused = true
			_scrub(float(str(meta)))
			for event in sim.events:
				if event.tick==int(str(meta)) and event.robot>=0:
					selected=event.robot;board.selected=selected
					board.preview_cell=board.state.robots[selected].pos
					_refresh_editor();break)
	bottom_column.add_child(log_box)
	chronicle_next_button = _button("Следующий этап →", _advance_lesson)
	chronicle_next_button.add_theme_stylebox_override("normal", _style(Color("204b66"), GREEN))
	bottom_column.add_child(chronicle_next_button)
	chronicle_next_button.hide()
	result_overlay = preload("res://scripts/result_mark.gd").new()
	result_overlay.full_window = true
	result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.hide()
	chronicle.add_child(result_overlay)
	block_editor.build(root)
	toast = _label("Соберите программу или запустите решение текущего этапа. Движение задаётся шагами и поворотами.", 12, MUTED)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(toast)
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Лувр · Инструкция к ограблению"
	help_dialog.dialog_text="РОБОТЫ НЕ БЛОКИРУЮТ ДРУГ ДРУГА\nШаг: 10 тиков/клетку; с предметом: 20. Поворот: 5 тиков. Взаимодействие с витриной: 40.\nЧтобы доставить предмет, выполните взаимодействие в зоне E/X.\n\nКООПЕРАЦИЯ\nПлита держит дверь, пока занята. Кнопка тяжёлой двери действует 5–6 с (зависит от уровня).\nРобот в проёме задерживает закрытие тяжёлой двери на уровнях 1–3.\nФинал: дверь галереи закрывается строго по таймеру, даже в занятом проёме.\nПервое нажатие — в первые 60 тиков после взлома T_S; повторное — до закрытия.\nТерминал отключает свою защиту временно, затем перезаряжается.\nАктивное окно повторным взломом не продлевается.\n\nОХРАНА\nКонус 90°, длина 3–5 клеток.\nОбнаружение: 12 тиков видимости; вне обзора шкала убывает на 2 за тик.\nШум бросается в видимую клетку до 5 клеток. Радиус слуха 8.\nДлительность осмотра зависит от уровня. Перезарядка шума: 200 тиков.\n\nПРОГРАММЫ\nСигналы доставляются на следующем тике. Состояние устройств проверяйте\nусловиями напрямую. «Лазер безопасен» проверяет остаток окна\nна заданное время: при пересечении клетки учитывайте вход И выход.\n«Выбрать экспонат» резервирует ближайший свободный предмет.\n\nТУТОРИАЛ\nШесть отдельных комнат. Все инструменты доступны внизу; каждый этап учит новому приёму.\n«Показать решение» запускает эталон. Смена этапа — сверху.\nНочная смена: три сценария. Нулевая минута: четыре сценария после победы."
	help_dialog.ok_button_text = "Понятно, за работу"
	var help_copy = help_dialog.dialog_text
	help_dialog.dialog_text = ""
	var help_text = RichTextLabel.new()
	help_text.text = help_copy.replace("Смена этапа — сверху.", "После победы нажмите «Следующий этап» в хронике или под картой.")
	help_text.text += "\n\nКОМПОНЕНТЫ И ЛИЦЕНЗИИ\nGodot Engine · JetBrains Mono\n"
	for license_file in ["res://licenses/Godot-LICENSE.txt", "res://licenses/Godot-COPYRIGHT.txt", "res://assets/fonts/JetBrainsMono-OFL.txt"]:
		help_text.text += "\n" + FileAccess.get_file_as_string(license_file) + "\n"
	help_text.custom_minimum_size = Vector2(770, 570)
	help_dialog.add_child(help_text)
	add_child(help_dialog)
	_enlarge_dialog_text(chronicle)
	for dialog in [composer, help_dialog]:
		_style_dialog(dialog)

func _process(delta: float) -> void:
	if is_instance_valid(intro): return
	if coach != null: coach.update(delta)
	if reliability.active:
		_tick_reliability(delta)
		return
	block_editor.drag_scroll(delta)
	if sim.outcome == "running" and not paused and not replaying:
		accumulator += minf(delta, 0.25) * speed
		while accumulator >= Sim.STEP:
			accumulator -= Sim.STEP
			sim.step()
			if sim.outcome != "running":
				accumulator = 0
				break
	if not replaying:
		board.state = sim.view()
	board.running_animation = sim.outcome == "running" and not paused and not replaying
	board.frame_alpha = accumulator / Sim.STEP if not replaying else 0.0
	sound.update_audio(sim, paused, replaying, delta)
	_update_ui()

func _select_robot(id: int) -> void:
	_cancel_composer()
	selected = id
	board.selected = id
	portrait.robot_id = id
	_refresh_editor()

func _choose_cell(cell: Vector2i) -> void:
	if not picking_target and block_editor.pick_noise(cell): return
	if sim.outcome != "planning" or not picking_target:return
	var index = editing_index
	_open_composer(index)
	command_type.select(TYPES.find("noise"))
	target_selector.select(0)
	target_x.value=cell.x
	target_y.value=cell.y
	_update_parameters()

func _update_parameters() -> void:
	if not is_instance_valid(target_selector): return
	var kind = TYPES[maxi(0,command_type.selected)]
	var conditional = kind in ["condition","if","while"]
	var cond = Sim.CONDITIONS[maxi(0,condition.selected)]
	condition.visible=conditional
	condition_negate.visible=conditional
	signal_name.visible=kind in ["send","wait_signal"] or (conditional and cond in ["signal_on","signal_off","ready_or_done"])
	signal_value.visible=kind in ["send","wait_signal"]
	timer_name.visible=kind=="timer" or (conditional and cond=="timer_done")
	seconds.visible=kind in ["wait","timer","repeat"] or (conditional and cond in ["laser_safe","camera_safe","guard_distracted"])
	seconds.max_value=Sim.MAX_REPEAT if kind=="repeat" else Sim.MAX_SECONDS
	seconds.step=1 if kind=="repeat" else .05
	seconds.min_value=1 if kind=="repeat" else (0 if conditional else .05)
	seconds.suffix="раз" if kind=="repeat" else "с"
	target_selector.visible=kind=="interact" or (conditional and cond in ["laser_safe","terminal_ready","door_open","at_marker","camera_off","camera_safe"])
	coordinate_row.visible=kind=="noise"
	target_label.hide();quick_targets.hide();signal_presets.visible=signal_name.visible
	add_button.disabled=sim.outcome!="planning"
	add_button.text="Сохранить блок" if editing_index>=0 else "+ Добавить блок"
	action_description.text={"forward":"Одна клетка по стрелке робота. 0,5 с без добычи, 1 с с добычей. Стены сами не обходит.","backward":"Одна клетка назад без разворота. 0,5 с без добычи, 1 с с добычей.","left":"Повернуться на 90° против часовой стрелки. Занимает 0,25 с.","right":"Повернуться на 90° по часовой стрелке. Занимает 0,25 с.","interact":"У кнопки — открыть дверь; у терминала — взломать; рядом с витриной — взять; на выходе — положить.","noise":"Бросок в видимую клетку до 5 клеток. Слух охранника 8 клеток, осмотр 6 с, перезарядка 10 с.","select":"Закрепить ближайший свободный экспонат. Приближайтесь шагами и проверяйте «Рядом выбранный экспонат».","wait":"Ожидание заданного времени.","send":"Общий переключатель; доставка на следующем тике.","wait_signal":"Ожидать заданное состояние переключателя.","timer":"Личный таймер работает параллельно программе.","condition":"Ожидать состояние мира. Для окна задайте время, нужное на пересечение.","repeat":"Выполнить вложенные блоки N раз.","if":"Выбрать одну из двух веток по состоянию мира.","while":"Проверять условие перед каждым повторением."}[kind]
	var unlocked = block_editor.unlocked()
	for i in action_buttons.size():
		action_buttons[i].visible = TYPES[i] in unlocked
		action_buttons[i].add_theme_stylebox_override("normal",_style(_block_color(TYPES[i]).darkened(.6),GREEN if i==command_type.selected else EDGE))

func _add_command() -> void:
	if sim.outcome != "planning": return
	var kind = TYPES[command_type.selected]
	var c = {"type":kind}
	if kind in ["if","while","condition"]:
		c.condition = Sim.CONDITIONS[condition.selected]
		c.negate = condition_negate.button_pressed
		if c.condition in ["laser_safe","camera_safe","guard_distracted"]: c.ticks=roundi(seconds.value*20)
		if c.condition in ["laser_safe","terminal_ready","door_open","at_marker","camera_off","camera_safe"]:
			var device=target_values[target_selector.selected]
			var valid = false
			if c.condition=="laser_safe":valid=sim.lasers.any(func(l):return l.id==device)
			elif c.condition in ["camera_off","camera_safe"]:valid=device=="all_cameras" or sim.cameras.any(func(cam):return cam.id==device)
			else:valid=not sim.object(device).is_empty() and sim.object(device).type=={"terminal_ready":"terminal","door_open":"door","at_marker":"marker"}[c.condition]
			if not valid:composer_error.text="Выберите нужное устройство в списке целей";return
			if device!="all_cameras":c.device=device
	if kind=="noise":
		c.target=[int(target_x.value),int(target_y.value)]
	if kind=="interact" and target_selector.selected>0:
		var object_id=target_values[target_selector.selected]
		if object_id=="exit":pass # Delivery is implicit when standing on an exit.
		elif object_id=="selected" or sim.objects.any(func(o):return o.id==object_id and o.type in ["terminal","button","item"]):c.object=object_id
		else:composer_error.text="Выберите кнопку, терминал, экспонат или объект рядом";return
	if signal_name.visible:
		if signal_name.text.strip_edges().is_empty():
			composer_error.text = "Введите имя сигнала"
			return
		c.signal = signal_name.text.strip_edges()
	if kind in ["send","wait_signal"]: c.value = signal_value.button_pressed
	if timer_name.visible:
		if timer_name.text.strip_edges().is_empty():
			composer_error.text = "Введите имя таймера"
			return
		c.timer = timer_name.text.strip_edges()
	if kind in ["timer","wait"]: c.seconds = seconds.value
	if kind == "repeat": c.count = maxi(1,int(seconds.value))
	_remember()
	if editing_index >= 0:
		var old = plan[selected][editing_index].type
		if old in ["if","repeat","while"] and old != kind:
			history.pop_back()
			composer_error.text = "У блока с вложенными командами меняйте параметры. Для смены типа удалите его целиком."
			return
		if old not in ["if","repeat","while"] and kind in ["if","repeat","while"]:
			plan[selected].remove_at(editing_index)
			_insert_structure(c,editing_index)
		else: plan[selected][editing_index] = c
	else:
		_insert_structure(c,insert_index if insert_index >= 0 else plan[selected].size())
	_cancel_composer()
	_plan_changed()

func _insert_structure(c: Dictionary,index: int) -> void:
	plan[selected].insert(index,c)
	if c.type in ["if","repeat","while"]:
		plan[selected].insert(index+1,{"type":"end"})
		if c.type == "if": plan[selected].insert(index+1,{"type":"else"})

func _plan_changed() -> void:
	last_outcome = "planning"
	result_overlay.set_result("planning")
	reliability.cancel()
	reliability_finished = false
	run_result.clear()
	board.sim = sim
	if is_instance_valid(result_summary): result_summary.hide();result_scroll.hide()
	sim.reset(plan)
	board.state = sim.view()
	board.snap_visuals = true
	board.frame_alpha = 0
	sound.reset_history()
	board.plans = plan
	last_event_count = -1
	_refresh_editor()

func _refresh_editor() -> void:
	block_editor.prepare()
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var editable = sim.outcome == "planning"
	for i in 3:
		tabs[i].disabled = i not in sim.active_ids
		tabs[i].add_theme_color_override("font_color", Sim.COLORS[i])
		tabs[i].add_theme_stylebox_override("normal", _style(Color("233b5b") if i == selected else Color("142238"), Sim.COLORS[i] if i == selected else EDGE))
	robot_caption.text = "%d блоков · взгляд %s" % [plan[selected].size(), ["→ восток","↓ юг","← запад","↑ север"][board.state.robots[selected].facing]]
	editor_title.text = "ПЛАН: " + Sim.NAMES[selected]
	var depth = 0
	for index in plan[selected].size():
		var command: Dictionary = plan[selected][index]
		var active: bool = sim.outcome != "planning" and board.state.robots[selected].pc == index
		if command.type in ["end","else"]: depth = maxi(0,depth-1)
		block_editor.add_slot(index, depth)
		var p = Card.new()
		p.index = index
		p.robot_id = selected
		p.editable = editable and command.type not in ["end","else"]
		p.moved.connect(_move_card)
		p.accepts = block_editor.can_insert
		p.caption = _command_label(command)
		p.dropped.connect(block_editor.insert)
		var block_style = _style(_block_color(command.type).darkened(0.65 if not active else 0.35), _block_color(command.type), 6)
		block_style.content_margin_top = 4
		block_style.content_margin_bottom = 4
		block_style.border_width_left = 5
		block_style.content_margin_left = 10 + depth * 17
		p.add_theme_stylebox_override("panel", block_style)
		cards.add_child(p)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var contents = VBoxContainer.new()
		p.add_child(contents)
		contents.add_child(row)
		var handle = _label("⠿ %02d" % (index + 1), 11, Sim.COLORS[selected] if active else MUTED)
		handle.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(handle)
		var text = _button(_command_label(command), block_editor.toggle_parameters.bind(index))
		text.disabled = not editable or command.type in ["end","else"]
		text.alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_theme_font_size_override("font_size", 16)
		text.clip_text = true
		text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		text.tooltip_text = _command_label(command) + "\n\nНажмите для параметров. Перетаскивайте за заголовок. Цикл переносится вместе с содержимым."
		text.mouse_entered.connect(func(): board.preview_cell = _command_target(command))
		text.mouse_exited.connect(func(): board.preview_cell = Vector2i(-1, -1))
		_expand(text)
		row.add_child(text)
		for spec in [["↑", -1], ["↓", 1], ["×", 0]]:
			var b = _button(spec[0], _edit_card.bind(index, spec[1]))
			b.custom_minimum_size = Vector2(24, 25)
			var small_style = _style(Color("1c2f4b"), Color("3b5274"), 3)
			small_style.content_margin_left = 5
			small_style.content_margin_right = 5
			small_style.content_margin_top = 1
			small_style.content_margin_bottom = 1
			b.add_theme_stylebox_override("normal", small_style)
			b.disabled = not editable or command.type in ["end","else"] or (spec[1] == -1 and index == 0) or (spec[1] == 1 and index == plan[selected].size() - 1)
			row.add_child(b)
		p.wire_drag_targets(row)
		block_editor.parameters(contents, index)
		if block_editor.scroll_to == index:
			block_editor.reveal.call_deferred(index)
		if command.type in ["if","repeat","while","else"]: depth += 1
	block_editor.add_slot(plan[selected].size(), 0, plan[selected].is_empty())
	block_editor.scroll_to = -1
	board.plans = plan
	_update_parameters()

func _command_label(c:Dictionary)->String:
	match c.type:
		"forward": return "↑ Шаг вперёд · 0,5 / 1 с"
		"backward": return "↓ Шаг назад · 0,5 / 1 с"
		"left": return "Налево · 0,25 с"
		"right": return "Направо · 0,25 с"
		"interact": return "Взаимодействовать · "+str(c.get("object","рядом / выход"))
		"noise": return "Шум → "+str(c.target)
		"select": return "Выбрать ближайший свободный"
		"repeat": return "Повторить %d раз" % c.count
		"end": return "└ Конец блока"
		"else": return "Иначе"
		"wait": return "Ждать %.2f с" % (c.get("ticks",c.get("seconds",1)*20)/20.0)
		"timer": return "Таймер %s: %.2f с" % [c.timer,c.seconds]
		"send","wait_signal":return ("Установить " if c.type=="send" else "Ждать ")+c.signal+(" = да" if c.get("value",true) else " = нет")
		"condition","if","while":
			var index=Sim.CONDITIONS.find(c.get("condition",""))
			return {"condition":"Ждать: ","if":"Если ","while":"Пока "}[c.type]+("НЕ " if c.get("negate",false) else "")+(CONDITION_LABELS[index] if index>=0 else "условие")+" "+str(c.get("device",c.get("signal",c.get("timer",""))))+(" · через %.2f с"%(float(c.after_ticks)/20) if c.get("after_ticks",0)>0 else "")
	return c.type

func _edit_card(index: int, direction: int) -> void:
	if sim.outcome != "planning": return
	if direction == 0:
		_remember()
		var end = Sim._matching(plan[selected],index,false) if plan[selected][index].type in ["if","while","repeat"] else index
		for i in range(end,index-1,-1): plan[selected].remove_at(i)
		_plan_changed()
	else:
		var destination = index + direction
		if direction > 0 and plan[selected][index].type in ["if","while","repeat"]:
			destination = Sim._matching(plan[selected],index,false) + 1
		if direction > 0 and destination < plan[selected].size() and plan[selected][destination].type in ["if","while","repeat"]:
			destination = Sim._matching(plan[selected],destination,false)
		elif direction < 0 and destination >= 0 and plan[selected][destination].type == "end":
			destination = Sim._opening(plan[selected],destination)
		if destination >= 0 and destination < plan[selected].size(): _move_card(index,destination)

func _clear_robot() -> void:
	if sim.outcome == "planning":
		_remember()
		plan[selected] = []
		_plan_changed()

func _load_demo() -> void:
	if sim.outcome != "planning":
		return
	_remember()
	plan = sim.solution()
	reference_signature = records.signature(plan)
	_plan_changed()
	toast.text = "Эталон загружен. Можно менять блоки и наблюдать результат."

func _start() -> void:
	if sim.outcome in ["won", "lost"]: _reset()
	if sim.outcome != "planning":
		return
	var errors = Sim.validate(plan)
	if not errors.is_empty():
		toast.text = errors[0]
		return
	_cancel_composer()
	sound.activate()
	sound.reset_history()
	sim.reset(plan)
	sim.start()
	run_is_demo = records.signature(plan) == reference_signature
	run_result.clear()
	_show_chronicle()
	if tutorial: tutorial.hide()
	paused = false
	replaying = false
	accumulator = 0
	board.state = sim.view()
	_refresh_editor()
	toast.text = "Операция идёт автономно. Пауза и ×2 доступны. Изменить программу можно с помощью ключа."

func _reset() -> void:
	_stop_reliability(false)
	_cancel_composer()
	paused = false
	replaying = false
	accumulator = 0
	_plan_changed()
	_show_steps()
	_update_ui()
	toast.text = "Мир восстановлен. Команды сохранены — исправьте план и попробуйте ещё раз."

func _pause() -> void:
	if sim.outcome == "running":
		if replaying:
			_live()
		paused = not paused

func _live() -> void:
	if reliability.active: return
	replaying = false
	board.snap_visuals = true
	board.state = sim.view()
	last_render_key = ""

func _scrub(value: float) -> void:
	if reliability.active: return
	if refreshing or sim.tick == 0:
		return
	paused = true
	replaying = true
	board.snap_visuals = true
	board.frame_alpha = 0
	board.state = sim.snapshots[clampi(int(value), 0, sim.snapshots.size() - 1)]
	last_render_key = ""

func _update_ui() -> void:
	if reliability.active: return
	if board == null or board.state.is_empty():
		return
	var editable = sim.outcome == "planning"
	start_button.disabled = false
	reset_button.disabled = false
	start_button.text = "Ⅱ" if sim.outcome == "running" and not paused else "▶"
	start_button.tooltip_text = "Пауза" if sim.outcome == "running" and not paused else "Выполнить"
	pause_button.disabled = sim.outcome != "running"
	pause_button.text = "▶  Продолжить" if paused else "Ⅱ  Пауза"
	clear_button.disabled = not editable
	add_step.disabled = not editable
	undo_button.disabled = not editable or history.is_empty()
	demo_button.disabled = not editable
	load_button.disabled = not editable
	command_type.disabled = not editable
	signal_name.editable = editable
	seconds.editable = editable
	condition.disabled = not editable
	_update_parameters()
	level_picker.disabled = sim.outcome == "running"
	demo_button.visible = true
	stage_picker.visible = sim.level == 0
	stage_picker.disabled = sim.outcome == "running"
	var next_available = sim.level == 0 and sim.outcome == "won"
	for button in [next_stage_button, chronicle_next_button]:
		button.visible = next_available
		button.text = "К ограблению: Закрытая галерея →" if sim.stage == 5 else "Следующий этап %d/6 →" % (sim.stage + 2)
	if sim.stage == 5:chronicle_next_button.text = "К ограблению →"
	robustness_button.visible = sim.level >= 2
	robustness_button.disabled = sim.outcome != "won"
	robustness_button.text = "Устойчивость %d×"%sim.data.get("scenarios",[]).size()
	lesson.text = _lesson_text()
	var phase = "● ПОДГОТОВКА"
	var phase_color = GREEN
	match sim.outcome:
		"running": phase = "Ⅱ ПАУЗА" if paused else "● В ЭФИРЕ"
		"won": phase = "✓ ОПЕРАЦИЯ УСПЕШНА"
		"lost":
			phase = "! ТРЕВОГА / ПРОВАЛ"
			phase_color = Color("ee9384")
	if replaying:
		phase = "↶ ПРОСМОТР ЗАПИСИ"
	phase_label.text = phase
	phase_label.add_theme_color_override("font_color", phase_color)
	time_label.text = "%05.1f с" % (board.state.tick * Sim.STEP)
	status_label.visible = sim.outcome != "planning"
	status_label.text = board.state.robots[selected].status
	for key in board.state.timers[selected]:
		status_label.text += " · %s: %.1f с" % [key, maxf(0,(board.state.timers[selected][key] - board.state.tick) * Sim.STEP)]
	status_label.add_theme_color_override("font_color", Color("ee9384") if board.state.robots[selected].blocked else Sim.COLORS[selected])
	var delivered=board.state.objects.filter(func(o):return o.type=="item" and o.delivered).size()
	var total=sim.items().size()
	var evacuated=sim.active_ids.filter(func(i):return board.state.robots[i].pos in sim.exits()).size()
	objective_label.text="Доставлено: %d/%d    •    На выходе: %d/%d" % [delivered,total,evacuated,sim.active_ids.size()]
	laser_label.text="Скорость: 0,5 с/клетку    •    С добычей: 1 с/клетку"
	for i in 3:
		operation_steps[i].visible=i in sim.active_ids
		operation_steps[i].text="%s · %d/%d · %s" % [Sim.NAMES[i],mini(board.state.robots[i].pc+1,plan[i].size()),plan[i].size(),board.state.robots[i].status]
	var flags:Array[String]=[]
	for key in board.state.signals:flags.append(key+(" = да" if board.state.signals[key] else " = нет"))
	operation_signals.text="Сигналы: "+("нет" if flags.is_empty() else " · ".join(flags))
	operation_stage.text=sim.data.name+" · доставлено %d/%d" % [delivered,total]
	result_mark.set_result(board.state.outcome)
	operation_title.text = {"planning":"Готовность к запуску","running":"Операция в эфире","won":"Экспонат у команды","lost":"Операция сорвана"}[sim.outcome]
	if replaying:operation_title.text = "Запись · %.2f с" % (board.state.tick * Sim.STEP)
	elif sim.level == 0 and sim.outcome == "won":
		operation_title.text = "Этап %d из 6 завершён" % (sim.stage + 1)
	if sim.outcome != last_outcome:
		last_outcome = sim.outcome
		if sim.outcome in ["won","lost"]:
			if sim.outcome == "won": run_result = records.finish(sim, plan, not run_is_demo)
			_show_chronicle()
		result_overlay.set_result(sim.outcome)
	_refresh_results()
	refreshing = true
	scrubber.max_value = maxi(1, sim.snapshots.size() - 1)
	scrubber.editable = sim.tick > 0
	if not replaying:
		scrubber.value = sim.tick
	scrub_label.text = "%04.1f с" % (board.state.tick * Sim.STEP)
	refreshing = false
	var render_key = "%s/%d/%d/%s" % [sim.outcome, selected, board.state.robots[selected].pc, replaying]
	if render_key != last_render_key:
		last_render_key = render_key
		_refresh_editor()
	var locale_changed = log_locale != TranslationServer.get_locale()
	if locale_changed:
		log_locale = TranslationServer.get_locale()
		last_event_count = -1
	if sim.events.size() != last_event_count:
		var begin = maxi(0, last_event_count)
		if last_event_count <= 0 or last_event_count > sim.events.size():
			log_box.clear()
			begin = 0
		last_event_count = sim.events.size()
		if sim.events.is_empty():
			log_box.append_text("[color=#a1b2ca]Система готова. Каждое событие операции появится здесь. Нажмите событие для разбора.[/color]")
		for event in sim.events.slice(begin):
			var color = "#ee9384" if event.kind in ["lost", "blocked"] else ("#80b9ff" if event.kind == "won" else "#b4c8e5")
			var escaped_text: String = preload("res://scripts/localization.gd").text(str(event.message)).replace("[", "[lb]")
			log_box.append_text("[url=%d][color=%s]%05.1f   %s[/color][/url]\n" % [event.tick, color, event.tick * Sim.STEP, escaped_text])
		if sim.outcome == "won":
			toast.text = "УСПЕХ · %.1f секунды · %d команд. Вся команда дома. Попробуйте сократить время или число команд!" % [sim.tick * Sim.STEP, records.command_count(plan)]
		elif sim.outcome == "lost":
			toast.text = "Провал — это информация. Нажмите красное событие или перемотайте запись. Нажмите «Исправить программу» или ключ, чтобы продолжить."

func _save_plan(path: String = SAVE_PATH) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		toast.text = "Не удалось сохранить план: %s" % error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"version": 6, "level":sim.level, "stage":sim.stage, "plans": plan, "layout":records.key(sim), "assisted": records.signature(plan)==reference_signature}, "  "))
	toast.text = "План сохранён локально. Кнопка «Открыть» восстановит его после перезапуска."

func _load_plan(path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		toast.text = "Сохранённого плана пока нет. Сначала нажмите «Сохранить»."
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		toast.text = "Не удалось прочитать сохранённый план."
		return
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		toast.text = "Сохранение повреждено. Текущий план сохранён."
		return
	var data = parser.data
	if not data is Dictionary or data.get("version") != 6 or data.get("level", -1) != sim.level or data.get("stage",0) != sim.stage or not data.get("plans") is Array:
		toast.text = "Этот план относится к другой миссии или старой планировке. Откройте соответствующий уровень; старые маршруты несовместимы."
		return
	if sim.level==3 and data.get("layout","")!=records.key(sim):
		toast.text="Этот план относится к другой миссии или старой планировке. Откройте соответствующий уровень; старые маршруты несовместимы."
		return
	var errors = Sim.validate(data.plans, true)
	if not errors.is_empty():
		toast.text = "Сохранение не загружено: " + errors[0]
		return
	_remember()
	plan = data.plans
	if data.get("assisted",false):reference_signature=records.signature(plan)
	_plan_changed()
	toast.text = "Сохранённый план восстановлен."

func _show_help() -> void:
	if reliability.active: reliability.paused=true
	if sim.outcome == "running":
		paused = true
	help_dialog.popup_centered(Vector2i(820, 720))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080d18"))
	# Engraved architectural frame, kept outside interactive controls.
	for inset in [7.0, 11.0]:
		draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), Color("243b60"), false, 1)
	for x in [11.0, size.x - 11.0]:
		for y in [11.0, size.y - 11.0]:
			draw_circle(Vector2(x, y), 2, Color("779ed6"))

func _place_name(cell: Vector2i) -> String:
	if cell == sim.terminal:
		return "терминал камер"
	if cell == sim.laser_terminal:
		return "терминал лазеров"
	if cell == sim.artifact:
		return "витрина: " + sim.layout.prize
	if cell == sim.exit_cell:
		return "выход"
	if cell == sim.noise_point:
		return "комната отвлечения"
	return "точка %d:%d" % [cell.x, cell.y]

func _planned_position() -> Vector2i:
	var position = Vector2i(3, 11 + selected)
	var end = editing_index if editing_index >= 0 else plan[selected].size()
	for i in end:
		if plan[selected][i].type == "move":
			position = Sim.to_cell(plan[selected][i].target)
	return position

func _remember() -> void:
	history.append(plan.duplicate(true))
	if history.size() > 40:
		history.pop_front()

func _undo() -> void:
	if sim.outcome == "planning" and not history.is_empty():
		_cancel_composer()
		plan = history.pop_back()
		_plan_changed()
		toast.text = "Последнее изменение отменено."

func _move_card(source: int, destination: int) -> void:
	if sim.outcome != "planning" or source == destination or source<0 or source>=plan[selected].size() or destination<0 or destination>=plan[selected].size(): return
	var end = Sim._matching(plan[selected],source,false) if plan[selected][source].type in ["if","repeat","while"] else source
	if destination > source and destination <= end: return
	var candidate = plan.duplicate(true)
	var chunk = candidate[selected].slice(source,end+1)
	for i in range(end,source-1,-1): candidate[selected].remove_at(i)
	if destination > end: destination -= chunk.size()-1
	for i in chunk.size(): candidate[selected].insert(destination+i,chunk[i])
	if not Sim.validate(candidate).is_empty():
		toast.text = "Перемещайте блок целиком или используйте + внутри нужной ветки."
		return
	_remember()
	plan = candidate
	_plan_changed()

func _open_composer(index: int = -1) -> void:
	if sim.outcome != "planning":
		return
	if index >= 0 and (plan[selected][index].has("all") or plan[selected][index].has("any")):
		toast.text = "Составное условие сохранено. Палитра редактирует одиночные условия; используйте вложенные «Если»."
		return
	sound.activate()
	target_selector.clear()
	target_values=["cell","exit","selected","all_cameras"]
	for label in ["Объект рядом","Зона выхода","Выбранный экспонат","Все камеры"]: target_selector.add_item(label)
	for o in sim.objects:
		if o.type=="exit":continue
		target_values.append(o.id)
		target_selector.add_item({"terminal":"Терминал","button":"Кнопка","plate":"Плита","door":"Дверь","item":"Экспонат","marker":"Метка"}[o.type]+" · "+o.id+" "+str(o.pos))
	for laser in sim.lasers:
		target_values.append(laser.id);target_selector.add_item("Лазер "+laser.id)
	for cam in sim.cameras:
		target_values.append(cam.id);target_selector.add_item("Камера "+cam.id)
	condition_negate.button_pressed = false
	editing_index = index
	picking_target = false
	board.pick_target = false
	composer_error.text = ""
	composer.title = ("Изменить шаг %d" % (index + 1) if index >= 0 else "Новый шаг") + " · " + Sim.NAMES[selected]
	if index >= 0:
		var command: Dictionary = plan[selected][index]
		var destination=command.get("target",command.get("object",command.get("device","cell")))
		if destination is Array:
			target_x.value=destination[0];target_y.value=destination[1];target_selector.select(0)
		else:target_selector.select(maxi(0,target_values.find(destination)))
		command_type.select(maxi(0,TYPES.find(command.type)))
		if command.type in ["condition","if","while"]:
			condition.select(maxi(0,Sim.CONDITIONS.find(command.get("condition","front_clear"))))
			if command.get("condition","") in ["camera_off","camera_safe"] and not command.has("device"):target_selector.select(target_values.find("all_cameras"))
		_update_parameters()
		seconds.value=command.get("ticks",0)/20.0 if command.type in ["condition","if","while"] else 1
		if command.has("ticks"):seconds.value=command.ticks/20.0
		if command.type == "repeat": seconds.value = command.count
		if command.type == "timer":
			seconds.value = command.seconds
			timer_name.text = command.timer
		if command.type in ["send", "wait_signal", "link"]:
			signal_name.text = command.signal
			signal_value.button_pressed = command.get("value",true)
		if command.type == "wait":
			seconds.value = command.get("seconds",command.get("ticks",20)/20.0)
		if command.type in ["condition","if","while"]:
			condition_negate.button_pressed = command.get("negate",false)
			condition.select(maxi(0,Sim.CONDITIONS.find(command.get("condition","camera_off"))))
			signal_name.text = command.get("signal","ГОТОВ")
			timer_name.text = command.get("timer","T")
	else:
		command_type.select(0)
		condition.select(Sim.CONDITIONS.find("front_clear"))
		_update_parameters()
		seconds.value=1
		target = sim.exit_cell
	var suggestions: Array[String] = ["ПЛИТА_ДЕРЖИТСЯ", "НОСИТЕЛЬ_ГОТОВ", "ОКНО_ГОТОВО", "ДОБЫЧА_ВЫНЕСЕНА"]
	for commands in plan:
		for command in commands:
			if command.type in ["send", "wait_signal"] and command.signal not in suggestions:
				suggestions.append(command.signal)
	signal_presets.clear()
	signal_presets.add_item("Выбрать сигнал команды…")
	for value in suggestions:
		signal_presets.add_item(value)
	_update_parameters()
	modal_shade.show()
	composer.popup_centered(Vector2i(790, 690))

func _choose_action(index: int) -> void:
	command_type.select(index)
	composer_error.text = ""
	_update_parameters()

func _pick_on_map() -> void:
	composer.hide()
	modal_shade.hide()
	picking_target = true
	board.pick_target = true
	toast.text = "Выберите место броска шума. Движение на карте не задаётся. Escape — отмена."

func _cancel_composer() -> void:
	if is_instance_valid(composer):
		composer.hide()
		modal_shade.hide()
	editing_index = -1
	insert_index = -1
	picking_target = false
	if is_instance_valid(board):
		board.pick_target = false

func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(card_scroll):
		card_scroll.scroll_vertical = int(card_scroll.get_v_scroll_bar().max_value)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and block_editor != null:
		block_editor.pointer = event.position

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_composer()
		block_editor.expanded = -1
		_refresh_editor()
		toast.text = "Выбор отменён."
		if tutorial: tutorial.hide()

func _command_target(command: Dictionary) -> Vector2i:
	if command.type == "move":
		return Sim.to_cell(command.target)
	return {"hack": sim.terminal, "hack_lasers": sim.laser_terminal, "take": sim.artifact}.get(command.type, Vector2i(-1, -1))

func _open_inside(index: int) -> void:
	_open_composer()
	insert_index = index

func _block_color(kind: String) -> Color:
	if kind in ["forward","backward","left","right"]: return Color("4d9eff")
	if kind in ["repeat","if","else","end","while"]: return Color("d59a35")
	if kind in ["send","wait_signal","link"]: return Color("bf83ed")
	if kind in ["timer","wait","condition"]: return Color("58b7b0")
	return Color("df7196")


func _draft_key()->int:return sim.stage if sim.level==0 else sim.level+5
func _change_level(index:int)->void:
	if index<0 or index>=Sim.LEVEL_NAMES.size():return
	level_plans[_draft_key()]=plan.duplicate(true)
	_cancel_composer();history.clear();sim.set_level(index)
	plan=level_plans[_draft_key()].duplicate(true);level_picker.select(index);stage_picker.select(0);selected=sim.active_ids[0];board.selected=selected;_reset()
func _change_stage(index:int)->void:
	if index<0 or index>=6:return
	level_plans[_draft_key()]=plan.duplicate(true)
	_cancel_composer();history.clear();sim.set_level(0,index)
	plan=level_plans[_draft_key()].duplicate(true);level_picker.select(0);stage_picker.select(index);selected=sim.active_ids[0];board.selected=selected;_reset()
func _advance_lesson()->void:
	if sim.level != 0 or sim.outcome != "won":return
	if sim.stage < 5:_change_stage(sim.stage + 1)
	else:_change_level(1)
	if sim.level==0 and coach!=null:coach.active=true;coach.update(0)
	toast.text = "Новый этап: " + sim.data.name + ". " + sim.data.hint
	_update_ui()

func _lesson_text()->String:
	return ("Этап %d из 6 · %s\n" % [sim.stage + 1, sim.data.name] if sim.level == 0 else "") + sim.data.hint
func _show_steps()->void:
	if not reliability.active and sim.outcome == "lost":
		_reset()
		return
	chronicle.hide()
	editor_panel.show()
	steps_tab.set_pressed_no_signal(true)
	chronicle_tab.set_pressed_no_signal(false)

func _show_chronicle()->void:
	_cancel_composer()
	editor_panel.hide()
	chronicle.show()
	steps_tab.set_pressed_no_signal(false)
	chronicle_tab.set_pressed_no_signal(true)

func _run_reference()->void:
	_load_demo();_start()
func _check_robustness()->void:
	if sim.outcome != "won" or not reliability.start(sim,plan): return
	reliability_finished = false
	reliability_plan_signature = records.signature(plan)
	_show_chronicle()
	result_overlay.hide()
	for button in [start_button,pause_button,reset_button,robustness_button,save_button,demo_button,load_button,level_picker,stage_picker,steps_tab,improve_button,chronicle_next_button]:button.disabled=true
	for tile in block_editor.tiles:tile.disabled=true
	scrubber.editable=false
	scrubber.get_parent().hide()
	result_actions.hide();status_scroll.hide();result_summary.show();reliability_actions.show()
	sound.reset_history()
	_tick_reliability(0)

func _tick_reliability(delta:float) -> void:
	reliability.step(delta)
	board.sim=reliability.probe
	board.state=reliability.probe.view()
	board.frame_alpha=0
	board.running_animation=not reliability.paused and reliability.hold<=0
	var delivered=board.state.objects.filter(func(o):return o.type=="item" and o.delivered).size()
	var total=reliability.probe.items().size()
	var evacuated=reliability.probe.active_ids.filter(func(i):return board.state.robots[i].pos in reliability.probe.exits()).size()
	objective_label.text="Доставлено: %d/%d    •    На выходе: %d/%d"%[delivered,total,evacuated,reliability.probe.active_ids.size()]
	toast.text="Проверяем одну программу при разных фазах защиты. Можно приостановить проверку или вернуть исходный результат."
	phase_label.text="ПРОВЕРКА %d/%d · ×8"%[reliability.scenario+1,reliability.scenario_count]
	time_label.text="%05.1f с"%(reliability.probe.tick*Sim.STEP)
	operation_title.text="Одна программа · %d сценария"%reliability.scenario_count
	result_summary.text=reliability.status_text()
	reliability_pause_button.text="▶ Продолжить" if reliability.paused else "Ⅱ Пауза проверки"
	result_mark.set_result(reliability.probe.outcome)
	log_box.clear()
	for event in reliability.probe.events.slice(maxi(0,reliability.probe.events.size()-5)):
		log_box.append_text("%.1f  %s\n"%[event.tick*Sim.STEP,str(event.message).replace("[","[lb]")])
	if not reliability.active:
		reliability_finished=true
		records.reliability(sim,plan,reliability.successes(),not run_is_demo)
		_stop_reliability(true)

func _stop_reliability(keep_result:bool=true) -> void:
	reliability.cancel()
	if not keep_result:reliability_finished=false
	board.sim=sim;board.state=sim.view();board.snap_visuals=true
	if not is_instance_valid(reliability_actions):return
	scrubber.get_parent().show()
	reliability_actions.hide();steps_tab.disabled=false;save_button.disabled=false;reset_button.disabled=false;improve_button.disabled=false;chronicle_next_button.disabled=false
	last_event_count=-1;last_render_key=""
	_update_ui()

func _refresh_results() -> void:
	var won=sim.outcome=="won" and not replaying
	result_scroll.visible=won
	result_summary.visible=won
	result_actions.visible=(sim.outcome in ["won","lost"]) and not replaying
	if sim.outcome=="lost":
		improve_button.text="Исправить программу →"
	status_scroll.visible=not won
	if not won:return
	result_scroll.custom_minimum_size.y=200 if reliability_finished else 130
	if run_result.is_empty():run_result=records.finish(sim,plan,false)
	var previous:Dictionary=run_result.previous
	var count=int(run_result.blocks)
	var text="Время  %.2f с    ·    Команд  %d\n"%[sim.tick*Sim.STEP,count]
	if run_is_demo:
		text+="Эталон · без личного рекорда. Измените программу и попробуйте превзойти её."
	elif previous.is_empty():
		text+="Первый личный рекорд! Теперь попробуйте улучшить время или сократить программу."
	else:
		var difference=(sim.tick-int(previous.ticks))*Sim.STEP
		text+=("Новый рекорд времени! " if run_result.new_time else "Лучшее время: %.2f с. "%[float(previous.ticks)*Sim.STEP])
		text+="%+.2f с · %+d команд к лучшим результатам."%[difference,count-int(previous.blocks)]
		if run_result.new_size:text+=" Новый рекорд компактности!"
	if reliability_finished and reliability_plan_signature==records.signature(plan):
		text+="\nУстойчивость: %d/%d\n"%[reliability.successes(),sim.data.scenarios.size()]+reliability.status_text()
	elif sim.level>=2:
		var saved=records.best(sim)
		if saved.get("reliable_signature","")==records.signature(plan):text+="\nСохранённая устойчивость этой программы: %d/%d"%[int(saved.get("reliable_count",0)),sim.data.scenarios.size()]
		else:text+="\nПроверьте устойчивость: та же программа, три фазы защиты."
	elif sim.level==0 and sim.stage==0:text+="\nЭксперимент: 3 отдельных шага быстрее цикла, но требуют больше команд."
	if not records.save_error.is_empty():text+="\n"+records.save_error
	result_summary.text=text
	improve_button.text="Улучшить программу →"
	# The detailed event log remains scrollable below the compact results.

func _improve_program() -> void:
	if reliability.active:return
	var failed = -1
	var failed_pc = -1
	if sim.outcome=="lost":
		for id in sim.active_ids:
			if sim.robots[id].blocked or sim.robots[id].detection>=12:
				failed=id;failed_pc=sim.robots[id].pc;break
	_reset()
	if failed>=0:
		_select_robot(failed)
		block_editor.expanded=clampi(failed_pc,0,plan[failed].size()-1) if not plan[failed].is_empty() else -1
		block_editor.scroll_to=block_editor.expanded
		_refresh_editor()
	toast.text="План сохранён. Измените его и сравните новую попытку с личным рекордом."

func _build_tutorial()->void:
	tutorial=_panel();tutorial.position=Vector2(50,235);tutorial.size=Vector2(560,270);add_child(tutorial)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);tutorial.add_child(column)
	column.add_child(_label("ПЕРВАЯ ПРОГРАММА ЗА МИНУТУ",24,GREEN))
	var text=_label("Лувр должен открыть дверь и выйти. Соберите четыре команды с подсказками, запустите их и посмотрите, как робот справится сам. Затем улучшите результат. Остальные пять уроков объяснят защиту и кооперацию.",17)
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size=Vector2(530,110);column.add_child(text)
	column.add_child(_button("Начать · ~1 минута",func():tutorial.hide();coach.start();level_picker.select(0)))
	column.add_child(_button("Пропустить → Закрытая галерея",func():tutorial.hide();_change_level(1);level_picker.select(1)))
	tutorial.hide()
func _show_tutorial(_page:int=-1)->void:
	if reliability.active: reliability.paused=true
	if sim.outcome=="running":paused=true
	tutorial.show()
func _close_tutorial()->void:tutorial.hide()

func _play_intro() -> void:
	if is_instance_valid(intro): return
	tutorial.hide()
	board.tooltip_text = ""
	intro = preload("res://scripts/intro.gd").new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.finished.connect(_finish_intro)
	add_child(intro)
	intro.grab_focus()

func _finish_intro() -> void:
	var closing = intro
	intro = null
	if is_instance_valid(closing):
		closing.hide()
		closing.queue_free()
	sound.activate()
	_show_tutorial(-1)
