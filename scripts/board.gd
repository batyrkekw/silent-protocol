extends Control
signal cell_clicked(cell:Vector2i)
signal robot_clicked(id:int)
const Sim=preload('res://scripts/simulation_v5.gd')
const Presentation=preload('res://scripts/presentation.gd')
const Art=preload('res://scripts/robot_art.gd')
var museum=preload('res://scripts/museum_visuals.gd').new()
var sim:ProtocolSimulation
var state:Dictionary={}
var selected=0
var plans:Array=[[],[],[]]
var hover=Vector2i(-1,-1)
var show_vision=true
var show_routes=false
var show_details=false
var running_animation=false
var frame_alpha=0.0
var snap_visuals=true
var actors:Array=[]
var visual_guard=Vector2.ZERO
var pick_target=false
var preview_cell=Vector2i(-1,-1)
var cell_size=32.0
var origin=Vector2.ZERO
var tile=Vector2.ONE
var font:Font=preload('res://assets/fonts/jetbrains-mono.ttf')
var clock=0.0
var drawing_item=0
func _ready():
 clip_contents=true
 mouse_exited.connect(func():hover=Vector2i(-1,-1);tooltip_text="")
func _process(delta:float):
 if running_animation or (sim and sim.outcome=='planning'):clock+=delta
 if not state.is_empty():actors=Presentation.layout(state.robots,tile,frame_alpha)
 queue_redraw()
func point(cell:Vector2i)->Vector2:return origin+(Vector2(cell)+Vector2(.5,.5))*tile
func _text(p:Vector2,value:String,color:Color,font_size:int=12):draw_string(font,p,preload("res://scripts/localization.gd").text(value),HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(14,font_size),color)
func _gui_input(event:InputEvent):
 if event is InputEventMouseMotion:
  hover=Vector2i((event.position-origin)/tile);tooltip_text='Клетка %d:%d · движение задаётся шагами'%[hover.x,hover.y]
  if sim and not state.is_empty():
   for o in state.objects:
    if o.pos==hover:
     tooltip_text=o.get('name',o.id)
     if o.type=='terminal':tooltip_text='%s · взлом %.1f с · окно %.1f с'%( [o.id,o.hack/20.0,o.window/20.0] )
   for target in sim.data.get('noise_targets',[]):
    if Sim.to_cell(target)==hover:tooltip_text='Шумовая ниша · бросьте шум через окно из пультовой'
   for g in state.guards:
    if g.get('mode','')=='post' and g.route[0]==hover:tooltip_text='Охранный пост · сам не уйдёт. Требуется отвлечение.'
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  var cell=Vector2i((event.position-origin)/tile)
  if not pick_target:
   for id in sim.active_ids:
    if state.robots[id].pos==cell:robot_clicked.emit(id);return
  if sim.walkable(cell):cell_clicked.emit(cell)
