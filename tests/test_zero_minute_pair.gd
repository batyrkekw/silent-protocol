extends SceneTree
## Historical reproduction using the OLD door rule. Current regression: test_zero_minute.gd.
const Sim=preload('res://scripts/simulation_v5.gd')
var grid=JSON.parse_string(FileAccess.get_file_as_string('res://design/zero_minute/preflight.json')).grid
func _initialize():call_deferred('audit')
func world(window:int):
 var s=Sim.new();s.level=3;s.width=28;s.height=18;s.walls.clear()
 for y in 18:
  for x in 28:
   if grid[y][x]=='#':s.walls[Vector2i(x,y)]=true
 s.data={'grid':grid,'name':'Gallery pair audit','robots':[{'id':0,'pos':[8,12]},{'id':1,'pos':[20,8]}],
 'objects':[{'id':'T_S','type':'terminal','pos':[2,2],'hack':60,'window':window,'cooldown':400,'circuit':'gallery'},
 {'id':'B_G','type':'button','pos':[8,12],'door':'D_G'},
 {'id':'D_G','type':'door','pos':[20,7],'mode':'heavy','duration':120},
 {'id':'E1','type':'item','pos':[19,6],'name':'E1'},
 {'id':'E2','type':'item','pos':[19,2],'name':'E2'},
 {'id':'exit','type':'exit','pos':[1,13]}],
 'guards':[{'pos':[12,11],'facing':[-1,0],'route':[[16,11],[12,11]],'index':0,'wait':60,'pause':60,'radius':4,'inspect':180}],
 'cameras':[{'id':'CAM1','pos':[1,11],'facing':[1,0],'cells':[],'phase':0,'period':240,'active':80}],
 'lasers':[{'id':'gallery','circuit':'gallery','cells':[]},{'id':'LZ_M','cells':[[18,11]],'phase':0,'period':240,'off_start':160,'off_length':80}]}
 for x in range(2,9):s.data.cameras[0].cells.append([x,11])
 for y in range(2,7):
  for x in range(18,23):
   if Vector2i(x,y) not in [Vector2i(19,2),Vector2i(19,6)]:s.data.lasers[0].cells.append([x,y])
 s.reset([[],[],[]]);s.record=false;return s
func walk(s,plan:Array,pos:Vector2i,facing:int,target:Vector2i)->int:
 for step in s.route(pos,target):
  var direction=Sim.DIRECTIONS.find(step-pos)
  var turn=posmod(direction-facing,4)
  if turn==3:plan.append({'type':'left'})
  else:
   for i in turn:plan.append({'type':'right'})
  plan.append({'type':'forward'});pos=step;facing=direction
 return facing
func audit():
 var results=[]
 for window in [220,240,260]:
  var found=false
  for delay in range(0,481,5):
   var s=world(window)
   var a:Array=[{'type':'wait','ticks':80},{'type':'interact','object':'B_G'},{'type':'send','signal':'OPEN'}]
   var facing=walk(s,a,Vector2i(8,12),0,Vector2i(3,2))
   if delay>0:a.append({'type':'wait','ticks':delay})
   a.append({'type':'interact','object':'T_S'});a.append({'type':'send','signal':'HACKED'})
   walk(s,a,Vector2i(3,2),facing,Vector2i(8,12));a.append({'type':'interact','object':'B_G'});a.append({'type':'wait','ticks':300})
   var b:Array=[{'type':'wait_signal','signal':'OPEN'}]
   facing=walk(s,b,Vector2i(20,8),0,Vector2i(20,7));b.append({'type':'wait_signal','signal':'HACKED'})
   facing=walk(s,b,Vector2i(20,7),facing,Vector2i(20,2));b.append({'type':'interact','object':'E2'})
   walk(s,b,Vector2i(20,2),facing,Vector2i(20,8));b.append({'type':'wait','ticks':300})
   s.reset([a,b,[]]);s.start()
   var entered=-1;var left=-1
   while s.outcome=='running' and s.tick<2000:
    s.step()
    if entered<0 and s.robots[1].pos==Vector2i(20,6):entered=s.tick
    if s.robots[1].carrying and s.robots[1].pos==Vector2i(20,7) and left<0:left=s.tick
    if s.robots[1].carrying and s.robots[1].pos==Vector2i(20,8):
     var row={'window':window,'delay_before_hack':delay,'tick_outside':s.tick,'laser_entry':entered,'laser_exit':left,'events':s.events.duplicate(true),'programs':[a,b,[]]}
     results.append(row);found=true
     print('COUNTEREXAMPLE window=',window,' delay=',delay,' E2 outside at=',s.tick,' laser exposure=',left-entered)
     break
   if found:break
  if not found:print('No pair example in tested delays for window ',window)
 var file=FileAccess.open('res://design/zero_minute/pair_counterexamples.json',FileAccess.WRITE);file.store_string(JSON.stringify(results,'  '));file.close()
 var validation={'windows_passed':[],'timeline':{},'determinism':false,'double_tick_batches':false,'reset_restores_state':false}
 if not results.is_empty():
  var program=results[0].programs
  var standard=[]
  for window in range(220,261):
   var s=world(window);s.reset(program);var initial=s.view();s.start()
   var door_enter=-1
   while s.outcome=='running' and s.tick<664:
    s.step()
    if door_enter<0 and s.robots[1].pos==Vector2i(20,7):door_enter=s.tick
   assert(s.outcome=='running' and s.robots[1].carrying and s.robots[1].pos==Vector2i(20,8))
   validation.windows_passed.append(window)
   if window==240:
    standard=s.events.duplicate(true)
    validation.timeline={'door_first_occupied':door_enter,'hack_complete':442,'laser_entry':454,'take_complete':534,'second_press':614,'laser_exit':644,'vestibule':664}
    s.reset(program);validation.reset_restores_state=s.view()==initial
  for batch in [1,2]:
   var s=world(240);s.reset(program);s.start()
   while s.outcome=='running' and s.tick<664:
    for i in batch:s.step()
   if batch==1:validation.determinism=s.events==standard
   else:validation.double_tick_batches=s.events==standard
  var output=FileAccess.open('res://design/zero_minute/pair_validation.json',FileAccess.WRITE);output.store_string(JSON.stringify(validation,'  '));output.close()
  print('ALL WINDOWS: ',validation.windows_passed.size(),' / 41; deterministic=',validation.determinism,' x2=',validation.double_tick_batches,' reset=',validation.reset_restores_state)
 print('PAIR AUDIT: ',results.size(),' counterexamples. This tests the gallery phase, not a complete two-robot level solution.')
 quit()
