extends Control
## Original vector-animated opening. No movie dependency; scales with the viewport.
signal finished
const Art = preload("res://scripts/robot_art.gd")
const FONT = preload("res://assets/fonts/jetbrains-mono.ttf")
const BOLD = preload("res://assets/fonts/jetbrains-mono-bold.ttf")
const DURATION = 19.0
const INK = Color("080e1d")
const GOLD = Color("e7c580")
const CYAN = Color("77d9d0")
var elapsed = 0.0
var skip_armed = false
var closed = false
var sparkle = 0.0
var interactions = 0
var player: AudioStreamPlayer
var subtitle: Label
var skip_hint: Label
var chapter: Label
var progress: ProgressBar
var audio_enabled = true
var interactive_center = Vector2(1005,405)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	z_index = 100
	player = AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/intro.wav")
	player.volume_db = -10
	add_child(player)
	if audio_enabled and DisplayServer.get_name() != "headless": player.play()
	chapter = _label(15, CYAN)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	chapter.offset_left = 60; chapter.offset_top = 38
	add_child(chapter)
	subtitle = _label(23, Color("edf3fa"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left = 80; subtitle.offset_right = -80
	subtitle.offset_top = -136; subtitle.offset_bottom = -80
	add_child(subtitle)
	skip_hint = _label(15, Color("a8b8cf"))
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint.offset_top = -65; skip_hint.offset_bottom = -30
	add_child(skip_hint)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = DURATION
	progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	progress.offset_left = 60; progress.offset_right = -60
	progress.offset_top = -12; progress.offset_bottom = -9
	var bg = StyleBoxFlat.new(); bg.bg_color = Color("19283d")
	var fg = StyleBoxFlat.new(); fg.bg_color = CYAN
	progress.add_theme_stylebox_override("background",bg)
	progress.add_theme_stylebox_override("fill",fg)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	_refresh_text()

func _label(font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _process(delta: float) -> void:
	if closed: return
	elapsed += delta
	sparkle = maxf(0, sparkle-delta)
	_refresh_text()
	queue_redraw()
	if elapsed >= DURATION: finish()

func _refresh_text() -> void:
	if not is_instance_valid(chapter): return
	var part = mini(3, int(elapsed/5.0))
	chapter.text = ["01 / ПАРИЖ · ПОСЛЕ ЗАКРЫТИЯ", "02 / У КАЖДОГО ЕСТЬ СВОЯ ЧАСТЬ ПЛАНА", "03 / НИКАКОЙ ИМПРОВИЗАЦИИ", "04 / ТЕПЕРЬ ВАШ ВЫХОД"][part]
	subtitle.text = ["В музее всё под охраной. Кроме одной маленькой идеи.", "Лувр взламывает. Мона отвлекает. Лиза забирает.", "Три робота. Один алмаз. Всё решает правильная программа.", "ТИХИЙ ПРОТОКОЛ"][part]
	if sparkle > 0: subtitle.text = "Лиза: «Тс-с-с. Он и так слишком блестящий!»"
	skip_hint.text = "Пропустить мультик? Нажмите ПРОБЕЛ ещё раз" if skip_armed else "ПРОБЕЛ ×2 — пропустить   ·   нажмите на алмаз, чтобы он засиял"
	skip_hint.add_theme_color_override("font_color", GOLD if skip_armed else Color("a8b8cf"))
	progress.value = minf(elapsed, DURATION)

func _input(event: InputEvent) -> void:
	if closed: return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_SPACE:
			if skip_armed: finish()
			else: skip_armed = true; _refresh_text()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var p = (get_global_transform_with_canvas().affine_inverse()*event.position)/Vector2(size.x/1440.0,size.y/900.0)
			if p.distance_to(interactive_center) < 95:
				sparkle = 1.6
				interactions += 1
				_refresh_text()
		get_viewport().set_input_as_handled()

func finish() -> void:
	if closed: return
	closed = true
	if is_instance_valid(player): player.stop()
	finished.emit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),INK)
	var scale = Vector2(size.x/1440.0,size.y/900.0)
	draw_set_transform(Vector2.ZERO,0,scale)
	for i in 55:
		var p = Vector2(fposmod(i*137.7,1440),90+fposmod(i*83.9,520))
		draw_circle(p,1.1,Color(.5,.7,.9,.16+.12*sin(elapsed+i)))
	if elapsed < 5: _exterior(scale)
	elif elapsed < 15: _heist(scale)
	else: _finale(scale)
	draw_set_transform(Vector2.ZERO,0,scale)
	if sparkle > 0:
		for i in 14:
			var angle = i*TAU/14 + elapsed
			var ray = Vector2.from_angle(angle)
			var radius = 40+(1.6-sparkle)*80
			draw_line(interactive_center+ray*radius,interactive_center+ray*(radius+18),Color(GOLD,sparkle/1.6),2,true)
	# A brief cinematic fade between shots; the clock continues underneath.
	var transition = minf(absf(elapsed-5),absf(elapsed-15))
	if transition < .3: draw_rect(Rect2(0,0,1440,900),Color(INK,1-transition/.3))
	draw_set_transform(Vector2.ZERO)

func _text(p: Vector2, value: String, font_size: int, color: Color = GOLD) -> void:
	draw_string(BOLD,p,preload("res://scripts/localization.gd").text(value),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _robot(p: Vector2, id: int, zoom: float, scale: Vector2, name: bool = false) -> void:
	# RobotArt resets its canvas transform, so wrap it explicitly for viewport scaling.
	Art.render(self,p*scale,id,zoom*scale.x)
	draw_set_transform(Vector2.ZERO,0,scale)
	if name: _text(p+Vector2(-37,68),["ЛУВР","МОНА","ЛИЗА"][id],18,CYAN)

func _diamond(p: Vector2, amount: float = 1.0) -> void:
	interactive_center = p
	var points = PackedVector2Array([Vector2(-30,-15),Vector2(-14,-30),Vector2(14,-30),Vector2(30,-15),Vector2(0,28)])
	for i in points.size(): points[i] = points[i]*amount+p
	draw_circle(p,55*amount,Color(.3,.85,1,.06+.03*sin(elapsed*3)))
	draw_colored_polygon(points,Color("abecf1"))
	draw_polyline(PackedVector2Array([points[0],points[2],points[4],points[1],points[3]]),Color.WHITE,2,true)
	draw_line(points[0],points[3],Color("4da2c3"),2,true)

func _exterior(scale: Vector2) -> void:
	draw_circle(Vector2(1170,180),42,Color("c0d8e8"))
	draw_circle(Vector2(1190,168),39,INK)
	for side in [Rect2(120,330,420,250),Rect2(900,330,420,250)]:
		draw_rect(side,Color("15243b"))
		draw_line(side.position,side.position+Vector2(side.size.x,0),GOLD,2,true)
		for col in 7:
			for row in 3:
				draw_rect(Rect2(side.position+Vector2(26+col*56,35+row*64),Vector2(19,29)),Color("6a654e") if (col+row)%3==0 else Color("25364d"))
	var triangle = PackedVector2Array([Vector2(510,580),Vector2(720,275),Vector2(930,580)])
	draw_colored_polygon(triangle,Color("16394c"))
	draw_polyline(PackedVector2Array([triangle[0],triangle[1],triangle[2],triangle[0]]),CYAN,2,true)
	for i in range(1,8):
		var k = i/8.0
		draw_line(triangle[0].lerp(triangle[1],k),triangle[2].lerp(triangle[1],k),Color("396878"),1,true)
		draw_line(triangle[1],triangle[0].lerp(triangle[2],k),Color("396878"),1,true)
	draw_line(Vector2(90,582),Vector2(1350,582),Color("435069"),2)
	_text(Vector2(590,230),"03:14 / LOUVRE",24)
	for id in 3:
		var x = lerpf(-100.0-id*100,570.0+id*140,smoothstep(0,3.8,elapsed))
		_robot(Vector2(x,640+sin(elapsed*6+id)*4),id,2.1,scale,true)
	_diamond(Vector2(1050,260),.65)

func _heist(scale: Vector2) -> void:
	var t = elapsed-5
	draw_rect(Rect2(110,180,1220,480),Color("d2dfe3"))
	for i in 10:
		draw_rect(Rect2(110+i*122,180,61,480),Color("cbd8de"))
	for x in [140,400,720,1240]:
		draw_rect(Rect2(x,220,30,390),Color("9eafb9"))
		draw_rect(Rect2(x-12,210,54,18),Color("e8eff0"))
	draw_rect(Rect2(110,610,1220,50),Color("8b9da9"))
	draw_rect(Rect2(335,405,72,90),Color("20384d"))
	var hacked = t > 2.6
	draw_rect(Rect2(345,417,52,34),CYAN if hacked else Color("d6b86e"))
	for i in 3: draw_line(Vector2(351,425+i*7),Vector2(370+int(t*5+i)%18,425+i*7),INK,2)
	if not hacked:
		for i in 4:
			var x = 830+i*100
			draw_line(Vector2(x,250),Vector2(x,610),Color(1,.25,.38,.12),13,true)
			draw_line(Vector2(x,250),Vector2(x,610),Color("ec647e"),2,true)
	else: _text(Vector2(845,260),"ОКНО ОТКРЫТО · 06 С",19,Color("244b59"))
	draw_rect(Rect2(1050,480,90,130),Color("8b9faa"))
	draw_rect(Rect2(1038,473,114,15),Color("f3f5ef"))
	var taken = smoothstep(5,7,t)
	_diamond(Vector2(1095,425+sin(t*3)*6).lerp(Vector2(990,500),taken))
	_robot(Vector2(298,545+sin(t*8)*2),0,2.4,scale,true)
	_robot(Vector2(610,550),1,2.4,scale,true)
	_robot(Vector2(lerpf(750,990,smoothstep(2.8,5.6,t)),550),2,2.4,scale,true)
	# Mona throws a decoy; a visibly bored guard turns and leaves his post.
	var throw_phase = clampf((t-1.7)/1.0,0,1)
	var disc = Vector2(640,510).lerp(Vector2(490,300),throw_phase)
	disc.y -= sin(throw_phase*PI)*55
	if t > 1.7:
		draw_circle(disc,8,Color("ad82ca"))
		for i in 3: draw_arc(Vector2(490,300),18+fmod(t*30+i*20,65),0,TAU,40,Color(.5,.3,.8,.35),2,true)
	var guard = Vector2(1180,330).lerp(Vector2(540,300),smoothstep(2.7,5.0,t))
	draw_circle(guard,22,Color("25354c"))
	draw_rect(Rect2(guard+Vector2(-27,-20),Vector2(54,9)),Color("1a2538"))
	_text(guard+Vector2(-7,-35),"?" if t>2 else "z",24,Color("20374a"))
	if t > 7.5: _text(Vector2(520,350),"ПО ПРОГРАММЕ. БЕЗ ПАНИКИ.",22,Color("274451"))

func _finale(scale: Vector2) -> void:
	var t = elapsed-15
	_text(Vector2(323,245),"ТИХИЙ ПРОТОКОЛ",60,Color("eaf0fb"))
	_text(Vector2(395,290),"СОБЕРИ ПЛАН. ЗАПУСТИ ОГРАБЛЕНИЕ.",23,CYAN)
	for id in 3:
		var p = Vector2(480+id*240,450+sin(t*2+id)*7)
		_robot(p,id,3.4,scale,true)
		if id<2: draw_dashed_line(p+Vector2(70,0),p+Vector2(170,0),Color("4e7182"),2,8,true)
	_diamond(Vector2(720,610),1.2)