func _draw():
 if not sim or state.is_empty():return
 cell_size=minf((size.x-40)/sim.width,(size.y-60)/sim.height)
 tile=Vector2.ONE*cell_size;origin=(size-Vector2(0,26)-Vector2(sim.width,sim.height)*tile)/2
 museum.architecture(self)
 for y in sim.height:
  for x in sim.width:
   var cell=Vector2i(x,y);var rect=Rect2(origin+Vector2(cell)*tile,tile)
   if not sim.walls.has(cell):
    if sim.data.grid[y][x]=='W':
     draw_rect(rect.grow(-2),Color('c2dbe2'))
     draw_line(rect.position+Vector2(3,3),rect.end-Vector2(3,3),Color('81a9b9'),2,true)
     draw_line(rect.position+Vector2(3,tile.y-3),rect.position+Vector2(tile.x-3,3),Color('ffffff',.65),1,true)
    if show_details:draw_rect(rect,Color('d5dfe1'),false,1)
    if show_vision:
     for g in state.guards:
      if sim.visible(g.pos,g.facing,cell,2 if g.state=='inspect' else g.radius,.707106,state.objects):draw_rect(rect,Color(.8,.2,.3,.12))
     for c in state.cameras:
      if sim.camera_on(c,state.tick,state.objects) and cell in c.cells and sim.camera_line_clear(c,cell,state.objects):draw_rect(rect,Color(.9,.6,.15,.15))
 for target in sim.data.get('noise_targets',[]):
  var p=point(Sim.to_cell(target))
  draw_circle(p,cell_size*.3,Color('b9a7cd',.22))
  draw_arc(p,cell_size*.26,-.8,2.4,18,Color('9270b0'),1.5,true)
  draw_circle(p,2,Color('9270b0'))
 for o in state.objects:
  var p=point(o.pos)
  match o.type:
   'exit':
    draw_rect(Rect2(p-tile*.4,tile*.8),Color('71c5a9'),false,2)
    _text(p+Vector2(-8,5),'E',Color('317d6c'),16)
   'door':
    draw_rect(Rect2(p-tile*Vector2(.43,.28),tile*Vector2(.86,.56)),Color('6ac6b5') if o.open else Color('41576e'))
    _text(p+Vector2(-4,4),'D',Color.WHITE,12)
   'plate':
    var occupied=state.robots.any(func(r):return r.pos==o.pos)
    draw_rect(Rect2(p-tile*.33,tile*.66),Color('69bdac') if occupied else Color('9182ad'),false,3)
    _text(p+Vector2(-4,4),'P',Color('476b6b'),12)
   'button':
    draw_rect(Rect2(p-Vector2(10,9),Vector2(20,18)),Color('334d63'))
    draw_circle(p,5,Color('e7b66b'));_text(p+Vector2(-4,-14),'B',Color('49667a'),12)
   'marker':
    draw_rect(Rect2(p-tile*.30,tile*.60),Color('8ba6b9'),false,1)
    _text(p+Vector2(-5,5),'◇',Color('59778b'),14)
   'terminal':
    draw_rect(Rect2(p-Vector2(13,7),Vector2(27,22)),Color('12263a',.22))
    draw_rect(Rect2(p-Vector2(12,10),Vector2(24,20)),Color('263c52'))
    draw_rect(Rect2(p-Vector2(12,10),Vector2(24,20)),Color('8ea4af'),false,1)
    var color=Color('66d4ba') if state.tick>=o.ready else Color('bd9c67')
    draw_rect(Rect2(p-Vector2(8,7),Vector2(16,11)),color)
    _text(p+Vector2(-8,-15),o.id if o.id.begins_with('T_') else 'T'+o.id[-1],Color('b6cbd3') if sim.walls.has(o.pos+Vector2i.UP) else Color('49667a'),12)
   'item':
    var base=Rect2(p-tile*.42,tile*.84)
    draw_rect(Rect2(base.position+Vector2(2,5),base.size),Color('132e40',.22))
    draw_rect(base,Color('eff0e5'))
    draw_rect(base.grow(-2),Color('bfa574'),false,1)
    draw_rect(base.grow(-4),Color('233e50'))
    draw_line(base.position+Vector2(3,3),base.position+Vector2(base.size.x-3,3),Color('fff4d1'),2,true)
    if not o.delivered and o.carrier<0:
     drawing_item={'E1':1,'E2':2,'A':0}.get(o.id,0) if sim.level==3 else (int(o.id[-1])-1 if sim.level>=2 else (1 if sim.level==1 else 0))
     _gem(p+Vector2(0,sin(clock*2)*1.3),minf(1,cell_size/32))
 for l in state.lasers:
  var active=sim.laser_active(l,state.tick,state.objects)
  for cell in l.cells:
   var p=point(cell);var color=Color('ef4b7b') if active else Color('62a99e')
   var a=p-Vector2(tile.x*.45,0);var b=p+Vector2(tile.x*.45,0)
   if active:
    draw_line(a,b,Color(color,.08),12,true);draw_line(a,b,Color(color,.18),6,true);draw_line(a,b,color,2,true);draw_line(a,b,Color('ffe5ee',.8),.7,true)
   else:draw_dashed_line(a,b,Color(color,.6),1,4)
   draw_rect(Rect2(a-Vector2(2,5),Vector2(4,10)),Color('2e435b'));draw_rect(Rect2(b-Vector2(2,5),Vector2(4,10)),Color('2e435b'))
 museum.connections(self)
 for c in state.cameras:
  var mount=c.pos
  if not sim.walls.has(mount):
   if sim.walls.has(mount-c.facing):mount-=c.facing
  var p=point(mount)+Vector2(c.facing)*cell_size*.3
  draw_set_transform(p,Vector2(c.facing).angle()-PI/2)
  draw_rect(Rect2(-4,-10,8,10),Color('526b80'));draw_rect(Rect2(-11,-2,22,10),Color('273c51'))
  draw_circle(Vector2(0,9),4,Color('eab075') if sim.camera_on(c,state.tick,state.objects) else Color('70b5aa'))
  draw_set_transform(Vector2.ZERO)
  _text(p+Vector2(-7,-12),'C'+c.id[-1],Color('b6cbd3'),12)
 for g in state.guards:
  if g.get('mode','')=='post':
   var post=point(g.route[0]);draw_rect(Rect2(post-tile*.36,tile*.72),Color('b9747e'),false,2)
   var d=Vector2(g.post_facing);draw_line(post,post+d*tile.x*.5,Color('b9747e'),2,true)
  visual_guard=point(g.pos)
  _draw_guard(g)
 for id in sim.active_ids:
  if actors.size()<=id:continue
  var r=state.robots[id];var p=origin+actors[id].position
  Art.render(self,p,id,actors[id].scale)
  var heading=Vector2(Sim.DIRECTIONS[r.facing]);var side=heading.orthogonal()
  var tip=p+heading*minf(22,cell_size*.43)
  draw_colored_polygon(PackedVector2Array([tip+heading*4,tip-heading*3+side*4,tip-heading*3-side*4]),Sim.COLORS[id])
  if id==selected:draw_arc(p,18,-PI/2,TAU-PI/2,32,Color(Sim.COLORS[id],.6),1)
  if r.carrying:
   drawing_item={'E1':1,'E2':2,'A':0}.get(r.item,0) if sim.level==3 else (int(r.item[-1])-1 if sim.level>=2 else (1 if sim.level==1 else 0))
   _gem(p+Vector2(8,-10),.45)
  if r.detection>0:
   draw_rect(Rect2(p+Vector2(-13,-24),Vector2(26,4)),Color('39424d'))
   draw_rect(Rect2(p+Vector2(-13,-24),Vector2(26*r.detection/12.0,4)),Color('ec7c8c'))
  if r.elapsed>0:draw_arc(p,20,-PI/2,-PI/2+TAU*minf(1,r.elapsed/40.0),32,Sim.COLORS[id],2)
 # Coincident robots keep exact positions; tiny colored roster marks reveal shared cells.
 var groups:Dictionary={}
 for id in sim.active_ids:
  var cell=state.robots[id].pos
  if not groups.has(cell):groups[cell]=[]
  groups[cell].append(id)
 for cell in groups:
  if groups[cell].size()>1:
   for i in groups[cell].size():draw_rect(Rect2(point(cell)+Vector2(-9+i*7,15),Vector2(5,4)),Sim.COLORS[groups[cell][i]])
 if show_routes and sim.outcome=='planning':
  var last=state.robots[selected].pos;var facing=state.robots[selected].facing
  for c in plans[selected]:
   if c.type in ['left','right']:facing=posmod(facing+(1 if c.type=='right' else -1),4)
   elif c.type in ['forward','backward']:
    var next=last+Sim.DIRECTIONS[facing]*(-1 if c.type=='backward' else 1)
    if not sim.walkable(next):break
    draw_dashed_line(point(last),point(next),Color('578fa9'),1,4);last=next
   else:break
 if sim.walkable(hover) and sim.outcome=='planning':draw_rect(Rect2(point(hover)-tile*.5,tile),Color(.3,.6,.8,.15))
 if show_details:
  for x in sim.width:_text(origin+Vector2((x+.2)*tile.x,-5),str(x),Color('456178'),10)
  for y in sim.height:_text(origin+Vector2(-17,(y+.6)*tile.y),str(y),Color('456178'),10)
 # Compact objective HUD, pinned to the empty upper-right map corner.
 var hud=Vector2(size.x-100,26)
 draw_rect(Rect2(hud-Vector2(20,20),Vector2(114,82)),Color('101a2c',.92))
 var total=state.objects.filter(func(o):return o.type=='item').size()
 var delivered=state.objects.filter(func(o):return o.type=='item' and o.delivered).size()
 drawing_item=0;_gem(hud,.7)
 _text(hud+Vector2(20,5),'%d/%d'%[delivered,total],Color('e5edfa'),18)
 Art.render(self,hud+Vector2(0,36),0,.65)
 var escaped=sim.active_ids.filter(func(i):return state.robots[i].pos in sim.exits()).size()
 _text(hud+Vector2(20,41),'%d/%d'%[escaped,sim.active_ids.size()],Color('e5edfa'),18)
