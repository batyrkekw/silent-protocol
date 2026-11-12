extends SceneTree
const Main=preload('res://scripts/main.gd')
const Sim=preload('res://scripts/simulation_v5.gd')
var failures=0
var passed=0
func check(ok:bool,label:String):
 if ok:passed+=1;print('PASS ',label)
 else:failures+=1;push_error(label)
func _initialize():call_deferred('test')
func test():
 root.size=Vector2i(1440,900)
 var game=Main.new();game.show_intro_on_boot=false;game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(game)
 await process_frame;await process_frame
 var alphabet='АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюяABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
 var supported=game.theme.default_font.get_supported_chars()
 var missing=''
 for character in alphabet:
  if character not in supported:missing+=character
 check(missing.is_empty(),'UI font contains Russian/Latin glyphs without fallback: '+missing)
 check(game.toast.global_position.y+game.toast.size.y<=900,'Interface fits 1440x900')
 check(root.gui_embed_subwindows and game.chronicle.get_window()==root and game.composer.is_embedded() and game.help_dialog.is_embedded(),'All dialogs stay embedded in the game viewport')
 check(game.log_box.get_theme_font_size('normal_font_size')>=18 and game.action_description.get_theme_font_size('font_size')>=18,'Chronicle and command explanations use readable text sizes')
 check(not game.next_stage_button.visible,'Next lesson is hidden before success')
 var map_rect=game.board.get_global_rect()
 game._show_chronicle();await process_frame;await process_frame
 check(not game.chronicle.get_global_rect().intersects(game.board.get_global_rect()),'Chronicle occupies the sidebar without covering the map')
 check(game.board.get_global_rect()==map_rect and not game.editor_panel.visible,'Opening chronicle preserves map size and replaces the steps')
 game.steps_tab.pressed.emit();await process_frame
 check(game.editor_panel.visible and not game.chronicle.visible and game.steps_tab.button_pressed,'Steps tab restores the editor')
 game._show_tutorial();check(game.tutorial.visible,'Tutorial invitation can be opened')
 game._close_tutorial();check(not game.tutorial.visible,'Tutorial is optional')
 check(game.stage_picker.item_count==6,'Six independent lesson maps')
 check(game.level_picker.item_count==4 and 'goto' not in Main.TYPES,'Four missions and no destination movement in palette')
 var before=game.plan.duplicate(true)
 game._choose_cell(Vector2i(3,2))
 check(game.plan==before and not game.composer.visible,'Map click cannot add movement or open a destination editor')
 game._open_composer();check(game.action_buttons[0].visible and game.action_buttons[Main.TYPES.find("while")].visible,'All tools are available from the first tutorial lesson')
 game._cancel_composer();game._change_stage(5);game._open_composer()
 check(game.action_buttons[Main.TYPES.find("while")].visible and game.action_buttons[Main.TYPES.find("select")].visible,'Final lesson unlocks loops and target selection')
 game._choose_action(Main.TYPES.find("repeat"));game.seconds.value=3;game._add_command()
 check(game.plan[0].size()==2 and game.plan[0][1].type=='end','Repeat creates paired structure')
 game._open_inside(1);game._choose_action(0);game.target_x.value=3;game.target_y.value=2;game._add_command()
 check(game.plan[0][1].type=='forward' and not game.plan[0][1].has('target'),'Relative step inserted inside loop without a destination')
 game._open_inside(2);game._choose_action(Main.TYPES.find("if"));game._add_command()
 check(Sim.validate(game.plan).is_empty(),'Nested conditional is valid')
 game._edit_card(2,0);game._undo();check(game.plan[0].size()==6,'Undo restores whole conditional')
 game._load_demo();var saved=game.plan.duplicate(true)
 game._change_level(1);game._update_ui();check(game.plan==[[],[],[]],'Main mission starts with blank programs')
 game._change_level(0);game._change_stage(5);check(game.plan==saved,'Per-lesson draft persists')
 game._change_stage(0);game._run_reference()
 while game.sim.outcome=='running':game.sim.step()
 game.board.state=game.sim.view();game._update_ui()
 check(game.sim.outcome=='won' and game.chronicle.visible,'Show solution runs lesson to victory')
 check(game.next_stage_button.visible and game.chronicle_next_button.visible,'Victory offers next lesson in both map and chronicle')
 await process_frame;await process_frame
 check(game.toast.global_position.y+game.toast.size.y<=900 and game.next_stage_button.global_position.y+game.next_stage_button.size.y<=900,'Victory navigation fits without pushing controls off screen')
 check(game.result_overlay.visible and game.result_overlay.full_window and not game.result_overlay.get_global_rect().intersects(game.board.get_global_rect()),'Result animation stays inside the sidebar')
 check(game.log_box.get_global_rect().end.y <= game.chronicle.get_global_rect().end.y and game.chronicle_next_button.get_global_rect().end.y <= game.chronicle.get_global_rect().end.y,'Log and next button fit the sidebar')
 var won_plan=game.plan.duplicate(true);var won_tick=game.sim.tick
 game.steps_tab.pressed.emit();game.chronicle_tab.pressed.emit()
 check(game.plan==won_plan and game.sim.tick==won_tick and game.chronicle.visible,'Switching tabs preserves programs and result')
 await create_timer(2.5).timeout
 check(not game.result_overlay.visible and game.result_mark.visible,'Large result disappears; corner mark remains')
 game.sim.outcome='lost';game.board.state=game.sim.view();game._update_ui()
 check(game.result_overlay.visible and game.result_mark.result=='lost','Failure also animates across the window')
 game._reset();check(not game.chronicle.visible,'Reset closes chronicle')
 # Follow the same progression buttons as a new player, through all six lessons.
 var progression=true
 for stage in 6:
  game._run_reference()
  while game.sim.outcome=='running':game.sim.step()
  game.board.state=game.sim.view();game._update_ui()
  progression=progression and game.sim.outcome=='won' and game.sim.stage==stage and game.chronicle_next_button.visible
  if stage%2==0:game.chronicle_next_button.pressed.emit()
  else:game.next_stage_button.pressed.emit()
  progression=progression and game.sim.outcome=='planning' and not game.chronicle.visible and not game.next_stage_button.visible
  if stage<5:progression=progression and game.sim.stage==stage+1 and game.stage_picker.selected==stage+1
 check(progression and game.sim.level==1 and game.level_picker.selected==1,'Next buttons complete six lessons and open the first heist')
 game._change_level(2);game._load_demo()
 # Edit every reference block, including device windows and literal tick waits.
 var all_editable=true
 for id in 3:
  game._select_robot(id)
  for i in game.plan[id].size():
   if game.plan[id][i].type in ['else','end']:continue
   game._open_composer(i)
   all_editable=all_editable and game.command_type.selected>=0
   game._cancel_composer()
 check(all_editable,'Every reference block opens in the editor')
 game._select_robot(2)
 var negated_index=-1
 for i in game.plan[2].size():
  if game.plan[2][i].get('negate',false):negated_index=i;break
 game._open_composer(negated_index)
 check(game.condition_negate.button_pressed,'Negated loop condition is preserved when editing')
 game._cancel_composer();game._open_composer();game._choose_action(Main.TYPES.find('noise'));game._pick_on_map();game._choose_cell(Vector2i(17,11));game._add_command()
 check(game.plan[2].back().type=='noise' and game.plan[2].back().target==[17,11],'Map target picker is restricted to noise throws')
 game._open_composer();await process_frame
 check(game.composer.size.y<850,'Command palette fits screen')
 # Round-trip the actual editor, not merely opening it: timings and omitted defaults must survive.
 game._cancel_composer()
 for case in 8:
  game._change_level(0 if case<6 else case-5)
  if case<6:game._change_stage(case)
  game._load_demo();var original=game.plan.duplicate(true);var accepted=true
  for id in game.sim.active_ids:
   game._select_robot(id)
   for i in game.plan[id].size():
    if game.plan[id][i].type in ['else','end']:continue
    game._open_composer(i);game._add_command()
    accepted=accepted and not game.composer.visible
    game._cancel_composer()
    await process_frame
  var baseline=Sim.new();baseline.set_level(game.sim.level,game.sim.stage);baseline.record=false;baseline.reset(original);baseline.start()
  while baseline.outcome=='running' and baseline.tick<12000:baseline.step()
  var edited=Sim.new();edited.set_level(game.sim.level,game.sim.stage);edited.record=false;edited.reset(game.plan);edited.start()
  while edited.outcome=='running' and edited.tick<12000:edited.step()
  check(accepted and edited.outcome=='won' and edited.tick==baseline.tick,'Editing every block preserves solution and timing: map %d'%(case+1))
 game._change_level(0);game._change_stage(5)
 game.plan=[[{'type':'repeat','count':100},{'type':'wait','ticks':1},{'type':'end'}],[],[]];game._plan_changed();game._select_robot(0)
 game._open_composer(0);game._add_command();game._open_composer(1);game._add_command()
 check(game.plan[0][0].count==100 and is_equal_approx(game.plan[0][1].seconds,.05),'Repeat count and 0.05-second wait survive changing parameter modes')
 game.plan=[[{'type':'forward'},{'type':'repeat','count':2},{'type':'right'},{'type':'end'}],[],[]];game._plan_changed();game._edit_card(0,1)
 check(game.plan[0][0].type=='repeat' and game.plan[0][3].type=='forward' and Sim.validate(game.plan).is_empty(),'Moving a step down past a loop preserves both blocks')
 game._undo();check(game.plan[0][0].type=='forward','Reordering can be undone')
 var fixture='user://qa_plan_roundtrip.json'
 game.plan=[[],[],[]];game._plan_changed();game._save_plan(fixture)
 game.plan=[[{'type':'forward'}],[],[]];game._plan_changed();game._load_plan(fixture)
 check(game.plan==[[],[],[]],'Empty saved draft can be reloaded')
 game.plan=[[{'type':'forward'}],[],[]];game._plan_changed();var safe=game.plan.duplicate(true)
 var file=FileAccess.open(fixture,FileAccess.WRITE);file.store_string('{broken json');file.close();game._load_plan(fixture)
 check(game.plan==safe,'Broken JSON preserves the current plan')
 file=FileAccess.open(fixture,FileAccess.WRITE);file.store_string(JSON.stringify({'version':6,'level':0,'stage':5,'plans':[[{'type':'timer','ticks':20}],[],[]]}));file.close();game._load_plan(fixture)
 check(game.plan==safe,'Malformed saved command is rejected without changing the draft')
 game._save_plan(fixture);game.plan=[[],[],[]];game._plan_changed();game._load_plan(fixture)
 check(game.plan==safe,'Valid saved draft round-trips')
 DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
 game.plan=[[{'type':'condition','all':[{'condition':'front_clear'},{'condition':'signal_off','signal':'A'}]}],[],[]];game._plan_changed();game._cancel_composer();var compound=game.plan.duplicate(true);game._open_composer(0)
 check(not game.composer.visible and game.plan==compound,'Unsupported compound conditions cannot be silently replaced by a single condition')
 game._change_stage(2);game._load_demo();game._start();game.paused=true
 for i in 100:game.sim.step()
 game.board.state=game.sim.view();game._update_ui();var live_tick=game.sim.tick
 game._scrub(0);game._update_ui()
 check(game.operation_signals.text=='Сигналы: нет' and 'Готов' in game.operation_steps[0].text,'Replay statuses and signals come from the selected frame')
 game._live();check(game.sim.tick==live_tick and game.board.state.tick==live_tick,'Returning to live view does not rewind the simulation')
 var hack=Sim.new();hack.set_level(2);hack.record=false;hack.reset([[{'type':'interact','object':'terminal1'}],[],[]]);hack.robots[0].pos=Vector2i(3,1);hack.start();hack.step()
 game.sound.reset_history();game.sound.update_audio(hack,false,false,.05)
 check(game.sound.last_event_kind=='hack','Universal interaction plays the hacking sound')
 game.queue_free();await process_frame
 print('UI RESULT ',passed,' passed; ',failures,' failed');quit(1 if failures else 0)
