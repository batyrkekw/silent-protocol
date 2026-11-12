extends RefCounted
## Incremental, visible execution of the same frozen plan across three security phases.
const Sim = preload('res://scripts/simulation_v5.gd')
const LIMIT = 12000
var active=false
var paused=false
var probe
var plan:Array=[]
var results:Array=[]
var scenario_count=3
var scenario=0
var level=2
var stage=0
var accumulator=0.0
var hold=0.0
var speed=8.0
var cancelled=false
func start(source, program:Array) -> bool:
 if source.level<2 or not Sim.validate(program).is_empty():return false
 scenario_count=source.data.scenarios.size()
 level=source.level;stage=source.stage;plan=program.duplicate(true);results.clear();scenario=0
 active=true;paused=false;cancelled=false;accumulator=0;hold=0
 _next();return true
func _next() -> void:
 probe=Sim.new();probe.set_level(level,stage,scenario);probe.record=false;probe.reset(plan);probe.start()
func step(delta:float) -> void:
 if not active or paused:return
 if hold>0:
  hold-=delta
  if hold>0:return
  if scenario==scenario_count-1:active=false;return
  scenario+=1;accumulator=0;_next()
 accumulator+=minf(delta,.25)*Sim.HZ*speed
 var budget=mini(int(accumulator),160)
 accumulator-=budget
 for i in budget:
  if probe.outcome!='running':break
  probe.step()
  if probe.tick>=LIMIT:break
 if probe.outcome!='running' or probe.tick>=LIMIT:
  var message='Успех' if probe.outcome=='won' else ('Лимит ожидания: программа не завершилась' if probe.outcome=='running' else str(probe.events.back().message))
  results.append({'scenario':scenario,'won':probe.outcome=='won','ticks':probe.tick,'reason':message})
  hold=1.2
func cancel() -> void:
 active=false;cancelled=true
func successes() -> int:
 return results.filter(func(row):return row.won).size()
func status_text() -> String:
 var lines:Array[String]=[]
 var titles=probe.data.scenarios.map(func(v):return v.name)
 for i in scenario_count:
  if i<results.size():lines.append(('%s  %s · %.2f с'%['✓' if results[i].won else '×',titles[i],results[i].ticks*Sim.STEP])+('' if results[i].won else '\n    '+results[i].reason))
  elif active and i==scenario:lines.append('▶  %s · %.1f с'%[titles[i],probe.tick*Sim.STEP])
  else:lines.append('·  '+titles[i]+' · ожидает')
 return '\n'.join(lines)
