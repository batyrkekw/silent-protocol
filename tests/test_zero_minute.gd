extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
var passed=0
var failed=0
var report={'scenarios':[],'fixed':[],'exposure':[],'milestones':[],'pairs':[],'solo_trials':0,'noise_windows':[]}
func check(ok:bool,label:String):
 if ok:passed+=1
 else:failed+=1;push_error(label)
 print('PASS ' if ok else 'FAIL ',label)
func setup(variant:int=0):
 var s=Sim.new();s.set_level(3,0,variant);s.record=false;return s
func run(s,p:Array,limit:int=15000,batch:int=1):
 s.reset(p);s.start()
 while s.outcome=='running' and s.tick<limit:
  for i in batch:s.step()
 return s
func _initialize():call_deferred('audit')
func audit():
 var s=setup();var p=s.solution();check(Sim.validate(p).is_empty(),'Reference is a valid relative-command program')
 var fixed=[[],[],[]];var elapsed=[0,0,0];var exposure={};var camera_crossings=0;var safe_crossings=true;var return_safe=true;var outside=-1
 s.reset(p);s.start()
 while s.outcome=='running' and s.tick<15000:
  var old=s.robots.map(func(r):return r.pc);s.step()
  for id in 3:
   var r=s.robots[id]
   if old[id]<p[id].size():
    elapsed[id]+=1
    if r.pc!=old[id]:
     var c=p[id][old[id]].duplicate(true)
     if c.type in ['condition','wait_signal','while','repeat','if','else','end','timer']:c={'type':'wait','ticks':elapsed[id]}
     fixed[id].append(c);elapsed[id]=0
   if r.pos==Vector2i(4,11):camera_crossings+=1;safe_crossings=safe_crossings and not s.camera_on(s.cameras[0])
   for l in s.lasers:
    if l.id=='LZ_M':continue
    var key=str(id)+l.id
    if r.pos in l.cells and not exposure.has(key):exposure[key]={'robot':id,'zone':l.id,'entry':s.tick}
    if r.pos not in l.cells and exposure.has(key):
     var row=exposure[key];row.exit=s.tick;row.ticks=s.tick-row.entry;row.laser_deadline=s.object('T_S' if l.id=='gallery' else 'T_V').off_until;row.margin=row.laser_deadline-s.tick;report.exposure.append(row);exposure.erase(key)
  if s.guard.pos.y>11 and outside<0:outside=s.tick
  elif s.guard.pos.y==11 and outside>=0:report.noise_windows.append({'entry':outside,'return':s.tick,'duration':s.tick-outside});outside=-1
  if s.guard.state=='return':return_safe=return_safe and s.robots[0].pos.x!=14
 check(s.outcome=='won','1. Baseline wins at '+str(s.tick))
 report.milestones=s.events.filter(func(e):return e.kind in ['noise','hack','take','deposit','door','won'])
 check(safe_crossings and camera_crossings>0,'All three robots cross (4,11) only during CAM1 inactivity')
 check(return_safe,'Thrower leaves x=14 before the guard returns north')
 var baseline=s.events.duplicate(true)
 check(run(setup(),p).events==baseline,'2. Repeated run is deterministic')
 check(run(setup(),p,15000,2).events==baseline,'2. x1/x2 tick batches produce identical logs')
 var f=FileAccess.open('res://data/programs/09-fixed.json',FileAccess.WRITE);f.store_string(JSON.stringify(fixed,'  '));f.close()
 var fragile_failures=0
 for variant in 4:
  s=run(setup(variant),p);report.scenarios.append({'scenario':variant+1,'result':s.outcome,'ticks':s.tick});check(s.outcome=='won','9. Conditional reference scenario '+str(variant+1))
  var initial=setup(variant).view();s.reset(p);check(s.view()==initial and s.pending_signals.is_empty(),'10. Full reset scenario '+str(variant+1))
  s=run(setup(variant),fixed);report.fixed.append({'scenario':variant+1,'result':s.outcome,'ticks':s.tick,'reason':s.events.back().message})
  if variant==0:check(s.outcome=='won','9. Fixed timeline wins its baseline')
  elif s.outcome!='won':fragile_failures+=1
 check(fragile_failures>=2,'9. Fixed timeline fails at least two shifted scenarios: '+str(fragile_failures))
 for row in report.exposure:check(row.margin>0,'6. '+row.zone+' exposure '+str(row.ticks)+' ticks; margin '+str(row.margin))
 check(report.exposure.size()==3,'6. Exactly three artifact laser-zone visits')
 check(report.exposure[1].margin>=40,'6. E2 retains at least 40 ticks after the final laser cell')
 check(report.noise_windows.all(func(w):return w.duration>=11*20+20),'5. Noise absence window >= 220 crossing ticks + 20 reserve')
 var without_second=p.duplicate(true)
 var buttons=0
 for c in without_second[1]:
  if c.type=='interact' and c.get('object','')=='B_G':
   buttons+=1
   if buttons==2:c.clear();c.merge({'type':'wait','ticks':1})
 check(run(setup(),without_second).outcome=='lost','4. Omitting the second button press loses the E2 run')
 s=setup()
 # Analytical lower bounds include every legal adjacent interaction cell, not only nominated stands.
 var ts=[];var tv=[];var bg=[]
 for o in [s.object('T_S'),s.object('T_V'),s.object('B_G')]:
  var cells=[]
  for d in [Vector2i.ZERO]+Sim.DIRECTIONS:
   if s.walkable(o.pos+d):cells.append(o.pos+d)
  if o.id=='T_S':ts=cells
  elif o.id=='T_V':tv=cells
  else:bg=cells
 var hack_button=999;var button_door=999;var hack_door=999;var vault_plate=999;var vault_door=999
 for a in ts:
  hack_door=mini(hack_door,s.route(a,Vector2i(20,7)).size()*10)
  for b in bg:hack_button=mini(hack_button,s.route(a,b).size()*10)
 for b in bg:button_door=mini(button_door,s.route(b,Vector2i(20,7)).size()*10)
 for a in tv:
  vault_plate=mini(vault_plate,s.route(a,Vector2i(22,12)).size()*10);vault_door=mini(vault_door,s.route(a,Vector2i(24,13)).size()*10)
 for pair in [[0,1],[0,2],[1,2]]:
  var row={'robots':pair,'TS_to_button_min_ticks':hack_button,'authorization_ticks':60,'button_to_door_min_ticks':button_door,'door_ticks':120,'TS_to_door_min_ticks':hack_door,'gallery_window':260,'TV_to_plate_min_ticks':vault_plate,'TV_to_door_min_ticks':vault_door,'vault_window':160}
  report.pairs.append(row)
  check(hack_button>60 and button_door>120 and hack_door>260,'4. Gallery role-merging barriers for pair '+str(pair))
  check(vault_plate>180 and vault_door>180,'4. Vault role-merging barriers for pair '+str(pair))
 # The previous concrete pair exploit cannot open the gallery before a hack.
 var old=JSON.parse_string(FileAccess.get_file_as_string('res://design/zero_minute/pair_counterexamples.json'))[0].programs
 s=setup();s.reset(old);s.robots[0].pos=Vector2i(8,12);s.robots[1].pos=Vector2i(20,8);s.active_ids=[0,1];s.start()
 for t in 1000:s.step()
 check(not s.object('D_G').open and not s.robots[1].carrying,'4. Saved two-robot doorway exploit is rejected')
 # Door occupant does not extend a hard deadline; plate door retains its specified hold.
 s=setup();s.reset([[{'type':'wait','ticks':200}],[],[]]);s.active_ids=[0];s.robots[0].pos=Vector2i(20,7);s.object('D_G').until=120;s._devices();s.start()
 for t in 120:s.step()
 check(s.outcome=='lost' and not s.object('D_G').open,'4. Occupied gallery doorway closes at tick 120')
 s=setup();s.robots[0].pos=Vector2i(24,13);s._devices();check(s.object('D_V').open,'4. Plate door still holds while occupied')
 # Solo attempt: hack, travel, take; enumerate waits on each phase using real movement and hazard checks.
 var solo_template=load('res://tests/zero_helpers.gd').new()
 for id in 3:
  for phase in ['gallery','vault']:
   for delay in range(0,1201,20):
    s=setup();var program=solo_template.solo(s,id,phase,delay);s.reset(program);s.active_ids=[id];s.start()
    while s.outcome=='running' and s.tick<2500:s.step()
    if s.outcome=='won' or s.items().any(func(o):return o.delivered):failed+=1;push_error('Solo bypass')
    report.solo_trials+=1
 check(report.solo_trials==366,'3. 366 solo attempts (3 robots × 2 phases × 61 waits), no deliveries')
 # Noise cooldown, line of sight, radius, unknown signals and objects.
 s=setup();s.reset([[{'type':'noise','target':[14,13]}],[],[]]);s.robots[0].pos=Vector2i(14,9);s.active_ids=[0];s.robots[0].noise_ready=120;s.start()
 for i in 119:s.step()
 check(s.events.filter(func(e):return e.kind=='noise').is_empty(),'8. Initial noise cooldown blocks early throws')
 s.step();check(s.events.filter(func(e):return e.kind=='noise').size()==1,'8. Noise executes at cooldown boundary')
 s.robots[0].pc=0;s.robots[0].last_pc=-1;s.outcome='running';s.tick=121;s._robot(0)
 check(s.robots[0].pc==0 and s.events.filter(func(e):return e.kind=='noise').size()==1,'8. Second throw cannot bypass cooldown')
 s=setup();check(not s.validate_world([[{'type':'noise','target':[14,13]}],[],[]]).is_empty(),'8. Out-of-range noise rejected before execution')
 check(not s.validate_world([[{'type':'wait_signal','signal':'MISSING'}],[],[]]).is_empty(),'Validator reports signals without a sender')
 check(not s.validate_world([[{'type':'interact','object':'D_G'}],[],[]]).is_empty(),'Validator rejects interaction with non-interactable object')
 check(not Sim.validate([[{'type':'condition','condition':'laser_safe','after_ticks':-1}],[],[]]).is_empty(),'Forecast offset validated')
 report.passed=passed;report.failed=failed
 f=FileAccess.open('res://design/zero_minute/verification.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close()
 print('ZERO MINUTE TESTS: ',passed,' passed, ',failed,' failed')
 quit(1 if failed else 0)
