extends RefCounted
## Scratch-style toolbox, insertion boundaries and an inline parameter inspector.
const Tile = preload("res://scripts/command_tile.gd")
const Slot = preload("res://scripts/command_slot.gd")
const Sim = preload("res://scripts/simulation_v5.gd")
const GROUPS = [
	["Ход", ["forward","backward","left","right"]],
	["Действия", ["interact","noise","select"]],
	["Логика", ["condition","repeat","if","while"]],
	["Связь", ["wait","timer","send","wait_signal"]]
]
var game
var palette: VBoxContainer
var tiles: Array = []
var categories: Array = []
var category = 0
var cursor = -1
var expanded = -1
var scroll_to = -1
var robot = -1
var context = ""
var fields: Dictionary = {}
var pointer = Vector2(-1000,-1000)

func _init(host): game = host

func build(parent: VBoxContainer) -> void:
	palette = VBoxContainer.new()
	palette.add_theme_constant_override("separation", 5)
	parent.add_child(palette)
	palette.add_child(game._label("ИНСТРУМЕНТЫ   /   Перетащите блок в программу · нажмите блок, чтобы изменить параметры", 14, game.MUTED))
	var grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	palette.add_child(grid)
	for i in game.TYPES.size():
		var tile = Tile.new()
		tile.command_type = game.TYPES[i]
		tile.text = ["↑ Вперёд", "↓ Назад", "Налево · 90°", "Направо · 90°", "Взаимодействие", "Бросить шум", "Ждать время", "Сигнал да / нет", "Ждать сигнал", "Таймер", "Ждать условие", "Повторить N", "Если / иначе", "Пока условие", "Выбрать экспонат"][i]
		tile.custom_minimum_size.y = 32
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override("font_size", 15)
		tile.allowed = func(): return game.sim.outcome == "planning"
		tile.tooltip_text = game.TYPE_LABELS[i] + "\nПеретащите между блоками или нажмите для вставки. Параметры меняются прямо в карточке."
		tile.mouse_default_cursor_shape = Control.CURSOR_DRAG
		var style = game._style(game._block_color(tile.command_type).darkened(.65), game._block_color(tile.command_type))
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		tile.add_theme_stylebox_override("normal", style)
		tile.pressed.connect(add_from_palette.bind(tile.command_type))
		tile.drag_started.connect(game._show_steps)
		grid.add_child(tile)
		tiles.append(tile)

func unlocked() -> Array:
	return game.TYPES.duplicate()

# Kept for old callers; all categories now share one visible shelf.
func choose_category(value: int) -> void:
	category = value
	refresh_palette()

func refresh_palette() -> void:
	for tile in tiles:
		tile.visible = true
		tile.disabled = game.sim.outcome != "planning"

func prepare() -> void:
	var next_context = "%s/%s" % [game.sim.level, game.sim.stage]
	if robot != game.selected or context != next_context:
		robot = game.selected
		context = next_context
		cursor = -1
		expanded = -1
		fields = {}
	cursor = mini(cursor, game.plan[game.selected].size())
	if expanded >= game.plan[game.selected].size(): expanded = -1
	refresh_palette()

func choose_slot(boundary: int) -> void:
	if game.sim.outcome != "planning": return
	cursor = boundary
	expanded = -1
	game._refresh_editor()
	game.editor_hint.text = "Следующий блок появится здесь. Нажмите команду в палитре."

func append_mode() -> void:
	choose_slot(game.plan[game.selected].size())
	game.card_scroll.set_deferred("scroll_vertical", int(game.card_scroll.get_v_scroll_bar().max_value))

