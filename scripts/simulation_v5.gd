class_name ProtocolSimulation
extends RefCounted
const HZ=20
const STEP=0.05
const MAX_TICKS=20000 # Test watchdog, not a mission deadline.
const LEVEL_VERSION=6
const NAMES=["ЛУВР","МОНА","ЛИЗА"]
const COLORS=[Color("62daca"),Color("cf9cff"),Color("f4ba73")]
const DIRECTIONS=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
const LEVEL_NAMES=["Туториал","Закрытая галерея","Ночная смена","Нулевая минута"]
const CONDITIONS=["camera_off","laser_safe","terminal_ready","door_open","guard_busy","guard_west","items_free","items_pending","signal_on","signal_off","timer_done","front_clear","carrying","camera_safe","guard_in_niche","ready_or_done","all_delivered","selected_near","at_marker","guard_distracted","guard_posted","noise_ready","plate_occupied","guard_patrol","guard_paused","guard_returning","guard_investigating","guard_going_to_noise","guard_east","camera_active","laser_on","guard_horizontal"]
var level=0
var stage=0
var scenario=0
var width=0
var height=0
var data:Dictionary
var layout:Dictionary
var objects:Array=[]
var robots:Array=[]
var guards:Array=[]
var cameras:Array=[]
var lasers:Array=[]
var walls:Dictionary={}
var tick=0
var outcome="planning"
var plans:Array=[[],[],[]]
var signals:Dictionary={}
var pending_signals:Array=[]
var timers:Array=[{},{},{}]
var events:Array=[]
var snapshots:Array=[]
var practiced:Dictionary={}
var active_ids:Array=[]
var record=true
var guard:Dictionary={}
var exit_cell=Vector2i.ZERO
var terminal=Vector2i.ZERO
var laser_terminal=Vector2i.ZERO
var artifact=Vector2i.ZERO
var noise_point=Vector2i.ZERO
var camera=Vector2i.ZERO
var artifact_taken=false
var camera_until=0
var laser_until=0
var link_owner=-1
var key_until=0
var lockdown_until=0
var decoys:Array=[]
var laser_cells:Array=[]
var guard_patrol:Array=[]
func _init():set_level(0)
func set_level(index:int,lesson:int=0,variant:int=0):
 level=clampi(index,0,LEVEL_NAMES.size()-1);stage=clampi(lesson,0,5);scenario=variant
 var id=stage if level==0 else level+5
 data=JSON.parse_string(FileAccess.get_file_as_string('res://data/levels/%02d.json'%(id+1)))
 width=data.grid[0].length();height=data.grid.size();walls.clear()
 for y in height:
  for x in width:
   if data.grid[y][x]=='#':walls[Vector2i(x,y)]=true
 layout={"name":data.name,"prize":"Экспонаты","start":to_cell(data.robots[0].pos),"rooms":[],"labels":[]}
 reset([[],[],[]])
