extends RefCounted
const Sim=preload('res://scripts/simulation_v5.gd')
func solo(s,id:int,phase:String,delay:int)->Array:
 var plans=[[],[],[]];var p=plans[id];var pos=Vector2i(3,13+id);var face=0
 var terminal=Vector2i(3,2) if phase=='gallery' else Vector2i(4,16)
 var target=Vector2i(20,6) if phase=='gallery' else Vector2i(24,15)
 for goal in [terminal,target,Vector2i(1,13)]:
  for next in s.route(pos,goal):
   var d=Sim.DIRECTIONS.find(next-pos);var turns=posmod(d-face,4)
   if turns==3:p.append({'type':'left'})
   else:
    for i in turns:p.append({'type':'right'})
   p.append({'type':'forward'});pos=next;face=d
  if goal==terminal:
   p.append({'type':'interact','object':'T_S' if phase=='gallery' else 'T_V'})
   if delay:p.append({'type':'wait','ticks':delay})
  elif goal==target:p.append({'type':'interact','object':'E1' if phase=='gallery' else 'A'})
  else:p.append({'type':'interact','object':'exit1'})
 return plans