func _draw_guard(g: Dictionary) -> void:
 var p = visual_guard
 var facing = Vector2(g.facing)
 var stride = sin(clock*9)*2 if g.state in ["investigate","return"] or g.get("mode","")!="post" and g.state=="patrol" else 0.0
 draw_set_transform(p,0,Vector2.ONE*.9)
 draw_circle(Vector2(1,6),13,Color(0.05,0.08,0.13,.2))
 # Navy uniform, peaked cap, shoulder radio and a small brass badge.
 draw_rect(Rect2(-7,5+stride,5,9),Color("172539"))
 draw_rect(Rect2(2,5-stride,5,9),Color("172539"))
 draw_rect(Rect2(-10,-5,20,15),Color("334761"))
 draw_rect(Rect2(-13,-3,4,11),Color("233449"))
 draw_rect(Rect2(9,-3,4,11),Color("233449"))
 draw_rect(Rect2(-5,-12,10,9),Color("ceac88"))
 draw_rect(Rect2(-8,-15,16,6),Color("20354e"))
 draw_rect(Rect2(-9,-10,18,3),Color("122134"))
 draw_rect(Rect2(-6,-2,3,4),Color("e2bd71"))
 draw_rect(Rect2(5,-6,3,6),Color("101c2c"))
 draw_line(Vector2(7,-7),Vector2(7,-12),Color("6b829b"),1)
 draw_rect(Rect2(-8,6,16,3),Color("142437"))
 draw_set_transform(Vector2.ZERO)
 draw_line(p+facing*13,p+facing*21,Color("ba7181"),2,true)
 if g.state != "patrol": _text(p+Vector2(13,-12),"?",Color("a73d50"),14)