func reset(new_plans:Array):
 plans=new_plans.duplicate(true);tick=0;outcome='planning';signals.clear();pending_signals.clear();events.clear();snapshots.clear();timers=[{},{},{}];practiced.clear();active_ids.clear();robots.clear();artifact_taken=false
 objects=data.objects.duplicate(true)
 for o in objects:
  o.pos=to_cell(o.pos)
  if o.type=='door':o.open=false;o.until=0
  if o.type=='terminal':o.off_until=0;o.ready=0;o.hacked_at=-99999;terminal=o.pos;laser_terminal=o.pos
  if o.type=='item':o.owner=-1;o.delivered=false;o.carrier=-1;artifact=o.pos
  if o.type=='exit':exit_cell=o.pos
 for i in 3:
  var start=Vector2i(-20,-20)
  for spawn in data.robots:
   if int(spawn.id)==i:start=to_cell(spawn.pos);active_ids.append(i)
  robots.append({"id":i,"pos":start,"previous":start,"facing":0,"pc":0,"elapsed":0,"path":[],"move_clock":0,"move_period":10,"carrying":false,"item":"","target_item":"","loops":{},"status":"Готов","blocked":false,"detection":0,"noise_ready":0,"last_pc":-1,"route":[],"target":Vector2i(-1,-1)})
 guards=data.guards.duplicate(true)
 for g in guards:
  g.pos=to_cell(g.pos);g.previous=g.pos;g.facing=to_cell(g.facing);g.route=g.route.map(func(p):return to_cell(p));g.clock=0;g.state='patrol';g.noise=g.pos;g.patrol_index=int(g.index);g.post_facing=g.facing
 cameras=data.cameras.duplicate(true)
 for c in cameras:c.pos=to_cell(c.pos);c.facing=to_cell(c.facing);c.cells=c.cells.map(func(p):return to_cell(p))
 lasers=data.lasers.duplicate(true);laser_cells=[]
 for l in lasers:l.cells=l.cells.map(func(p):return to_cell(p));laser_cells+=l.cells
 if not data.get('scenarios',[]).is_empty():
  var v=data.scenarios[clampi(scenario,0,data.scenarios.size()-1)]
  for i in mini(v.laser_phases.size(),lasers.size()):lasers[i].phase=int(v.laser_phases[i])
  cameras[0].phase=int(v.camera_phase)
  guards[0].pos=to_cell(v.guard_pos);guards[0].previous=guards[0].pos;guards[0].facing=to_cell(v.guard_facing);guards[0].wait=int(v.guard_wait);guards[0].patrol_index=int(v.guard_index)
  if v.has('terminal_cooldowns'):
   for key in v.terminal_cooldowns:object(key).ready=int(v.terminal_cooldowns[key])
  else:object('terminal1').ready=int(v.terminal_remaining)
  for r in robots:r.noise_ready=int(v.get('noise_remaining',0))
  if guards[0].get('mode','')=='post':guards[0].post_facing=guards[0].facing
 guard=guards[0] if not guards.is_empty() else {"pos":Vector2i(-10,-10),"previous":Vector2i(-10,-10),"facing":Vector2i.RIGHT,"state":"patrol","clock":0,"noise":Vector2i(-10,-10),"patrol_index":0,"wait":0}
 guard_patrol=guard.get('route',[Vector2i(-10,-10)])
 camera=cameras[0].pos if not cameras.is_empty() else Vector2i(-10,-10)
 noise_point=Vector2i(6,5)
 _devices();_record_snapshot()
func object(id:String)->Dictionary:
 for o in objects:
  if o.id==id:return o
 return {}
func items()->Array:return objects.filter(func(o):return o.type=='item')
func exits()->Array:return objects.filter(func(o):return o.type=='exit').map(func(o):return o.pos)
func start():
 var errors=validate(plans)
 if level==3 and errors.is_empty():errors=validate_world(plans)
 if not errors.is_empty():outcome='lost';log_event(errors[0],'lost');return
 outcome='running';log_event('Операция началась','start')
func walkable(p:Vector2i)->bool:
 if p.x<0 or p.y<0 or p.x>=width or p.y>=height or walls.has(p):return false
 if data.grid[p.y][p.x]=="W":return false
 for o in objects:
  if o.type=='item' and o.pos==p:return false
 return true
func passable(p:Vector2i)->bool:
 if not walkable(p):return false
 for o in objects:
  if o.type=='door' and o.pos==p and not o.open:return false
 return true
func route(from:Vector2i,to:Vector2i,closed:bool=false)->Array:
 if not walkable(from) or not walkable(to):return []
 var queue:Array=[from];var parent:Dictionary={from:from};var i=0
 while i<queue.size():
  var p:Vector2i=queue[i];i+=1
  if p==to:
   var result:Array=[]
   while p!=from:result.push_front(p);p=parent[p]
   return result
  for d in DIRECTIONS:
   var next=p+d
   if not parent.has(next) and (passable(next) if closed else walkable(next)):parent[next]=p;queue.append(next)
 return []
func step():
 if outcome!='running':return
 tick+=1
 for m in pending_signals:signals[m.key]=m.value
 pending_signals.clear()
 for id in active_ids:_robot(id)
 _devices()
 for g in guards:_guard(g)
 _detect()
 if outcome=='running' and items().all(func(o):return o.delivered) and active_ids.all(func(i):return robots[i].pos in exits()):
  outcome='won'
  for id in active_ids:robots[id].status='Эвакуирован'
  log_event('Все экспонаты доставлены. Команда эвакуирована.','won')
 if outcome=='running' and active_ids.all(func(id):return robots[id].pc>=plans[id].size()):
  outcome='lost';log_event('Программы завершены, но задача не выполнена. Проверьте доставку и выход команды.','lost')
 if outcome=='running' and robots.any(func(r):return r.blocked):outcome='lost';log_event('Ошибка программы: проверьте заблокированную команду.','lost')
 _record_snapshot()
