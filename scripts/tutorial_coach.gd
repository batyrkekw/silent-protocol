extends RefCounted
## Contextual first-minute lesson: four edits, one autonomous run, then optimization.
var game
var panel:PanelContainer
var body:Label
var title:Label
var active=false
var highlight:Control
var step_index=0
var elapsed=0.0
var phase=0.0
var interrupted=false
var printed_text=""
var typed=0.0
var voice:AudioStreamPlayer
func _init(host):game=host
func build() -> void:
 voice=AudioStreamPlayer.new();voice.stream=load("res://assets/audio/type.wav");voice.volume_db=-25;game.add_child(voice)
 panel=game._panel();panel.add_theme_stylebox_override('panel',game._style(Color('173d45'),Color('70c9ba'),7))
 var column=VBoxContainer.new();panel.add_child(column)
 var head=HBoxContainer.new();column.add_child(head)
 title=game._label('ПЕРВАЯ ПРОГРАММА · ~1 МИНУТА',14,game.GREEN);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
 head.add_child(game._button('×',stop))
 body=game._label('',15);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(body)
 game.editor_panel.add_child(panel)
 game.editor_panel.move_child(panel,game.tabs[0].get_parent().get_index()+1)
 panel.hide()
func start() -> void:
 game._change_stage(0)
 game._clear_robot()
 active=true;interrupted=false;elapsed=0;step_index=0
 panel.show();game._show_steps();update(0)
func stop() -> void:
 active=false;panel.hide();_highlight(null)
func _highlight(control:Control) -> void:
 if highlight==control:return
 if is_instance_valid(highlight):highlight.modulate=Color.WHITE
 highlight=control
func update(delta:float) -> void:
 if not active:return
 if game.sim.level!=0:stop();return
 elapsed+=delta;phase+=delta
 if game.sim.outcome=='won':stop();return
 if game.sim.outcome=='running':
  panel.hide();_highlight(null);return
 panel.show()
 if game.sim.stage>0:
  title.text="Этап %d"%(game.sim.stage+1)
  body.text=game._lesson_text()
  _highlight(null);_reveal(delta);return
 var program:Array=game.plan[0]
 var expected=['forward','interact','repeat','forward','end']
 var actual=program.map(func(c):return c.type)
 var target_kind=''
 if actual.is_empty():
  step_index=0;target_kind='forward'
  body.text='1/5 · Дойдём до кнопки. Перетащите «Вперёд» из нижней панели в пустую программу справа.'
 elif actual==['forward']:
  step_index=1;target_kind='interact'
  body.text='2/5 · Добавьте «Взаимодействие». Рядом с кнопкой робот сам откроет дверь.'
 elif actual==['forward','interact']:
  step_index=2;target_kind='repeat'
  body.text='3/5 · Добавьте «Повторить N». В нём уже стоит 3 — столько клеток осталось до выхода.'
 elif actual==['forward','interact','repeat','end']:
  step_index=3;target_kind='forward'
  game.block_editor.cursor=3
  body.text='4/5 · Перетащите «Вперёд» МЕЖДУ «Повторить» и «Конец блока». Один шаг повторится трижды!'
 elif actual==expected and int(program[2].get('count',0))==3:
  step_index=4
  body.text='5/5 · Нажмите ▶. После запуска не управляйте роботом: программа сделает всё сама.'
  _highlight(game.start_button)
 else:
  body.text='Попробуйте свою программу или соберите: Вперёд → Взаимодействие → Повторить 3 [Вперёд]. Лишний блок удаляется кнопкой ×.'
  _highlight(null)
 if not target_kind.is_empty():_highlight(game.block_editor.tiles[game.TYPES.find(target_kind)])
 if is_instance_valid(highlight):highlight.modulate=Color(1,1,1).lerp(Color('a5fff1'),.35+.25*sin(phase*4))
 title.text='ПЕРВАЯ ПРОГРАММА · %d/5'%(step_index+1)

 _reveal(delta)

func _reveal(delta:float) -> void:
 # Reveal the translated text; whitespace is silent, effects respect the sound menu.
 var translated=preload("res://scripts/localization.gd").text(body.text)
 if translated!=printed_text:
  printed_text=translated;typed=0;body.visible_characters=0
 var previous=int(typed)
 typed=minf(typed+delta*32,printed_text.length())
 body.visible_characters=int(typed)
 if int(typed)>previous and printed_text.substr(previous,1).strip_edges()!="" and game.sound.effects_enabled and DisplayServer.get_name()!="headless":
  voice.volume_db=linear_to_db(maxf(.001,game.sound.volume)) - 22
  voice.play()
