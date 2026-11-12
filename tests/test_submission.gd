extends SceneTree
const Main=preload('res://scripts/main.gd')
const Loc=preload('res://scripts/localization.gd')
var failures=0
func check(ok,label):
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('test')
func test():
 root.size=Vector2i(1440,900)
 var game=Main.new();game.show_intro_on_boot=false;game.records_path='user://qa_submission.json'
 game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(game)
 await process_frame;await process_frame
 var worker=Loc.new();root.add_child(worker)
 var plan=game.plan.duplicate(true)
 for locale in ['ru','kk','en']:
  TranslationServer.set_locale(locale);worker.refresh(game)
  await process_frame;await process_frame
  check(game.exit_button.get_global_rect().end.x<=1440,'Header exit fits '+locale)
  game.credits_button.pressed.emit();await process_frame
  check(game.credits_dialog.visible and game.credits_dialog.is_embedded(),'Credits open embedded '+locale)
  check(game.credits_dialog.size.x<=root.size.x and game.credits_dialog.size.y<=root.size.y,'Credits fit')
  game.credits_dialog.hide()
  game.exit_button.pressed.emit();await process_frame
  check(game.exit_dialog.visible and game.exit_dialog.is_embedded(),'Exit confirmation opens embedded')
  game.exit_dialog.get_cancel_button().pressed.emit();game.exit_dialog.hide()
  check(game.plan==plan and game.sim.outcome=='planning','Cancelled exit preserves draft')
 check(not game.exit_dialog.confirmed.get_connections().is_empty(),'Exit confirmation has action')
 game._open_composer();game._choose_action(Main.TYPES.find('noise'))
 check('осмотр 6 с' not in game.action_description.text,'Noise does not promise fixed 6 seconds')
 game.queue_free();await process_frame;worker.queue_free();await process_frame
 print('SUBMISSION UI: ',failures,' failed');quit(1 if failures else 0)