func _robot(id:int):
 var r:Dictionary=robots[id]
 if r.blocked:return
 if r.pc>=plans[id].size():r.status='Эвакуирован' if r.pos in exits() else 'Программа завершена';return
 var c:Dictionary=plans[id][r.pc];var k:String=c.type;practiced[k]=true
 if r.last_pc!=r.pc:
  r.last_pc=r.pc
  var title={'forward':'Шаг вперёд','backward':'Шаг назад','left':'Поворот налево','right':'Поворот направо','interact':'Взаимодействие','noise':'Бросок шума','select':'Выбор экспоната','wait':'Ожидание времени','send':'Передача сигнала','wait_signal':'Ожидание сигнала','timer':'Запуск таймера','condition':'Проверка состояния','if':'Выбор ветки','else':'Ветка иначе','while':'Проверка цикла','repeat':'Повторение','end':'Конец блока'}.get(k,k)
  log_event('%s · блок %d · %s'%[NAMES[id],r.pc+1,title],'step',id)
 match k:
  'forward','backward':_move(r,r.pos+DIRECTIONS[r.facing]*(-1 if k=='backward' else 1))
  'left','right':
   r.elapsed+=1
   if r.elapsed>=5:r.facing=posmod(r.facing+(1 if k=='right' else -1),4);_complete(r)
  'interact','hack','hack_lasers','take':_interact(r,c)
  'select':
   if r.carrying:_block(r,'Сначала доставьте предмет на выход');return
   var choices=items().filter(func(o):return not o.delivered and o.carrier<0 and o.owner in [-1,id])
   choices.sort_custom(func(a,b):return r.pos.distance_squared_to(a.pos)<r.pos.distance_squared_to(b.pos) if r.pos.distance_squared_to(a.pos)!=r.pos.distance_squared_to(b.pos) else a.id<b.id)
   if choices.is_empty():_block(r,'Нет свободного экспоната');return
   for item in items():
    if item.owner==id and item.carrier<0 and not item.delivered:item.owner=-1
   choices[0].owner=id;r.target_item=choices[0].id;_complete(r)
  'noise':
   var p=to_cell(c.get('target',[6,5]))
   if tick<r.noise_ready:r.status='Перезарядка шума';return
   if not walkable(p) or r.pos.distance_to(p)>5 or not line_clear(r.pos,p):_block(r,'Бросок: нужна видимая клетка в радиусе 5');return
   if level==1 and (p.y not in [5,6] or p.x<1 or p.x>13):_block(r,'Шум разрешён в южной полосе');return
   if guards.any(func(g):return g.state in ['investigate','inspect','return']):r.status='Уже идёт проверка шума';return
   for g in guards:
    if g.pos.distance_to(p)<=8 and (g.pos==p or not route(g.pos,p,true).is_empty()):g.noise=p;g.state='investigate';g.wait=0;g.clock=0;log_event('Охранник услышал шум в '+str(p),'noise',id)
   r.noise_ready=tick+200;_complete(r)
  'wait':
   r.elapsed+=1;r.status='Ожидание'
   if r.elapsed>=int(c.get('ticks',round(float(c.get('seconds',1))*HZ))):_complete(r)
  'send':pending_signals.append({'key':c.signal,'value':c.get('value',true)});log_event('%s → %s = %s'%[NAMES[id],c.signal,'да' if c.get('value',true) else 'нет'],'signal',id);_complete(r)
  'wait_signal':
   r.status='Ждёт '+c.signal
   if signals.get(c.signal,false)==c.get('value',true):_complete(r)
  'timer':timers[id][c.get('timer','T')]=tick+roundi(c.seconds*HZ);_complete(r)
  'condition':
   r.status='Ждёт: '+{'camera_off':'камера выключена','camera_safe':'окно камеры','laser_safe':'окно лазера','terminal_ready':'терминал готов','guard_distracted':'охранник в нише','guard_posted':'охранник на посту','door_open':'дверь открыта','timer_done':'таймер','signal_off':'сигнал выключен','signal_on':'сигнал включён','ready_or_done':'запрос напарника'}.get(c.get('condition',''),'условие')
   if evaluate(c,id):_complete(r)
  'repeat':
   if not r.loops.has(r.pc):r.loops[r.pc]=int(c.count)
   _complete(r)
  'if','while':
   if evaluate(c,id):_complete(r)
   else:r.pc=_matching(plans[id],r.pc,true)+1
  'else':r.pc=_matching(plans[id],r.pc,false)+1
  'end':
   var opening=_opening(plans[id],r.pc);var type=plans[id][opening].type
   if type=='repeat':
    r.loops[opening]-=1
    if r.loops[opening]>0:r.pc=opening+1
    else:r.loops.erase(opening);_complete(r)
   elif type=='while':r.pc=opening
   else:_complete(r)
  _:_block(r,'Неизвестный блок '+k)