func add_slot(boundary: int, depth: int, empty: bool = false) -> void:
	var slot = Slot.new()
	slot.boundary = boundary
	slot.accepts = can_insert
	slot.received.connect(insert)
	slot.chosen = boundary == cursor
	slot.custom_minimum_size.y = 68 if empty else 10
	var style = StyleBoxFlat.new()
	style.bg_color = Color("122137")
	style.content_margin_left = 10 + depth * 17
	slot.add_theme_stylebox_override("panel", style)
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			choose_slot(boundary))
	if boundary == game.plan[game.selected].size():
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = 68 if empty else 28
	if empty:
		var label = game._label("Перетащите первый блок сюда\nили нажмите команду в палитре", 14, game.MUTED)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
	game.cards.add_child(slot)

func default_command(kind: String) -> Dictionary:
	var command = {"type":kind}
	match kind:
		"repeat": command.count = 3
		"wait": command.seconds = 1.0
		"timer": command.merge({"timer":"T1", "seconds":1.0})
		"send","wait_signal": command.merge({"signal":"ГОТОВ", "value":true})
		"condition","if","while": command.condition = "front_clear"
		"noise":
			var pos = game.sim.robots[game.selected].pos
			command.target = [pos.x, pos.y]
	return command

func candidate(data, boundary: int) -> Array:
	if game.sim.outcome != "planning" or not data is Dictionary: return []
	var program: Array = game.plan[game.selected]
	if boundary < 0 or boundary > program.size(): return []
	var result: Array = game.plan.duplicate(true)
	var chunk: Array = []
	match data.get("kind", ""):
		"new_command":
			if data.get("type", "") not in unlocked(): return []
			chunk.append(default_command(data.type))
			if data.type == "if": chunk.append({"type":"else"})
			if data.type in ["repeat","while","if"]: chunk.append({"type":"end"})
		"plan_step":
			if data.get("robot", -1) != game.selected or not data.get("index") is int: return []
			var source: int = data.index
			if source < 0 or source >= program.size() or program[source].type in ["else","end"]: return []
			var end = Sim._matching(program,source,false) if program[source].type in ["repeat","if","while"] else source
			if boundary >= source and boundary <= end + 1: return []
			chunk = result[game.selected].slice(source,end+1)
			for i in range(end,source-1,-1): result[game.selected].remove_at(i)
			if boundary > end: boundary -= chunk.size()
		_: return []
	for i in chunk.size(): result[game.selected].insert(boundary+i, chunk[i])
	return result if Sim.validate(result, true).is_empty() else []

func can_insert(data, boundary: int) -> bool:
	return not candidate(data, boundary).is_empty()

func insert(data, boundary: int) -> void:
	var result = candidate(data, boundary)
	if result.is_empty(): return
	game._remember()
	game.plan = result
	expanded = -1
	if data.kind == "new_command":
		cursor = boundary + 1
		expanded = boundary if data.type not in ["forward","backward","left","right","select"] else -1
		scroll_to = boundary
	else:
		cursor = -1
	game._plan_changed()

func add_from_palette(kind: String) -> void:
	if game.sim.outcome == "planning": game._show_steps()
	insert({"kind":"new_command", "type":kind}, game.plan[game.selected].size() if cursor < 0 else cursor)

func toggle_parameters(index: int) -> void:
	if game.sim.outcome != "planning": return
	if game.plan[game.selected][index].type in ["else","end"]: return
	expanded = -1 if expanded == index else index
	cursor = index + 1
	game._refresh_editor()
	reveal.call_deferred(index)

func row(parent: VBoxContainer, label: String) -> HBoxContainer:
	var line = HBoxContainer.new()
	parent.add_child(line)
	var title = game._label(label, 14, game.MUTED)
	title.custom_minimum_size.x = 94
	line.add_child(title)
	return line

