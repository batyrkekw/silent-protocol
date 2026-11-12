extends SceneTree
const Main = preload('res://scripts/main.gd')
const Sim = preload('res://scripts/simulation_v5.gd')
var passed = 0
var failed = 0
var game
func check(ok: bool, title: String):
 if ok:passed+=1;print('PASS ',title)
 else:failed+=1;push_error(title)
func _initialize():call_deferred('test')
func key(pressed: bool, echo: bool = false):
 var event=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=pressed;event.echo=echo
 root.push_input(event)
func test():
 root.size=Vector2i(1440,900)
 game=Main.new();game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(game)
 if DisplayServer.get_name()=='headless':game._play_intro()
 await process_frame;await process_frame
 check(is_instance_valid(game.intro) and game.intro.is_visible_in_tree(),'Intro appears at startup before tutorial')
 check(not game.tutorial.visible and game.sim.tick==0,'Tutorial and simulation wait for the intro')
 var intro=game.intro
 intro.set_process(false)
 check(intro.player.stream.get_length()>=18.9,'Original intro music covers the whole animation')
 if DisplayServer.get_name()!='headless':check(intro.player.playing,'Intro music starts automatically in the native app')
 intro.elapsed=7;intro._refresh_text();intro.queue_redraw()
 await process_frame;await process_frame
 # Interaction is local to the intro and never changes the plan.
 var before=game.plan.duplicate(true)
 var click=InputEventMouseButton.new();click.position=intro.interactive_center;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 root.push_input(click)
 check(intro.interactions==1 and intro.sparkle>0,'Clicking the diamond triggers a sparkle and a line of dialogue')
 check(game.plan==before,'Intro interaction cannot alter the program underneath')
 key(true)
 check(intro.skip_armed and is_instance_valid(game.intro),'First Space asks for confirmation without skipping')
 check('ещё раз' in intro.skip_hint.text,'Skip confirmation explains the second press')
 key(true,true)
 check(not intro.closed,'Holding Space does not count as the second press')
 key(false);key(true)
 check(not is_instance_valid(game.intro) and intro.closed,'Second separate Space skips the animation')
 check(not intro.player.playing and game.tutorial.visible,'Skip stops intro music and opens the optional tutorial')
 key(false)
 await process_frame;await process_frame
 game._close_tutorial();game._play_intro()
 var natural=game.intro
 natural.set_process(false);natural.elapsed=natural.DURATION-.01;natural._process(.02)
 check(not is_instance_valid(game.intro) and game.tutorial.visible,'Intro finishes automatically without input')
 await process_frame;await process_frame
 game._close_tutorial()
 check(Sim.NAMES==['ЛУВР','МОНА','ЛИЗА'] and Sim.LEVEL_NAMES[0]=='Туториал','Robot names and tutorial title are updated')
 check(game.block_editor.tiles.size()==15 and game.block_editor.tiles.all(func(tile):return tile.is_visible_in_tree() and not tile.disabled),'All 15 tools are visible and available together')
 var shelf=game.block_editor.palette.get_global_rect()
 check(shelf.position.y>=game.editor_panel.get_global_rect().end.y and shelf.end.y<=900,'Toolbox is below the workspace and fits the window')
 check(game.block_editor.tiles.all(func(tile):return shelf.encloses(tile.get_global_rect())),'Every command fits the shelf without horizontal scrolling')
 var toolbar=game.save_button.get_parent()
 var chronicle_index=-1
 for child in toolbar.get_children():
  if child is Button and child.text=='Хроника':chronicle_index=child.get_index()
 check(chronicle_index<0 and game.demo_button.get_index()==game.save_button.get_index()+1 and game.load_button.get_index()==game.save_button.get_index()+2 and game.save_button.get_global_rect().position.x>game.reset_button.get_global_rect().end.x+100,'File actions sit on the right; obsolete toolbar Chronicle is absent')
 check(not game.add_step.is_visible_in_tree(),'No add-step button is needed')
 check(game.board.show_vision,'Vision cones are always enabled')
 var has_toggle=false
 for child in game.board.get_parent().get_child(0).get_children():
  if child is Button and child.text=='Зоны обзора':has_toggle=true
 check(not has_toggle,'Vision toggle is removed from the map header')
 game._show_chronicle();await process_frame;await process_frame
 check(game.log_box.get_global_rect().end.y<=game.chronicle.get_global_rect().end.y,'Chronicle fits above the bottom toolbox')
 game.block_editor.tiles[0].drag_started.emit()
 check(game.editor_panel.visible,'Beginning a toolbox drag reveals the program when Chronicle was open')
 game._show_chronicle()
 game.block_editor.tiles[0].pressed.emit()
 check(game.editor_panel.visible and game.plan[0].size()==1,'Clicking a toolbox command returns from chronicle to the program')
 game.queue_free();await process_frame;await process_frame
 print('INTRO RESULT ',passed,' passed; ',failed,' failed')
 quit(1 if failed else 0)