func _move(r:Dictionary,p:Vector2i):
 if not walkable(p):_block(r,'Стена или витрина на пути');return
 if guards.any(func(g):return g.pos==p):r.status='Проход занят охранником';return
 if not passable(p):r.status='Ждёт открытия двери';return
 r.path=[p];r.move_period=20 if r.carrying else 10;r.move_clock+=1;r.status='Шаг назад' if plans[r.id][r.pc].type=='backward' else 'Шаг вперёд'
 if r.move_clock>=r.move_period:
  r.previous=r.pos;r.pos=p;r.move_clock=0;r.path=[]
  _complete(r)
func _interact(r:Dictionary,c:Dictionary):
 if r.carrying and r.pos in exits():
  var held=object(r.item);held.delivered=true;held.carrier=-1;r.carrying=false;r.item='';r.target_item='';log_event(NAMES[r.id]+' доставил '+held.name,'deposit',r.id);_complete(r);return
 var o:Dictionary={}
 if c.has('object'):
  o=object(r.target_item if c.object=='selected' else c.object)
  if o.is_empty():_block(r,'Указанный объект не найден');return
 elif not r.target_item.is_empty():
  var selected=object(r.target_item)
  if not selected.is_empty() and not selected.delivered and r.pos.distance_to(selected.pos)<=1.01:o=selected
 if o.is_empty():
  for candidate in objects:
   if candidate.type in ['button','terminal','item'] and r.pos.distance_to(candidate.pos)<=1.01 and not candidate.get('delivered',false):o=candidate;break
 if o.is_empty() or r.pos.distance_to(o.pos)>1.01:_block(r,'Нужно подойти к объекту');return
 match o.type:
  'button':
   var door=object(o.door)
   if door.has('authorization_terminal') and not (door.open and tick<door.until):
    var auth=object(door.authorization_terminal)
    if tick>=auth.off_until or tick-auth.hacked_at>int(door.authorization_ticks):
     r.status='Кнопка ждёт нового взлома';return
   door.open=true;door.until=tick+int(door.duration);log_event('Кнопка открыла дверь','door',r.id);_complete(r)
  'terminal':
   if tick<o.off_until:_complete(r);return
   if tick<o.ready:r.status='Перезарядка терминала';return
   r.elapsed+=1;r.status='Взлом %d/%d'%( [r.elapsed,int(o.hack)] )
   if r.elapsed>=int(o.hack):o.hacked_at=tick;o.off_until=tick+int(o.window);o.ready=o.off_until+int(o.cooldown);log_event('Защита отключена до тика %d'%o.off_until,'hack',r.id);_complete(r)
  'item':
   if r.carrying:_block(r,'Можно нести только один предмет. Сначала доставьте его.');return
   if o.delivered or o.carrier>=0 or o.owner not in [-1,r.id]:_block(r,'Экспонат уже закреплён за напарником');return
   if r.pos==o.pos:_block(r,'Встаньте рядом с витриной');return
   o.owner=r.id;r.elapsed+=1;r.status='Вскрытие %d/40'%r.elapsed
   if r.elapsed>=40:o.carrier=r.id;r.carrying=true;r.item=o.id;artifact_taken=true;log_event(NAMES[r.id]+' взял '+o.name,'take',r.id);_complete(r)
  _:_block(r,'Этот объект не требует взаимодействия')
