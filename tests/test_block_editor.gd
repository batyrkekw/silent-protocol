extends SceneTree
const Main = preload('res://scripts/main.gd')
const Sim = preload('res://scripts/simulation_v5.gd')
const Slot = preload('res://scripts/command_slot.gd')
var passed = 0
var failed = 0
var game
func check(ok: bool, title: String):
 if ok: passed += 1; print('PASS ',title)
 else: failed += 1; push_error(title)
func _initialize():call_deferred('test')
func block(kind):return {'kind':'new_command','type':kind}
func move(index, robot=0):return {'kind':'plan_step','robot':robot,'index':index}
func open_fields(index):
 game.block_editor.expanded = -1
 game.block_editor.toggle_parameters(index)
 return game.block_editor.fields
func mouse_motion(point, relative=Vector2.ZERO, held=false):
 var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(event)
func mouse_button(point, pressed):
 var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event)
func drag(start, destination):
 mouse_motion(start);mouse_button(start,true)
 mouse_motion(start+Vector2(15,8),Vector2(15,8),true)
 await process_frame
 mouse_motion(destination,destination-start,true)
 await process_frame
 mouse_button(destination,false)
 await process_frame;await process_frame
func test():
 root.size=Vector2i(1440,900)
 game=Main.new();game.show_intro_on_boot=false;game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(game)
 game._close_tutorial()
 await process_frame;await process_frame
 var editor=game.block_editor
 check(editor.palette.is_visible_in_tree() and game.card_scroll.size.y>=290,'Permanent palette leaves room for the program')
 check(editor.can_insert(block('repeat'),0),'All commands can be used from the first tutorial lesson')
 var slot=game.cards.get_child(0)
 check(slot is Slot and slot._can_drop_data(Vector2.ZERO,block('forward')),'Empty program accepts a toolbox block')
 slot._drop_data(Vector2.ZERO,block('forward'))
 check(game.plan[0]==[{'type':'forward'}] and not game.composer.visible,'Dropping creates a command without any dialog')
 editor.tiles[1].pressed.emit()
 check(game.plan[0].back().type=='backward','Clicking a toolbox block also inserts it')
 game._change_stage(5)
 editor.choose_category(2)
 check(editor.tiles[Main.TYPES.find('repeat')].visible,'Unlocked logic category shows repeat')
 editor.insert(block('repeat'),0)
 check(game.plan[0]==[{'type':'repeat','count':3},{'type':'end'}],'Repeat creates its end automatically')
 editor.insert(block('if'),1)
 editor.insert(block('forward'),2)
 editor.insert(block('backward'),4)
 check(game.plan[0].map(func(c):return c.type)==['repeat','if','forward','else','backward','end','end'],'Drops populate both branches inside a loop')
 check(Sim.validate(game.plan).is_empty(),'Nested structure remains valid')
 check(not editor.can_insert(move(0),3),'Cannot move a loop into itself')
 check(not editor.can_insert(move(3),0) and not editor.can_insert(move(5),0),'Else and end cannot be detached')
 check(not editor.can_insert(move(2,1),0),'Stale drag from another robot is rejected')
 check(not editor.can_insert(block('goto'),0) and not editor.can_insert(block('forward'),99),'Invalid kinds and insertion indices are rejected')
 editor.insert(move(2),5)
 check(game.plan[0][3].type=='backward' and game.plan[0][4].type=='forward','A step can move between if branches')
 game._undo()
 check(game.plan[0][2].type=='forward','Undo restores drag position')
 editor.insert(move(1),7)
 check(game.plan[0].map(func(c):return c.type)==['repeat','end','if','forward','else','backward','end'],'Moving an if carries both branches and end')
 game._undo()
 editor.choose_slot(6)
 editor.add_from_palette('left')
 check(game.plan[0][6].type=='left','Clicking after choosing a slot inserts inside that loop')
 var f=open_fields(0)
 f.amount.value=5
 editor.apply_fields(f)
 check(game.plan[0][0].count==5 and not game.composer.visible,'Repeat count edits inline')
 game._undo()
 check(game.plan[0][0].count==3,'Parameter changes participate in undo')
 game._clear_robot()
 editor.insert(block('wait'),0)
 f=editor.fields;f.amount.value=.05;editor.apply_fields(f)
 check(game.plan[0][0].seconds==.05,'Smallest wait survives inline editing')
 editor.insert(block('send'),1)
 f=editor.fields;f.name.text='';editor.apply_fields(f)
 check(f.error.visible and game.plan[0][1].signal=='ГОТОВ','Empty signal is rejected without replacing the program')
 f.name.text='КАМЕРА';f.value.button_pressed=false;editor.apply_fields(f)
 check(game.plan[0][1].signal=='КАМЕРА' and not game.plan[0][1].value,'Signal name and off state edit inline')
 editor.insert(block('timer'),2)
 f=editor.fields;f.name.text='ОКНО';f.amount.value=2.75;editor.apply_fields(f)
 check(game.plan[0][2].timer=='ОКНО' and game.plan[0][2].seconds==2.75,'Timer edits inline')
 editor.insert(block('condition'),3)
 f=editor.fields;f.condition.select(Sim.CONDITIONS.find('timer_done'));editor.update_fields(f,false)
 f.name.text='ОКНО';f.negate.button_pressed=true;editor.apply_fields(f)
 check(game.plan[0][3].timer=='ОКНО' and game.plan[0][3].negate,'Condition-specific controls preserve negation and timer')
 editor.insert(block('noise'),4)
 game._choose_cell(Vector2i(3,2));editor.apply_fields(editor.fields)
 check(game.plan[0][4].target==[3,2] and not game.composer.visible,'Noise picks coordinates on map without a modal')
 var original=game.plan.duplicate(true)
 game._choose_cell(Vector2i(2,2))
 check(game.plan==original,'Map is not a movement editor')
 # A real viewport drag exercises Control forwarding and hit testing, not only callbacks.
 game._clear_robot();await process_frame;await process_frame
 var tile=editor.tiles[0]
 editor.choose_category(0)
 tile.force_drag(block('forward'),Label.new())
 var point=game.cards.get_child(0).get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion)
 var release=InputEventMouseButton.new();release.position=point;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;root.push_input(release)
 await process_frame;await process_frame
 check(game.plan[0].size()==1 and game.plan[0][0].type=='forward','Viewport drag and drop actually inserts a block')
 var first_card=game.cards.get_child(1)
 # The dummy headless display reports mouse position (0,0) during drops.
 # Native runs exercise actual events; headless runs supply local coordinates.
 if DisplayServer.get_name()=='headless':
  var local_point=first_card.size-Vector2(100,3)
  if first_card._can_drop_data(local_point,block('backward')):first_card._drop_data(local_point,block('backward'))
  await process_frame;await process_frame
 else:
  await drag(editor.tiles[1].get_global_rect().get_center(),first_card.get_global_rect().end-Vector2(100,3))
 check(game.plan[0].map(func(c):return c.type)==['forward','backward'],'Dragging from a palette button into a card inserts at its bottom edge')
 first_card=game.cards.get_child(1)
 var second_card=game.cards.get_child(3)
 if DisplayServer.get_name()=='headless':
  var header=second_card.get_child(0).get_child(0).get_child(1)
  var local_point=header.get_global_transform_with_canvas().affine_inverse()*(second_card.get_global_rect().end-Vector2(100,3))
  if second_card._forward_can(local_point,move(0),header):second_card._forward_drop(local_point,move(0),header)
  await process_frame;await process_frame
 else:
  await drag(first_card.global_position+Vector2(120,22),second_card.get_global_rect().end-Vector2(100,3))
 check(game.plan[0].map(func(c):return c.type)==['backward','forward'],'Dragging a card header reorders through forwarded mouse events')
 game.plan[0]=[]
 for i in 30:game.plan[0].append({'type':'forward'})
 game._plan_changed();await process_frame;await process_frame
 tile.force_drag(block('forward'),Label.new())
 var edge=game.card_scroll.get_global_rect().end-Vector2(40,8)
 mouse_motion(edge)
 for i in 8:editor.drag_scroll(.05)
 check(game.card_scroll.scroll_vertical>0,'Dragging near the scroll edge scrolls a long program')
 mouse_button(Vector2(10,10),false)
 game._clear_robot();editor.insert(block('forward'),0)
 game.sim.outcome='running'
 check(not editor.can_insert(block('wait'),0),'Editing is locked during execution')
 editor.insert(block('wait'),0)
 check(game.plan[0].size()==1,'Rejected live drop cannot mutate the running program')
 game._reset()
 # Every distinct reference parameter form must preserve execution, including optional device and tick waits.
 var forms={}
 var all_preserved=true
 for level_id in 8:
  if level_id<6:game._change_stage(level_id)
  else:game._change_level(level_id-5)
  var source=game.sim.solution()
  for robot in game.sim.active_ids:
   game._select_robot(robot)
   for command in source[robot]:
    if command.type in ['end','else','forward','backward','left','right','select']:continue
    var key=command.type+'/'+str(command.get('condition',''))+'/'+str(command.get('device',''))+'/'+str(command.has('ticks'))+'/'+str(command.get('negate',false))
    if forms.has(key):continue
    forms[key]=true
    game.plan=[[],[],[]]
    game.plan[robot]=[command.duplicate(true)]
    if command.type=='if':game.plan[robot].append({'type':'else'})
    if command.type in ['repeat','while','if']:game.plan[robot].append({'type':'end'})
    game._plan_changed()
    f=open_fields(0)
    editor.apply_fields(f)
    var actual=game.plan[robot][0].duplicate(true)
    var expected=command.duplicate(true)
    for c in [actual,expected]:
     if c.type in ['condition','if','while']:
      c.negate=c.get('negate',false)
      if c.get('condition','') in ['laser_safe','camera_safe','guard_distracted']:c.ticks=c.get('ticks',0)
     if c.type in ['send','wait_signal']:c.value=c.get('value',true)
     if c.type=='wait':
      c.seconds=c.get('ticks',c.get('seconds',1)*20)/20.0;c.erase('ticks')
    if JSON.parse_string(JSON.stringify(actual))!=JSON.parse_string(JSON.stringify(expected)):
     all_preserved=false;print('MISMATCH ',expected,' -> ',actual)
    await process_frame
 check(all_preserved,'All '+str(forms.size())+' distinct reference parameter forms survive inline editing')
 game._change_stage(0);game._run_reference()
 while game.sim.outcome=='running':game.sim.step()
 game.board.state=game.sim.view();game._update_ui()
 await process_frame;await process_frame
 check(game.toast.get_global_rect().end.y<=900 and game.next_stage_button.get_global_rect().end.y<=900,'Victory layout still fits the viewport')
 game.queue_free();await process_frame;await process_frame
 print('BLOCK EDITOR RESULT ',passed,' passed; ',failed,' failed')
 quit(1 if failed else 0)