func _gem(p: Vector2, scale: float = 1.0) -> void:
 if drawing_item == 1:
  var v = PackedVector2Array([p+Vector2(-13,6)*scale,p+Vector2(-8,-6)*scale,p+Vector2(9,-6)*scale,p+Vector2(14,6)*scale])
  draw_colored_polygon(v,Color("e8b943"))
  draw_line(v[0],v[3],Color("9c6c22"),4*scale,true)
  draw_line(v[1],v[2],Color("fff1b0"),3*scale,true)
  draw_line(p+Vector2(-4,0)*scale,p+Vector2(5,0)*scale,Color("a5792d"),1*scale,true)
  return
 if drawing_item == 2:
  var curve = PackedVector2Array()
  for i in 21:
   var angle = lerpf(0.15,2.75,i/20.0)
   curve.append(p+Vector2(cos(angle)*14,sin(angle)*12-7)*scale)
  for i in range(20,-1,-1):
   var angle = lerpf(0.15,2.75,i/20.0)
   curve.append(p+Vector2(cos(angle)*14,sin(angle)*5-7)*scale)
  draw_colored_polygon(curve,Color("f2c44e"))
  var rim = PackedVector2Array()
  for i in 21:
   var angle = lerpf(0.15,2.75,i/20.0)
   rim.append(p+Vector2(cos(angle)*14,sin(angle)*10-6)*scale)
  draw_polyline(rim,Color("fff0a0"),2*scale,true)
  draw_line(p+Vector2(14,-5)*scale,p+Vector2(15,-10)*scale,Color("7c5b25"),3*scale,true)
  var glint = (sin(clock*3)+1)*0.5
  var star = p+Vector2(-4,-1)*scale
  draw_line(star-Vector2(5,0)*scale,star+Vector2(5,0)*scale,Color(1,1,0.85,glint),1,true)
  draw_line(star-Vector2(0,5)*scale,star+Vector2(0,5)*scale,Color(1,1,0.85,glint),1,true)
  return
 var vertices = [Vector2(-10, -5), Vector2(-5, -10), Vector2(5, -10), Vector2(10, -5), Vector2(0, 9)]
 var points = PackedVector2Array()
 for v in vertices:
  points.append(p + v * scale)
 draw_colored_polygon(points, Color("b8e2e1"))
 var mid = p + Vector2(0, -5) * scale
 draw_colored_polygon(PackedVector2Array([points[0], mid, points[4]]), Color("70a9b9"))
 draw_colored_polygon(PackedVector2Array([mid, points[3], points[4]]), Color("d2f4ed"))
 draw_colored_polygon(PackedVector2Array([points[1], points[2], mid]), Color("f5fff9"))
 points.append(points[0])
 draw_polyline(points, Color("e6fbef"), 1, true)
 draw_line(points[0], points[3], Color("f4fffa"), 1, true)
 draw_line(points[1], mid, Color("8abfca"), 1, true)
 draw_line(points[2], mid, Color("8abfca"), 1, true)