func _complete(r:Dictionary):r.pc+=1;r.elapsed=0;r.move_clock=0;r.path=[];r.status='Следующий блок'
func _block(r:Dictionary,why:String):r.blocked=true;r.status=why;log_event(NAMES[r.id]+': '+why,'blocked',r.id)
func _devices():
 for d in objects:
  if d.type!='door':continue
  var occupied=active_ids.any(func(id):return robots[id].pos==d.pos)
  var was_open=d.open
  if d.mode=='plate':d.open=(occupied and d.get('hold_occupied',false)) or objects.any(func(p):return p.type=='plate' and p.door==d.id and active_ids.any(func(id):return robots[id].pos==p.pos))
  elif d.mode=='heavy':d.open=tick<d.until or (occupied and d.get('hold_occupied',true))
  if was_open and not d.open and d.has('authorization_terminal'):
   log_event('Дверь галереи закрылась: истекли 120 тиков. Продлите окно кнопкой.','door')
   if occupied and outcome=='running':outcome='lost';log_event('Дверь галереи закрылась в занятом проёме. Вторая кнопка не нажата.','lost')
func _guard(g:Dictionary):
 if g.wait>0:
  g.wait-=1
  if g.wait==0 and g.state=='inspect':
   g.state='return';var best=0
   for i in g.route.size():
    if route(g.pos,g.route[i],true).size()<route(g.pos,g.route[best],true).size():best=i
   g.patrol_index=best
   if g.get('nearest_return',false):g.return_goal=Vector2i(clampi(g.pos.x,12,16),11)
   var return_path=route(g.pos,g.get('return_goal',g.route[best]),true)
   if not return_path.is_empty():g.facing=return_path[0]-g.pos
   log_event('Охранник возвращается','guard')
  return
 var goal=g.noise if g.state=='investigate' else (g.get('return_goal',g.route[g.patrol_index]) if g.state=='return' else g.route[g.patrol_index])
 if g.pos==goal:
  if g.state=='investigate':
   g.state='inspect';g.wait=int(g.get('inspect',data.get('noise',{}).get('inspect',120)));g.clock=0
   log_event('Охранник проверяет шум: %d тиков'%g.wait,'guard')
  elif g.state=='return':
   g.state='patrol';g.clock=0
   if g.get('mode','')=='post':g.facing=g.post_facing
  return
 g.clock+=1
 if g.clock<12:return
 g.clock=0
 var path=route(g.pos,goal,true)
 if path.is_empty():return
 g.previous=g.pos;g.facing=path[0]-g.pos;g.pos=path[0]
 if g.pos==goal:
  if g.state=='investigate':g.state='inspect';g.wait=int(g.get('inspect',data.get('noise',{}).get('inspect',120)));log_event('Охранник проверяет шум: %d тиков'%g.wait,'guard')
  elif g.state=='return' and g.get('nearest_return',false):
   g.state='patrol';g.wait=0;g.erase('return_goal');g.patrol_index=1
  else:
   g.state='patrol';g.wait=int(g.pause)
   if g.get('mode','')=='post':g.patrol_index=0;g.facing=g.post_facing
   else:g.patrol_index=1-int(g.patrol_index)
func line_clear(a:Vector2i,b:Vector2i,world_objects:Array=[])->bool:
 var delta=Vector2(b-a);var count=maxi(1,ceili(delta.length()*12))
 for i in range(1,count+1):
  var p=Vector2(a)+Vector2(.5,.5)+delta*float(i)/count;var cell=Vector2i(floori(p.x),floori(p.y))
  if walls.has(cell):return false
  for o in (objects if world_objects.is_empty() else world_objects):
   if o.type=='door' and o.pos==cell and not o.open:return false
 return true
func visible(a:Vector2i,facing:Vector2i,b:Vector2i,radius:float,cosine:float=.707106,world_objects:Array=[])->bool:
 var delta=Vector2(b-a)
 return delta.length()<=radius and (delta.length()==0 or Vector2(facing).dot(delta.normalized())+0.00001>=cosine) and line_clear(a,b,world_objects)
func laser_active(l:Dictionary,at:int=-1,world_objects:Array=[])->bool:
 if at<0:at=tick
 if l.has('circuit'):
  for o in (objects if world_objects.is_empty() else world_objects):
   if o.type=='terminal' and o.circuit==l.circuit:return at>=o.off_until
  return true
 var phase=posmod(at+int(l.phase)-int(l.off_start),int(l.period))
 return phase>=int(l.off_length)
