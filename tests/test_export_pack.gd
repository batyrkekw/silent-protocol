extends SceneTree
## Run externally with --main-pack build/windows/SilentProtocol.pck --path /tmp.
const Sim=preload('res://scripts/simulation_v5.gd')
const Main=preload('res://scripts/main.gd')
var failures=0
func _initialize():call_deferred('test')
func test():
 for id in 9:
  var sim=Sim.new();sim.set_level(0 if id<6 else id-5,id if id<6 else 0);sim.record=false
  var plan=sim.solution();sim.reset(plan);sim.start()
  while sim.outcome=='running' and sim.tick<12000:sim.step()
  if sim.outcome!='won':failures+=1;push_error('Exported map '+str(id)+' failed')
  else:print('PACK MAP ',id+1,' won at ',sim.tick)
 for resource in ['res://scripts/intro.gd','res://assets/audio/intro.wav','res://assets/fonts/jetbrains-mono.ttf','res://scripts/robot_art.gd']:
  if load(resource)==null:failures+=1
 var game=Main.new();game.show_intro_on_boot=false;game.records_path='user://qa_export_records.json'
 game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(game)
 await process_frame;await process_frame
 game.coach.start();game._run_reference()
 while game.sim.outcome=='running':game.sim.step()
 game.board.state=game.sim.view();game._update_ui()
 if game.sim.outcome!='won' or not game.result_summary.visible:failures+=1
 game.queue_free();await process_frame;await process_frame
 print('EXPORTED PACK RESULT ',failures,' failed')
 quit(1 if failures else 0)