func number(parent: HBoxContainer, value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var field = SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 112
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func line_edit(parent: HBoxContainer, value: String) -> LineEdit:
	var field = LineEdit.new()
	field.text = value
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func parameters(parent: VBoxContainer, index: int) -> void:
	if index != expanded or game.sim.outcome != "planning": return
	var c: Dictionary = game.plan[game.selected][index]
	if c.type in ["forward","backward","left","right","select"]: return
	if c.has("all") or c.has("any"):
		var note = game._label("Составное условие: параметры сохранены.",14,game.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(note)
		return
	var f = {"index":index, "robot":game.selected, "command":c.duplicate(true)}
	fields = f
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	if c.type in ["condition","if","while"]:
		var condition = OptionButton.new()
		for title in game.CONDITION_LABELS: condition.add_item(title)
		condition.fit_to_longest_item = false
		condition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		condition.select(maxi(0,Sim.CONDITIONS.find(c.get("condition","front_clear"))))
		box.add_child(condition)
		f.condition = condition
		var negate = CheckButton.new()
		negate.text = "НЕ · инвертировать условие"
		negate.button_pressed = c.get("negate",false)
		box.add_child(negate)
		f.negate = negate
	var amount_row = row(box, "Количество" if c.type == "repeat" else "Время, с")
	f.amount_row = amount_row
	f.amount = number(amount_row, c.get("count",c.get("ticks",c.get("seconds",0.0 if c.type in ["condition","if","while"] else 1.0)*20)/20.0), 1 if c.type == "repeat" else 0, Sim.MAX_REPEAT if c.type == "repeat" else Sim.MAX_SECONDS, 1 if c.type == "repeat" else .05)
	f.after_row = row(box, "Через, с")
	f.after = number(f.after_row, float(c.get("after_ticks",0))/20, 0, Sim.MAX_SECONDS, .05)
	f.name_row = row(box, "Имя")
	f.name = line_edit(f.name_row, str(c.get("signal",c.get("timer","ГОТОВ"))))
	f.value = CheckButton.new()
	f.value.text = "Включён / да"
	f.value.button_pressed = c.get("value",true)
	box.add_child(f.value)
	f.device_row = row(box, "Объект")
	f.device = OptionButton.new()
	f.device.fit_to_longest_item = false
	f.device.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.device_row.add_child(f.device)
	if c.type == "noise":
		var coords = row(box, "Цель X / Y")
		f.x = number(coords, c.target[0], 0, game.sim.width-1, 1)
		f.y = number(coords, c.target[1], 0, game.sim.height-1, 1)
		var hint = game._label("Кликните клетку на карте, чтобы задать цель шума.",14,game.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
	f.error = game._label("",14,Color("ee9384"))
	f.error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.error.hide()
	box.add_child(f.error)
	var buttons = HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(game._button("Применить", apply_fields.bind(f)))
	buttons.add_child(game._button("Свернуть", toggle_parameters.bind(index)))
	if f.has("condition"): f.condition.item_selected.connect(func(_id): update_fields(f, false))
	update_fields(f, true)

func update_fields(f: Dictionary, restore: bool) -> void:
	var c: Dictionary = f.command
	var cond = Sim.CONDITIONS[f.condition.selected] if f.has("condition") else ""
	f.amount_row.visible = c.type in ["repeat","wait","timer"] or cond in ["laser_safe","camera_safe","guard_distracted"]
	f.after_row.visible = cond in ["laser_safe","camera_safe"]
	f.amount.min_value = 1 if c.type == "repeat" else (.05 if c.type in ["wait","timer"] else 0)
	f.name_row.visible = c.type in ["send","wait_signal","timer"] or cond in ["signal_on","signal_off","ready_or_done","timer_done"]
	if not restore: f.name.text = "T1" if cond == "timer_done" else "ГОТОВ"
	f.value.visible = c.type in ["send","wait_signal"]
	f.device_row.visible = c.type == "interact" or cond in ["laser_safe","camera_off","camera_safe","terminal_ready","door_open","at_marker","plate_occupied","camera_active","laser_on"]
	f.device.clear()
	f.devices = []
	if c.type == "interact":
		f.devices.append(""); f.device.add_item("Рядом / доставка на выходе")
		f.devices.append("selected"); f.device.add_item("Выбранный экспонат")
	if cond in ["camera_off","camera_safe","camera_active"]:
		f.devices.append(""); f.device.add_item("Все камеры")
	var objects: Array = game.sim.objects
	if cond in ["laser_safe","laser_on"]: objects = game.sim.lasers
	elif cond in ["camera_off","camera_safe","camera_active"]: objects = game.sim.cameras
	for obj in objects:
		var type = obj.get("type", "")
		if c.type == "interact" and type not in ["terminal","button","item"]: continue
		if cond in ["terminal_ready","door_open","at_marker","plate_occupied"] and type != {"terminal_ready":"terminal","door_open":"door","at_marker":"marker","plate_occupied":"plate"}[cond]: continue
		f.devices.append(obj.id)
		f.device.add_item(str(obj.id))
	if restore:
		var selected_device = f.devices.find(c.get("device",c.get("object","")))
		if selected_device >= 0: f.device.select(selected_device)

func apply_fields(f: Dictionary) -> void:
	if game.sim.outcome != "planning" or game.selected != f.robot: return
	var c: Dictionary = f.command.duplicate(true)
	match c.type:
		"repeat": c.count = int(f.amount.value)
		"wait","timer":
			c.erase("ticks")
			c.seconds = f.amount.value
		"noise": c.target = [int(f.x.value),int(f.y.value)]
		"condition","if","while":
			var next_condition = Sim.CONDITIONS[f.condition.selected]
			if c.get("condition", "") != next_condition:
				for key in ["device","signal","timer","ticks","after_ticks"]: c.erase(key)
			c.condition = next_condition
			c.negate = f.negate.button_pressed
			if c.condition in ["laser_safe","camera_safe","guard_distracted"]: c.ticks = roundi(f.amount.value*20)
	if f.after_row.visible and (f.after.value>0 or c.has("after_ticks")): c.after_ticks = roundi(f.after.value*20)
	if f.name_row.visible:
		c["timer" if c.type == "timer" or c.get("condition", "") == "timer_done" else "signal"] = f.name.text.strip_edges()
	if f.value.visible: c.value = f.value.button_pressed
	if f.device_row.visible:
		if f.device.selected < 0:
			f.error.text = "На этом этапе нет подходящего устройства."
			f.error.show()
			return
		var key = "object" if c.type == "interact" else "device"
		c.erase(key)
		if not f.devices[f.device.selected].is_empty(): c[key] = f.devices[f.device.selected]
	var result: Array = game.plan.duplicate(true)
	result[game.selected][f.index] = c
	var errors = Sim.validate(result,true)
	if not errors.is_empty():
		f.error.text = " · ".join(errors)
		f.error.show()
		return
	if result != game.plan:
		game._remember()
		game.plan = result
	expanded = -1
	game._plan_changed()

func pick_noise(cell: Vector2i) -> bool:
	if expanded < 0 or fields.get("index",-1) != expanded or fields.is_empty() or not is_instance_valid(fields.get("x")) or fields.command.type != "noise": return false
	if game.sim.outcome != "planning" or fields.robot != game.selected: return false
	fields.x.value = cell.x
	fields.y.value = cell.y
	game.board.preview_cell = cell
	return true

func drag_scroll(delta: float) -> void:
	if not game.get_viewport().gui_is_dragging() or not game.editor_panel.is_visible_in_tree(): return
	var scroll: ScrollContainer = game.card_scroll
	var mouse = scroll.get_global_transform_with_canvas().affine_inverse() * pointer
	if mouse.x < 0 or mouse.x > scroll.size.x: return
	if mouse.y >= -24 and mouse.y < 38: scroll.scroll_vertical -= maxi(1,roundi(480*delta))
	elif mouse.y > scroll.size.y-38 and mouse.y <= scroll.size.y+24: scroll.scroll_vertical += maxi(1,roundi(480*delta))

func reveal(index: int) -> void:
	if not is_instance_valid(game) or not game.is_inside_tree(): return
	for child in game.cards.get_children():
		if child is PanelContainer and child.get_script() == game.Card and child.index == index:
			game.card_scroll.ensure_control_visible(child)
			return