func camera_on(c:Dictionary,at:int=-1,world_objects:Array=[])->bool:
 if at<0:at=tick
 if c.has('circuit'):
  for o in (objects if world_objects.is_empty() else world_objects):
   if o.type=='terminal' and o.circuit==c.circuit:return at>=o.off_until
  return true
 return posmod(at+int(c.phase),int(c.period))<int(c.active)
func camera_sees(c:Dictionary,p:Vector2i)->bool:
 return camera_on(c) and p in c.cells and camera_line_clear(c,p)
func camera_line_clear(c:Dictionary,p:Vector2i,world_objects:Array=[])->bool:
 # A wall-mounted lens looks from the inner edge, not from inside the opaque wall.
 var lens=c.pos+c.facing if walls.has(c.pos) else c.pos
 return line_clear(lens,p,world_objects)
func camera_active()->bool:return cameras.any(func(c):return camera_on(c))
func lasers_active()->bool:return lasers.any(func(l):return laser_active(l))
func _detect():
 for id in active_ids:
  var r:Dictionary=robots[id]
  if level==3 and guards.any(func(g):return g.pos==r.pos):
   outcome='lost';log_event(NAMES[id]+': столкновение с охранником','lost',id);return
  for l in lasers:
   if r.pos in l.cells and laser_active(l):outcome='lost';log_event('%s: лазер %s, тик %d; скорость %d тиков/клетку'%[NAMES[id],l.id,tick,20 if r.carrying else 10],'lost',id);return
  var source=''
  for g in guards:
   if visible(g.pos,g.facing,r.pos,2 if g.state=='inspect' else g.radius):source='охранник'
  for c in cameras:
   if camera_sees(c,r.pos):source=c.id
  r.detection=r.detection+1 if source!='' else maxi(0,r.detection-2)
  if r.detection>=12:outcome='lost';log_event('%s: %s обнаружил робота в %.2f с, блок %d'%[NAMES[id],source,tick*STEP,r.pc+1],'lost',id);return
func evaluate(c:Dictionary,id:int)->bool:
 var result=_evaluate(c,id)
 return not result if c.get("negate",false) else result
func _evaluate(c:Dictionary,id:int)->bool:
 if c.has('all'):return c.all.all(func(v):return evaluate(v,id))
 if c.has('any'):return c.any.any(func(v):return evaluate(v,id))
 match c.get('condition',''):
  'signal_on':return signals.get(c.get('signal','ГОТОВ'),false)
  'signal_off':return not signals.get(c.get('signal','ГОТОВ'),false)
  'timer_done':return timers[id].has(c.get('timer','T')) and tick>=timers[id][c.get('timer','T')]
  'carrying':return robots[id].carrying
  'front_clear':
   var ahead=robots[id].pos+DIRECTIONS[robots[id].facing]
   return passable(ahead) and not guards.any(func(g):return g.pos==ahead)
  'items_free':return items().any(func(o):return not o.delivered and o.carrier<0 and o.owner in [-1,id])
  'items_pending':return items().any(func(o):return not o.delivered)
  'ready_or_done':return signals.get(c.get('signal','НОСИТЕЛЬ_У_ДВЕРИ'),false) or items().all(func(o):return o.delivered)
  'all_delivered':return items().all(func(o):return o.delivered)
  'door_open':return object(c.get('device','door1')).get('open',false)
  'terminal_ready':return not object(c.get('device','terminal1')).is_empty() and tick>=object(c.get('device','terminal1')).get('ready',0)
  'selected_near':
   var selected=object(robots[id].target_item)
   return not selected.is_empty() and robots[id].pos.distance_to(selected.pos)<=1.01
  'at_marker':return robots[id].pos==object(c.get('device','staging')).get('pos',Vector2i(-999,-999))
  'guard_posted':return guards.all(func(g):return g.state=='patrol' and g.pos==g.route[0])
  'guard_distracted':return not guards.is_empty() and guards.all(func(g):return g.state=='inspect' and g.wait>=int(c.get('ticks',0)))
  'noise_ready':return tick>=robots[id].noise_ready and not guards.any(func(g):return g.state in ['investigate','inspect','return'])
  'plate_occupied':return active_ids.any(func(rid):return robots[rid].pos==object(c.get('device','P_V')).get('pos',Vector2i(-999,-999)))
  'guard_patrol':return guard.state=='patrol' and guard.wait==0
  'guard_paused':return guard.state=='patrol' and guard.wait>0
  'guard_returning':return guard.state=='return'
  'guard_investigating':return guard.state=='inspect'
  'guard_going_to_noise':return guard.state=='investigate'
  'guard_horizontal':return guard.facing.x!=0
  'guard_east':return guard.facing==Vector2i.RIGHT
  'camera_active':return not _evaluate({'condition':'camera_off','device':c.get('device','CAM1')},id)
  'laser_on':return not _evaluate({'condition':'laser_safe','device':c.get('device','LZ_M')},id)
  'guard_busy':return guards.any(func(g):return g.state=='investigate' or g.state=='inspect')
  'guard_in_niche':return guards.any(func(g):return g.pos.y>=(12 if level==3 else 4) and g.state in ['investigate','inspect'])
  'guard_west':return guards.is_empty() or (guard.facing==Vector2i.LEFT and guard.pos.x>=15 and guard.wait==0)
  'camera_off','camera_safe':
   for cam in cameras:
    if c.has('device') and cam.id!=c.device:continue
    for dt in range(0,int(c.get('ticks',0))+1):
     if camera_on(cam,tick+int(c.get("after_ticks",0))+dt):return false
   return true
  'laser_safe','lasers_off':
   var matched=false
   for l in lasers:
    if c.get('device',l.id)!=l.id:continue
    matched=true
    for dt in range(0,int(c.get('ticks',0))+1):
     if laser_active(l,tick+int(c.get("after_ticks",0))+dt):return false
   return matched
 return false
