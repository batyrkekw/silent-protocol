extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
var sim=Sim.new()
var plans=[[],[],[]]
var pos=[Vector2i(3,13),Vector2i(3,14),Vector2i(3,15)]
var face=[0,0,0]
func _initialize():call_deferred('build')
func add(id:int,c:Dictionary):plans[id].append(c)
func cond(id:int,name:String,device:String='',ticks:int=0,after:int=0):
 var c={'type':'condition','condition':name}
 if device!='':c.device=device
 if ticks:c.ticks=ticks
 if after:c.after_ticks=after
 add(id,c)
func signal_set(id:int,key:String,value:bool=true):add(id,{'type':'send','signal':key,'value':value})
func await_signal(id:int,key:String,value:bool=true):add(id,{'type':'wait_signal','signal':key,'value':value})
func turn(id:int,dir:int):
 var n=posmod(dir-face[id],4)
 if n==3:add(id,{'type':'left'})
 else:
  for i in n:add(id,{'type':'right'})
 face[id]=dir
func walk(id:int,target:Vector2i):
 for cell in sim.route(pos[id],target):
  turn(id,Sim.DIRECTIONS.find(cell-pos[id]));add(id,{'type':'forward'});pos[id]=cell
func use(id:int,obj:String):add(id,{'type':'interact','object':obj})
func start_west(id:int):
 walk(id,Vector2i(4,12));turn(id,3);cond(id,'camera_safe','CAM1',30);walk(id,Vector2i(4,10))
func west_to_button(id:int):
 walk(id,Vector2i(4,12));turn(id,3);cond(id,'camera_safe','CAM1',75);walk(id,Vector2i(4,11));walk(id,Vector2i(8,11));walk(id,Vector2i(8,12));turn(id,3)
func noise(id:int,key:String,returning:bool=false):
 walk(id,Vector2i(4,8)) if pos[id].x<10 else null
 walk(id,Vector2i(13,8));cond(id,'noise_ready');cond(id,'guard_horizontal');walk(id,Vector2i(14,9));await_signal(id,key)
 # Synchronize noise to camera/laser phases, rather than to elapsed mission time.
 if returning:
  cond(id,'laser_safe','LZ_M',50,60)
  cond(id,'camera_safe','CAM1',130,240)
 else:
  cond(id,'camera_safe','CAM1',140)
 add(id,{'type':'noise','target':[14,13]});signal_set(id,key+'_GO');signal_set(id,key,false)
 walk(id,Vector2i(13,8))
func east(id:int,key:String,target:Vector2i):
 signal_set(id,key);await_signal(id,key+'_GO');walk(id,Vector2i(8,11));walk(id,Vector2i(20,11));walk(id,Vector2i(20,10));walk(id,target)
func west(id:int,key:String):
 walk(id,Vector2i(20,10));turn(id,1);signal_set(id,key);await_signal(id,key+'_GO')
 walk(id,Vector2i(20,11));walk(id,Vector2i(8,11));walk(id,Vector2i(4,11));walk(id,Vector2i(4,12));walk(id,Vector2i(1,13));use(id,'exit1')
