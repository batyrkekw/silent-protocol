extends SceneTree
const Loc=preload('res://scripts/localization.gd')
var leftovers={}
func _initialize():call_deferred('test')
func inspect(node):
 if node is Label or node is RichTextLabel or node is Button:
  var t=node.text
  var regex=RegEx.new();regex.compile('[А-Яа-яЁё]')
  if regex.search(t) and t not in ['Русский','Қазақша'] and not t.begins_with('Русский'):leftovers[t]=true
 for child in node.get_children():inspect(child)
func test():
 var game=load('res://scripts/main.gd').new();game.show_intro_on_boot=false;game.records_path='user://qa_localization.json';root.add_child(game)
 await process_frame
 TranslationServer.set_locale('en')
 var worker=Loc.new();root.add_child(worker)
 for level in 4:
  game._change_level(level)
  for stage in (6 if level==0 else 1):
   if level==0:game._change_stage(stage)
   game._load_demo();game._refresh_editor();worker.refresh(game);inspect(game)
   game._start()
   while game.sim.outcome=='running' and game.sim.tick<12000:game.sim.step()
   game.board.state=game.sim.view();game._update_ui();worker.refresh(game);inspect(game)
 for key in leftovers:print('LEFTOVER ',key.replace('\n',' | '))
 var before=JSON.stringify(game.plan)
 for locale in ['ru','kk','en','ru']:
  TranslationServer.set_locale(locale);worker.refresh(game)
  assert(JSON.stringify(game.plan)==before)
  assert(Loc.text('Повторить 3 раз')!='Повторить 3 раз' if locale!='ru' else Loc.text('Повторить 3 раз')=='Повторить 3 раз')
 var font=load('res://assets/fonts/jetbrains-mono.ttf')
 for letter in 'ӘәҒғҚқҢңӨөҰұҮүҺһІі':assert(font.has_char(letter.unicode_at(0)))
 print('LOCALIZATION RESULT ',leftovers.size(),' untranslated UI strings; language switching preserves programs')
 quit(0 if leftovers.is_empty() else 1)
