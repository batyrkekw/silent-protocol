extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
const Presentation=preload('res://scripts/presentation.gd')
var passed=0
var failures=0
var report={'version':6,'reference':[],'scenarios':[],'fixed':[],'ablations':[],'movement':{'step':10,'loaded_step':20,'turn':5}}
func check(ok:bool,label:String):
 if ok:passed+=1;print('PASS ',label)
 else:failures+=1;push_error(label)
func setup(id:int,variant:int=0):
 var s=Sim.new();s.set_level(0 if id<6 else id-5,id if id<6 else 0,variant);s.record=false;return s
func run(s,program:Array,limit:int=15000):
 s.reset(program);s.start()
 while s.outcome=='running' and s.tick<limit:s.step()
 return s
func _initialize():
 for id in 8:
  var s=setup(id);var p=s.solution()
  check(Sim.validate(p).is_empty() and p.all(func(program):return program.all(func(c):return c.type!='goto')),'Relative-only valid reference %d'%(id+1))
  run(s,p)
  check(s.outcome=='won','Reference %d wins at tick %d'%[id+1,s.tick])
  report.reference.append({'case':id+1,'tick':s.tick,'result':s.outcome,'milestones':s.events.filter(func(e):return e.kind in ['noise','hack','take','deposit'])})
  var repeat=setup(id);run(repeat,p);check(repeat.events==s.events,'Determinism case %d'%id)
  repeat.reset(p);repeat.start()
  while repeat.outcome=='running' and repeat.tick<15000:repeat.step();repeat.step()
  check(repeat.events==s.events,'x1/x2 identical case %d'%id)
  var initial=setup(id).view();s.reset([[],[],[]]);check(s.view()==initial,'Complete reset case %d'%id)
  if id>=7:
   check(s.data.guards[0].mode=='post','Mission %d has a stationary sentry'%id)
   for variant in 3:
    var trial=setup(id,variant);run(trial,p)
    check(trial.outcome=='won','Mission %d scenario %d wins'%[id+1,variant+1])
    check(trial.events.filter(func(e):return e.kind=='noise' and e.robot==1).size()>=6,'Camera operator distracts for every outward/return passage %d/%d'%[id+1,variant+1])
    report.scenarios.append({'mission':id+1,'scenario':variant+1,'tick':trial.tick,'result':trial.outcome})
   # Flatten a real successful run, retaining movements but replacing dynamic control by literal durations.
   var trace=setup(id);trace.reset(p);trace.start();var fixed=[[],[],[]];var elapsed=[0,0,0]
   while trace.outcome=='running' and trace.tick<15000:
    var old=trace.robots.map(func(r):return r.pc);trace.step()
    for robot in 3:
     if old[robot]>=p[robot].size():continue
     elapsed[robot]+=1
     if trace.robots[robot].pc!=old[robot]:
      var c=p[robot][old[robot]].duplicate(true)
      if c.type in ['condition','wait_signal','while','repeat','if','else','end','timer']:c={'type':'wait','ticks':elapsed[robot]}
      fixed[robot].append(c);elapsed[robot]=0
   var f=FileAccess.open('res://data/programs/%02d-fixed.json'%(id+1),FileAccess.WRITE);f.store_string(JSON.stringify(fixed,'  '));f.close()
   var shifted_failures=0
   for variant in 3:
    var trial=setup(id,variant);run(trial,fixed)
    if variant==0:check(trial.outcome=='won','Literal timeline remains valid on baseline %d'%(id+1))
    elif trial.outcome!='won':shifted_failures+=1
    report.fixed.append({'mission':id+1,'scenario':variant+1,'result':trial.outcome,'tick':trial.tick})
   check(shifted_failures>0,'Phase changes defeat literal timeline %d'%(id+1))
 # Relative movement: exact time, preserved orientation, collision without pathfinding.
 var s=setup(0);s.reset([[{'type':'forward'},{'type':'backward'},{'type':'right'},{'type':'forward'}],[],[]]);s.start()
 for i in 9:s.step()
 check(s.robots[0].pos==Vector2i(1,1),'Step does not teleport before tick 10')
 s.step();check(s.robots[0].pos==Vector2i(2,1),'Forward takes exactly 10 ticks')
 for i in 10:s.step()
 check(s.robots[0].pos==Vector2i(1,1) and s.robots[0].facing==0,'Backward takes 10 ticks and preserves heading')
 for i in 4:s.step()
 check(s.robots[0].facing==0,'Turn consumes time')
 s.step();check(s.robots[0].facing==1,'Quarter turn takes exactly 5 ticks')
 for i in 10:s.step()
 check(s.robots[0].pos==Vector2i(1,2),'Forward follows new orientation')
 s=setup(0);s.reset([[{'type':'forward'}],[],[]]);s.robots[0].carrying=true;s.start()
 for i in 19:s.step()
 check(s.robots[0].pos==Vector2i(1,1),'Loaded movement waits 20 ticks')
 s.step();check(s.robots[0].pos==Vector2i(2,1),'Loaded step finishes on tick 20')
 s=setup(0);s.reset([[{'type':'backward'}],[],[]]);s.start();s.step()
 check(s.outcome=='lost' and s.robots[0].pos==Vector2i(1,1),'Wall causes program error, no automatic detour')
 check(not Sim.validate([[{'type':'goto','target':[9,1]}],[],[]]).is_empty(),'Saved destination commands are rejected')
 s=setup(0);run(s,[[{'type':'goto','target':[9,1]}],[],[]]);check(s.outcome=='lost','Runtime cannot execute destination movement')
 s=setup(0);s.reset([[{'type':'forward'}],[],[]]);s.robots[0].pos=s.object("door1").pos-Vector2i.RIGHT;s.start()
 for i in 20:s.step()
 check(s.robots[0].pos==s.object('door1').pos-Vector2i.RIGHT,'Closed door blocks a step without consuming it')
 s.object('door1').open=true
 for i in 10:s.step()
 check(s.robots[0].pos==s.object('door1').pos,'Waiting step completes once door opens')
 # All three robots retain universal abilities; the reference role is not a class permission.
 for id in 3:
  s=setup(7);var p=[[],[],[]];p[id]=[{'type':'interact','object':'terminal2'}];s.reset(p);s.active_ids=[id];s.robots[id].pos=Vector2i(13,12);s.start()
  for i in 40:s.step()
  check(s.object('terminal2').off_until>0,'Robot %d can hack camera terminal'%id)
  p[id]=[{'type':'noise','target':[14,10]}];s.reset(p);s.active_ids=[id];s.robots[id].pos=Vector2i(13,12);s.start();s.step()
  check(s.guard.state=='investigate','Robot %d can distract sentry'%id)
  p[id]=[{'type':'interact','object':'item3'}];s.reset(p);s.active_ids=[id];s.robots[id].pos=Vector2i(17,5);s.lasers=[];s.guards=[];s.cameras=[];s.start()
  for i in 40:s.step()
  check(s.robots[id].carrying,'Robot %d can take an exhibit'%id)
 # Stationary posts never drift; brute-force crossing fails even with cameras and lasers removed.
 for mission in [7]:
  s=setup(mission);var post=s.guard.pos;var facing=s.guard.facing
  for i in 1500:s.tick+=1;s._guard(s.guard)
  check(s.guard.pos==post and s.guard.facing==facing,'Sentry remains on post indefinitely %d'%mission)
  var p=[[],[],[{'type':'repeat','count':8},{'type':'forward'},{'type':'end'}]]
  s.reset(p)
  for o in s.objects:
   if o.type=='door':o.mode='permanent';o.open=true
  s.active_ids=[2];s.cameras=[];s.lasers=[];s.robots[2].pos=Vector2i(21,9) if mission==7 else Vector2i(20,14);s.robots[2].facing=2 if mission==7 else 3;s.start()
  while s.outcome=='running' and s.tick<150:s.step()
  check(s.outcome=='lost' and 'охранник' in s.events.back().message,'Brute-force post crossing fails without noise %d'%mission)
  # Simulate a complete inspection/return and verify the staging bay is genuinely hidden.
  s=setup(mission);var target=Vector2i(14,10) if mission==7 else Vector2i(17,11)
  s.guard.noise=target;s.guard.state='investigate';var hidden=true
  for i in 500:
   s.tick+=1;s._guard(s.guard)
   hidden=hidden and not s.visible(s.guard.pos,s.guard.facing,s.object('staging').pos,2 if s.guard.state=='inspect' else s.guard.radius)
  check(hidden and s.guard.pos==post and s.guard.facing==facing,'Staging bay stays safe during entire guard return %d'%mission)
  var glass=Vector2i(13,11) if mission==7 else Vector2i(16,11)
  check(not s.walkable(glass) and s.line_clear(Vector2i(13,12),target),'Noise window allows sight but prevents walking shortcuts %d'%mission)
  var camera=s.cameras.back();s.tick=0;check(s.camera_on(camera),'Security camera starts active %d'%mission)
  s.object('terminal2').off_until=100;s.tick=99;check(not s.camera_on(camera),'Camera hack is active before deadline %d'%mission)
  s.tick=100;check(s.camera_on(camera),'Security camera recovers exactly at deadline %d'%mission)
  # Break one support subsystem at a time; these are finite regression attempts, not exhaustive proof.
  for removed in (['noise','camera','vault','button','plate'] if mission==8 else ['noise','camera','vault','button']):
   var trial=setup(mission);p=trial.solution()
   if removed=='plate':trial.data.objects=trial.data.objects.filter(func(o):return o.type!='plate')
   for robot in 3:
    for index in p[robot].size():
     var c=p[robot][index]
     var cut=c.type=='noise' if removed=='noise' else c.type=='interact' and (c.get('object','')=='terminal2' if removed=='camera' else (c.get('object','') in ['terminal1','terminal3'] if removed=='vault' else c.get('object','')=='button1' if removed=='button' else false))
     if cut:p[robot][index]={'type':'wait','ticks':1}
   run(trial,p,11000)
   check(trial.outcome!='won','Removing %s prevents mission %d completion'%[removed,mission+1])
   report.ablations.append({'mission':mission+1,'removed':removed,'result':trial.outcome,'tick':trial.tick})
 # Camera wall-corner regression from the prior task remains valid.
 for variant in 3:
  s=setup(7,variant);var cam=s.cameras[0];var correct=true
  for t in 200:
   s.tick=t
   for cell in [Vector2i(4,8),Vector2i(4,10)]:correct=correct and s.camera_sees(cam,cell)==s.camera_on(cam)
  check(correct,'CAM1 covers both approaches throughout phase cycle %d'%variant)
 s=setup(6);check(not s.line_clear(Vector2i(7,3),Vector2i(7,5)),'Walls still block sight')
 # Signal, timer and occupied-door timing.
 s=setup(2);s.reset([[{'type':'send','signal':'A'}],[{'type':'wait_signal','signal':'A'}],[]]);s.start();s.step()
 check(s.robots[1].pc==0,'Signals do not arrive during the sender tick')
 s.step();check(s.robots[1].pc==1,'Signals arrive on the next tick')
 s=setup(0);s.reset([[{'type':'timer','timer':'T','seconds':.5},{'type':'forward'},{'type':'condition','condition':'timer_done','timer':'T'}],[],[]]);s.start()
 for i in 12:s.step()
 check(s.robots[0].pc==3 and s.tick==12,'Timer runs in parallel with step execution')
 s=setup(7);var door=s.object('door1');door.until=1;s.tick=2;s.robots[0].pos=door.pos;s._devices();check(door.open,'Occupied heavy door cannot close')
 s.robots[0].pos=Vector2i(17,7);s._devices();check(not door.open,'Expired heavy door closes when vacated')
 s=setup(6);s.robots[1].pos=s.robots[0].pos;var poses=Presentation.layout(s.robots,Vector2(30,30),.5)
 check(poses[0].position==poses[1].position,'Shared cell never pushes another robot')
 var anchor=poses[0].position;s.robots[1].pos+=Vector2i.RIGHT
 check(Presentation.layout(s.robots,Vector2(30,30),.5)[0].position==anchor,'Neighbor movement cannot displace a stationary robot')
 report.passed=passed;report.failures=failures
 var out=FileAccess.open('res://design/verification.json',FileAccess.WRITE);out.store_string(JSON.stringify(report,'  '));out.close()
 print('SPEC RESULT ',passed,' passed; ',failures,' failed');quit(1 if failures else 0)