func log_event(message:String,kind:String='info',robot:int=-1):events.append({'tick':tick,'message':message,'kind':kind,'robot':robot})
func _record_snapshot():
 if record:snapshots.append(view())
func view()->Dictionary:
 return {'tick':tick,'robots':robots.duplicate(true),'guard':guard.duplicate(true),'guards':guards.duplicate(true),'objects':objects.duplicate(true),'cameras':cameras.duplicate(true),'lasers':lasers.duplicate(true),'camera_active':camera_active(),'camera_until':0,'lasers_active':lasers_active(),'laser_until':0,'artifact_taken':artifact_taken,'signals':signals.duplicate(),'timers':timers.duplicate(true),'outcome':outcome,'level':level,'decoys':[],'key_until':0,'lockdown_until':0,'pulse_safe':true}
static func to_cell(value)->Vector2i:return value if value is Vector2i else Vector2i(int(value[0]),int(value[1]))
static func _matching(program:Array,index:int,allow_else:bool)->int:
 var depth=0
 for i in range(index+1,program.size()):
  if program[i].type in ['if','while','repeat']:depth+=1
  elif program[i].type=='end':
   if depth==0:return i
   depth-=1
  elif program[i].type=='else' and depth==0 and allow_else and program[index].type=='if':return i
 return program.size()-1
static func _opening(program:Array,index:int)->int:
 var depth=0
 for i in range(index-1,-1,-1):
  if program[i].type=='end':depth+=1
  elif program[i].type in ['if','while','repeat']:
   if depth==0:return i
   depth-=1
 return 0
const MAX_SECONDS=300
const MAX_REPEAT=1000
const COMMAND_TYPES=['interact','noise','select','wait','send','wait_signal','timer','condition','if','else','while','repeat','end','forward','backward','left','right']
static func _valid_number(value,minimum:float,maximum:float,integer:bool=false)->bool:
 return (value is float or value is int) and is_finite(value) and value>=minimum and value<=maximum and (not integer or value==floor(value))
static func _valid_name(value)->bool:return value is String and not value.strip_edges().is_empty() and value.length()<=64
static func _valid_condition(c:Dictionary,depth:int=0)->bool:
 if depth>8:return false
 if c.has('negate') and not c.negate is bool:return false
 if c.has('all') or c.has('any'):
  var clauses=c.get('all',c.get('any',null))
  if not clauses is Array or clauses.is_empty() or clauses.size()>32:return false
  return clauses.all(func(part):return part is Dictionary and _valid_condition(part,depth+1))
 if c.get('condition','') not in CONDITIONS:return false
 if c.has('device') and not _valid_name(c.device):return false
 if c.has('ticks') and not _valid_number(c.ticks,0,MAX_SECONDS*HZ,true):return false
 if c.has('after_ticks') and not _valid_number(c.after_ticks,0,MAX_SECONDS*HZ,true):return false
 if c.has('signal') and not _valid_name(c.signal):return false
 if c.has('timer') and not _valid_name(c.timer):return false
 return true
