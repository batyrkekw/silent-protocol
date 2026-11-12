extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
func _initialize():call_deferred('test')
func test():
 var game=load('res://scripts/main.gd').new();game.show_intro_on_boot=false;game.records_path='user://qa_zero_ui.json';root.add_child(game)
 await process_frame
 game._change_level(3);game._load_demo()
 assert(game.level_picker.item_count==4 and game.sim.level==3 and '4×' in game.robustness_button.text)
 assert(game.CONDITION_LABELS.size()==Sim.CONDITIONS.size())
 var index=-1
 for i in game.plan[0].size():
  if game.plan[0][i].get('after_ticks',0)>0:index=i;break
 assert(index>=0)
 game.block_editor.toggle_parameters(index)
 var fields=game.block_editor.fields
 assert(fields.after_row.visible)
 var original=game.plan.duplicate(true)
 game.block_editor.apply_fields(fields)
 assert(game.plan[0][index].after_ticks==original[0][index].after_ticks)
 game._load_demo();var saved=game.plan.duplicate(true);game._save_plan('user://qa_zero_plan.json');game.plan=[[],[],[]];game._load_plan('user://qa_zero_plan.json');assert(game.plan==saved);game._start()
 while game.sim.outcome=='running':game.sim.step()
 game.board.state=game.sim.view();game._update_ui()
 assert(game.sim.outcome=='won' and game.robustness_button.visible)
 game._check_robustness();assert(game.reliability.scenario_count==4)
 var count=0
 while game.reliability.active and count<15000:game.reliability.step(.25);count+=1
 assert(game.reliability.results.size()==4 and game.reliability.successes()==4)
 game._tick_reliability(0)
 assert('4/4' in game.result_summary.text)
 game._show_steps();game._reset();assert(game.sim.outcome=='planning' and not game.plan[0].is_empty())
 print('ZERO UI: picker, condition editor, forecast preservation, victory, 4/4 reliability, retry passed')
 game.queue_free();await process_frame;quit()
