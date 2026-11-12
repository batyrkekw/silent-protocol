extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
var frames=[]
var s=Sim.new()
func _initialize():call_deferred('audit')
func segment(a:Vector2i,b:Vector2i,facing:int,period:int)->Dictionary:
 var seq=[];var p=a
 for cell in s.route(a,b):
  var d=Sim.DIRECTIONS.find(cell-p);var turns=posmod(d-facing,4);turns=mini(turns,4-turns)
  for t in turns*5:seq.append(p)
  for t in period-1:seq.append(p)
  p=cell;seq.append(p);facing=d
 return {'cells':seq,'facing':facing}
func audit():
 s.set_level(3);s.record=false
 for t in 5000:
  frames.append({'pos':s.guard.pos,'facing':s.guard.facing})
  s._guard(s.guard)
 var rows=[]
 for loaded in [false,true]:
  var period=20 if loaded else 10
  var a=segment(Vector2i(20,10),Vector2i(14,13),1,period)
  var b=segment(Vector2i(14,13),Vector2i(8,11),a.facing,period)
  var found=[]
  # Cache sight per possible robot cell/tick: use real engine cone and wall rays.
  var sight={}
  for p in a.cells+b.cells:
   if sight.has(p):continue
   var seen=[]
   for frame in frames:seen.append(s.visible(frame.pos,frame.facing,p,s.guard.radius))
   sight[p]=seen
  for delay in range(0,1201,20):
   for dwell in range(0,1201,20):
    var detection=0;var alive=true;var t=delay
    for path in [a.cells,[Vector2i(14,13)],b.cells]:
     var cells=path
     if path.size()==1:cells=[];cells.resize(dwell);cells.fill(Vector2i(14,13))
     for p in cells:
      t+=1;detection=detection+1 if sight[p][t] else maxi(0,detection-2)
      if detection>=12 or p==frames[t].pos:alive=false;break
     if not alive:break
    if alive:found.append({'departure':delay,'niche_wait':dwell,'finish':t})
  print('LOADED=',loaded,' valid schedules=',found.size(),' first=',found.slice(0,3))
  if loaded:assert(found.is_empty())
  else:assert(not found.is_empty())
  rows.append({'loaded':loaded,'trials':3721,'successes':found.size(),'examples':found.slice(0,3)})
 var f=FileAccess.open('res://design/zero_minute/crossing_search.json',FileAccess.WRITE);f.store_string(JSON.stringify(rows,'  '));f.close()
 # Verify an empty-robot witness on the full interpreter (guard only for this isolated test).
 var witness=rows[0].examples[0];var trial=Sim.new();trial.set_level(3);trial.record=false
 var program=[{'type':'wait','ticks':witness.departure}];var pos=Vector2i(20,10);var facing=1
 for goal in [Vector2i(14,13),Vector2i(8,11)]:
  for next in trial.route(pos,goal):
   var direction=Sim.DIRECTIONS.find(next-pos);var turn=posmod(direction-facing,4)
   if turn==3:program.append({'type':'left'})
   else:
    for i in turn:program.append({'type':'right'})
   program.append({'type':'forward'});pos=next;facing=direction
  if goal==Vector2i(14,13) and witness.niche_wait:program.append({'type':'wait','ticks':witness.niche_wait})
 program.append({'type':'wait','ticks':1000});trial.reset([program,[],[]]);trial.active_ids=[0];trial.robots[0].pos=Vector2i(20,10);trial.robots[0].facing=1;trial.cameras=[];trial.lasers=[];trial.start()
 while trial.outcome=='running' and trial.robots[0].pos!=Vector2i(8,11) and trial.tick<3000:trial.step()
 assert(trial.outcome=='running' and trial.robots[0].pos==Vector2i(8,11))
 print('EMPTY ROBOT ACTUAL INTERPRETER: crossed at ',trial.tick,' without noise')
 quit()
