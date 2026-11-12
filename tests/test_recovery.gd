extends SceneTree
const Main=preload('res://scripts/main.gd')
const Loc=preload('res://scripts/localization.gd')
var passed=0
var failed=0
func check(value:bool,label:String):
 if value:passed+=1;print('PASS ',label)
 else:failed+=1;push_error(label)
func _initialize():call_deferred('run')
func finish(game):
 while game.sim.outcome=='running' and game.sim.tick<12000:game.sim.step()
 game.board.state=game.sim.view();game._update_ui()
func prepare(game,commands):
 game._reset();game.plan=[commands,[],[]];game._plan_changed();game._start();finish(game)
func run():
 var game=Main.new();game.show_intro_on_boot=false;game.records_path='user://qa_recovery.json';root.add_child(game)
 await process_frame
 game._close_tutorial()
 prepare(game,[{'type':'backward'}])
 var snapshot=game.plan.duplicate(true)
 check(game.sim.outcome=='lost' and game.sim.robots[0].blocked,'Wall collision produces a real failed attempt')
 check(game.result_actions.visible and not game.improve_button.disabled,'Failure exposes a working fix-program action')
 check(not game.start_button.disabled,'Run remains available after failure')
 game.improve_button.pressed.emit();game._update_ui()
 check(game.sim.outcome=='planning' and game.plan==snapshot and game.editor_panel.visible,'Fix preserves program and opens the editor')
 check(game.block_editor.expanded==0 and not game.block_editor.tiles[0].disabled,'Broken command can immediately be edited')
 check(not game.result_overlay.visible and game.sim.tick==0,'Failure overlay and simulation clock reset')
 game._edit_card(0,0);game.block_editor.add_from_palette('forward')
 check(game.plan[0].size()==1 and game.plan[0][0].type=='forward','Deleting and inserting commands works after failure')
 game._start();finish(game)
 check(game.sim.outcome=='lost','Incomplete route fails without locking the application')
 game._scrub(0);game.steps_tab.pressed.emit();game._update_ui()
 check(not game.replaying and not game.paused and game.sim.outcome=='planning','Steps leaves a failed replay and restores editable mode')
 check(game.plan[0][0].type=='forward','Steps preserves the failed draft')
 prepare(game,[{'type':'backward'}])
 game.start_button.pressed.emit();game._update_ui()
 check(game.sim.outcome=='running' and game.sim.tick==0,'Run starts a fresh attempt after failure')
 finish(game)
 game.reset_button.pressed.emit();game._run_reference();finish(game)
 check(game.sim.outcome=='won' and game.chronicle_next_button.visible,'Corrected run can win and unlock the next lesson')
 game.chronicle_next_button.pressed.emit();game._update_ui()
 check(game.sim.stage==1 and game.sim.outcome=='planning' and game.coach.active,'Next lesson works after a failed then successful run')
 game._change_stage(0);game._run_reference();finish(game)
 for locale in ['en','kk','ru']:
  TranslationServer.set_locale(locale);game._update_ui()
  check(game.log_box.get_parsed_text().contains(Loc.text('Операция началась')),'Existing chronicle switches to '+locale)
 check(game.log_box.get_parsed_text().contains('Операция началась') and not game.log_box.get_parsed_text().contains('Operation started'),'Returning to Russian rebuilds source events without mixed languages')
 # A genuine shifted-security loss also permits editing all three programs.
 game._change_level(2);game.sim.set_level(2,0,1)
 game.plan=JSON.parse_string(FileAccess.get_file_as_string('res://data/programs/08-fixed.json'));game._plan_changed();game._start();finish(game)
 check(game.sim.outcome=='lost','Shifted security reproduces a multi-robot failure')
 var team=game.plan.duplicate(true);game.improve_button.pressed.emit()
 check(game.sim.outcome=='planning' and game.plan==team and game.block_editor.tiles.all(func(t):return not t.disabled),'Multi-robot failure recovers with every program intact')
 game.queue_free();await process_frame;await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path('user://qa_recovery.json'))
 print('RECOVERY RESULT ',passed,' passed; ',failed,' failed');quit(1 if failed else 0)