func build():
 sim.set_level(3)
 start_west(0)
 west_to_button(1);west_to_button(2)
 walk(0,Vector2i(4,8));walk(0,Vector2i(13,8));turn(0,2)
 for id in 3:add(id,{'type':'repeat','count':2})
 for round in 1:
  var key='G'
  noise(0,key+'_EAST')
  walk(0,Vector2i(4,8));walk(0,Vector2i(3,2));await_signal(0,key+'_READY');signal_set(0,key+'_READY',false);cond(0,'terminal_ready','T_S');use(0,'T_S');signal_set(0,key+'_WINDOW')
  noise(0,key+'_WEST',true);signal_set(0,key+'_WINDOW',false)
  await_signal(1,key+'_WINDOW');use(1,'B_G');add(1,{'type':'timer','timer':'DOOR','seconds':5.8});cond(1,'timer_done','');plans[1][-1].timer='DOOR';use(1,'B_G');await_signal(1,key+'_WINDOW',false)
  east(2,key+'_EAST',Vector2i(20,8));turn(2,3);add(2,{'type':'select'});signal_set(2,key+'_READY');await_signal(2,key+'_WINDOW');cond(2,'door_open','D_G');cond(2,'laser_safe','gallery',210)
  walk(2,Vector2i(20,6))
  add(2,{'type':'while','condition':'selected_near','negate':true});add(2,{'type':'forward'});add(2,{'type':'end'})
  use(2,'selected')
  add(2,{'type':'if','condition':'at_marker','device':'far'});add(2,{'type':'repeat','count':4});add(2,{'type':'backward'});add(2,{'type':'end'});add(2,{'type':'end'})
  add(2,{'type':'backward'});add(2,{'type':'backward'});pos[2]=Vector2i(20,8);west(2,key+'_WEST')
  signal_set(2,key+'_EAST_GO',false);signal_set(2,key+'_WEST_GO',false);await_signal(2,key+'_WINDOW',false);west_to_button(2)
 for id in 3:add(id,{'type':'end'})
 # Bring both carrier and plate operator east on the same distraction.
 signal_set(2,'VAULT_ASSEMBLED')
 await_signal(1,'VAULT_ASSEMBLED');east(1,'V_EAST',Vector2i(22,12));signal_set(1,'PLATE')
 await_signal(2,'V_EAST_GO');walk(2,Vector2i(8,11));walk(2,Vector2i(20,11));walk(2,Vector2i(24,11));walk(2,Vector2i(24,12));turn(2,1);signal_set(2,'VAULT_READY')
 noise(0,'V_EAST');walk(0,Vector2i(4,8));walk(0,Vector2i(4,10));turn(0,1);cond(0,'camera_safe','CAM1',30);walk(0,Vector2i(4,12));walk(0,Vector2i(4,16));await_signal(0,'PLATE');await_signal(0,'VAULT_READY');cond(0,'terminal_ready','T_V');use(0,'T_V');signal_set(0,'VAULT_WINDOW')
 start_west(0);noise(0,'V_WEST',true)
 await_signal(2,'VAULT_WINDOW');cond(2,'door_open','D_V');walk(2,Vector2i(24,15));use(2,'A');turn(2,3);walk(2,Vector2i(24,12));signal_set(2,'VAULT_OUT');walk(2,Vector2i(24,11));walk(2,Vector2i(20,11));walk(2,Vector2i(20,10));signal_set(2,'CARRIER_ASSEMBLED');await_signal(2,'HOLDER_ASSEMBLED');west(2,'V_WEST')
 await_signal(1,'VAULT_OUT');walk(1,Vector2i(22,11));walk(1,Vector2i(20,11));walk(1,Vector2i(20,10));turn(1,1);signal_set(1,'HOLDER_ASSEMBLED');await_signal(1,'V_WEST_GO');var escort_start=plans[1].size();walk(1,Vector2i(20,11));walk(1,Vector2i(4,11));walk(1,Vector2i(4,12));walk(1,Vector2i(1,14))
 for idx in range(plans[1].size()-1,escort_start-1,-1):
  if plans[1][idx].type=='forward':plans[1].insert(idx,{'type':'wait','ticks':10})
 walk(0,Vector2i(4,8));walk(0,Vector2i(4,10));turn(0,1);cond(0,'camera_safe','CAM1',30);walk(0,Vector2i(4,12));walk(0,Vector2i(1,15))
 var file=FileAccess.open('res://data/programs/09.json',FileAccess.WRITE);file.store_string(JSON.stringify(plans,'  '));file.close()
 print('PROGRAM BLOCKS ',plans.map(func(p):return p.size()))
 for variant in 4:
  var s=Sim.new();s.set_level(3,0,variant);s.record=false;s.reset(plans);s.start()
  while s.outcome=='running' and s.tick<16000:s.step()
  print('VARIANT ',variant,' ',s.outcome,' at ',s.tick,' ',s.events.back())
  for r in s.robots:print('robot ',r.id,' ',r.pos,' pc=',r.pc,' ',r.status)
 quit()