static func validate(plan:Array,allow_empty:bool=false)->Array[String]:
 var errors:Array[String]=[]
 if plan.size()!=3:return ['Нужны три программы']
 var total=0
 for program in plan:
  if not program is Array:return ['Неверная программа']
  if program.size()>2000:return ['Слишком много блоков в программе']
  var stack:Array=[]
  for c in program:
   total+=1
   if not c is Dictionary or not c.has('type'):return ['Повреждённый блок']
   if c.type not in COMMAND_TYPES:errors.append('Неизвестная команда');continue
   if c.type=='repeat' and not _valid_number(c.get('count',null),1,MAX_REPEAT,true):errors.append('Число повторов должно быть целым от 1 до %d'%MAX_REPEAT)
   if c.type=='wait':
    if c.has('ticks'):
     if not _valid_number(c.ticks,1,MAX_SECONDS*HZ,true):errors.append('Некорректное число тиков ожидания')
    elif not _valid_number(c.get('seconds',null),STEP,MAX_SECONDS):errors.append('Некорректное время ожидания')
   if c.type=='timer':
    if not _valid_number(c.get('seconds',null),STEP,MAX_SECONDS) or not _valid_name(c.get('timer','T')):errors.append('Задайте имя и время таймера')
   if c.type=='noise':
    var target=c.get('target',null)
    if not (target is Array and target.size()==2 and _valid_number(target[0],0,999,true) and _valid_number(target[1],0,999,true)):errors.append('Координаты шума должны быть целыми')
   if c.type=='interact' and c.has('object') and not _valid_name(c.object):errors.append('Неверный объект взаимодействия')
   if c.type in ['send','wait_signal']:
    if not _valid_name(c.get('signal',null)):errors.append('Введите имя сигнала')
    if c.has('value') and not c.value is bool:errors.append('Сигнал должен иметь значение да или нет')
   if c.type in ['condition','if','while'] and not _valid_condition(c):errors.append('Некорректное условие')
   if c.type in ['if','while','repeat']:stack.append({'type':c.type,'else':false})
   if c.type=='else':
    if stack.is_empty() or stack.back().type!='if' or stack.back()['else']:errors.append('Иначе вне условия')
    else:stack.back()['else']=true
   if c.type=='end':
    if stack.is_empty():errors.append('Лишний конец')
    else:stack.pop_back()
  if not stack.is_empty():errors.append('Незакрытый блок')
 if total==0 and not allow_empty:errors.append('Добавьте блоки')
 return errors
func solution()->Array:return JSON.parse_string(FileAccess.get_file_as_string('res://data/programs/%02d.json'%((stage if level==0 else level+5)+1)))

func validate_world(programs:Array)->Array[String]:
 var errors:Array[String]=[]
 var sent={}
 for program in programs:
  for c in program:
   if c.type=='send':sent[c.signal]=true
 for id in active_ids:
  var p=robots[id].pos;var facing=robots[id].facing;var known=true
  for c in programs[id]:
   if c.type in ['if','while','repeat','else']:known=false
   if c.type=='wait_signal' and not sent.has(c.signal):errors.append(NAMES[id]+' ждёт сигнал «'+c.signal+'», но никто его не отправляет')
   if c.type=='interact' and c.get('object','') not in ['', 'selected']:
    var o=object(c.object)
    if o.is_empty() or o.type not in ['terminal','button','item','exit']:errors.append('Неверный объект взаимодействия: '+c.object)
   if known:
    if c.type=='left':facing=posmod(facing-1,4)
    if c.type=='right':facing=posmod(facing+1,4)
    if c.type in ['forward','backward']:p+=DIRECTIONS[facing]*(-1 if c.type=='backward' else 1)
    if c.type=='noise':
     var target=to_cell(c.target)
     if not walkable(target) or p.distance_to(target)>5 or not line_clear(p,target):errors.append('Шум: нужна прямая видимость и радиус 5 клеток')
 return errors
