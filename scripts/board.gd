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
var label_font:Font=preload('res://assets/fonts/jetbrains-mono-bold.ttf')
var badge_style:StyleBoxFlat
var badge_rects:Dictionary={}
var badge_key=''
var clock=0.0
var drawing_item=0
func _ready():
 clip_contents=true
 badge_style=StyleBoxFlat.new()
 badge_style.bg_color=Color('101e2d')
 badge_style.border_color=Color('577b8a')
 badge_style.set_border_width_all(1)
 badge_style.set_corner_radius_all(4)
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
     if o.type=='button':tooltip_text='Кнопка: взаимодействуйте, чтобы открыть дверь'
     if o.type=='plate':tooltip_text='Плита: стойте на ней, чтобы удерживать дверь открытой'
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
 _layout_badges()
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
   'plate':_draw_plate(o,p)
   'button':_draw_button(o,p)
   'marker':
    draw_rect(Rect2(p-tile*.30,tile*.60),Color('8ba6b9'),false,1)
    _text(p+Vector2(-5,5),'◇',Color('59778b'),14)
   'terminal':
    draw_rect(Rect2(p-Vector2(13,7),Vector2(27,22)),Color('12263a',.22))
    draw_rect(Rect2(p-Vector2(12,10),Vector2(24,20)),Color('263c52'))
    draw_rect(Rect2(p-Vector2(12,10),Vector2(24,20)),Color('8ea4af'),false,1)
    var color=Color('66d4ba') if state.tick>=o.ready else Color('bd9c67')
    draw_rect(Rect2(p-Vector2(8,7),Vector2(16,11)),color)
    _device_badge(p,o.id if o.id.begins_with('T_') else 'T'+o.id[-1],Color('83e2da'))
   'item':
    if not o.delivered and o.carrier<0:
     drawing_item={'E1':1,'E2':2,'A':0}.get(o.id,0) if sim.level==3 else (int(o.id[-1])-1 if sim.level>=2 else (1 if sim.level==1 else 0))
     draw_set_transform(p+Vector2(0,7),0,Vector2(1,.3))
     draw_circle(Vector2.ZERO,cell_size*.23,Color('243747',.16))
     draw_set_transform(Vector2.ZERO)
     _gem(p+Vector2(0,sin(clock*2)*1.3),minf(1,cell_size/28))
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
 for c in state.cameras:_draw_camera(c)
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
func _layout_badges()->void:
 var key=str(size)+':'+str(sim.level)+':'+str(sim.stage)
 if key==badge_key:return
 badge_key=key;badge_rects.clear()
 var floor_rects=[];var icons=[];var devices=[]
 for y in sim.height:
  for x in sim.width:
   if not sim.walls.has(Vector2i(x,y)):floor_rects.append(Rect2(origin+Vector2(x,y)*tile,tile).grow(4))
 for o in state.objects:
  if o.type=='terminal':devices.append({'title':o.id if o.id.begins_with('T_') else 'T'+o.id[-1],'pos':point(o.pos)})
 for c in state.cameras:
  var mount=c.pos
  if not sim.walls.has(mount) and sim.walls.has(mount-c.facing):mount-=c.facing
  devices.append({'title':c.id,'pos':point(mount)+Vector2(c.facing)*cell_size*.3})
 for device in devices:icons.append(Rect2(device.pos-Vector2(17,14),Vector2(34,28)))
 var reserved=[Rect2(size.x-120,6,114,82),Rect2(0,size.y-30,size.x,30)]
 for device in devices:
  var extent=Vector2(label_font.get_string_size(device.title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+18,21)
  var options=[]
  for distance in range(0,8):
   for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
    var offset=(extent.x*.5+cell_size*.5+10 if direction.x!=0 else extent.y*.5+cell_size*.5+8)+distance*cell_size*.5
    options.append(Rect2(device.pos+direction*offset-extent*.5,extent))
  # Free wall/background rectangles only; no label may cover a playable cell.
  var picked=Rect2()
  for box in options:
   if not Rect2(5,4,size.x-10,size.y-37).encloses(box):continue
   if floor_rects.any(func(r):return r.intersects(box)):continue
   if icons.any(func(r):return r.intersects(box)):continue
   if reserved.any(func(r):return r.intersects(box.grow(3))):continue
   picked=box;break
  if not picked.has_area():
   for y in range(6,int(size.y-50),24):
    for x in range(6,int(size.x-extent.x-6),16):
     var box=Rect2(Vector2(x,y),extent)
     if floor_rects.any(func(r):return r.intersects(box)) or icons.any(func(r):return r.intersects(box)) or reserved.any(func(r):return r.intersects(box.grow(3))):continue
     if not picked.has_area() or box.get_center().distance_to(device.pos)<picked.get_center().distance_to(device.pos):picked=box
  if picked.has_area():badge_rects[device.title]=picked;reserved.append(picked)

func _device_badge(anchor:Vector2,title:String,accent:Color)->void:
 if not badge_rects.has(title):return
 var box:Rect2=badge_rects[title];var at=box.position
 var end=Vector2(clampf(anchor.x,box.position.x,box.end.x),clampf(anchor.y,box.position.y,box.end.y))
 var start=anchor.move_toward(end,minf(14,anchor.distance_to(end)))
 draw_line(start,end,Color(accent,.45),1,true)
 draw_style_box(badge_style,box)
 draw_line(at+Vector2(5,20),at+Vector2(box.size.x-5,20),Color(accent,.75),1,true)
 draw_string(label_font,at+Vector2(9,15),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color('f0f6fa'))

func _draw_button(o:Dictionary,p:Vector2)->void:
 var door={}
 for candidate in state.objects:
  if candidate.id==o.door:door=candidate;break
 var active=door.get('open',false)
 var radius=clampf(cell_size*.30,6,12)
 var face=p+Vector2(0,1 if active else -2)
 draw_circle(p+Vector2(0,3),radius+3,Color('223746'))
 draw_circle(p,radius+2,Color('80969b'))
 draw_circle(face,radius,Color('65cbb2') if active else Color('efb857'))
 draw_arc(face,radius-2,PI,TAU,16,Color('fff2c7',.65),1.5,true)
 # A downward press arrow distinguishes an action button from a floor plate.
 draw_line(face-Vector2(0,4),face+Vector2(0,3),Color('263945'),1.5,true)
 draw_polyline(PackedVector2Array([face+Vector2(-3,0),face+Vector2(0,3),face+Vector2(3,0)]),Color('263945'),1.5,true)
 if active and door.get('until',0)>state.tick:
  var left=clampf(float(door.until-state.tick)/maxf(1,door.get('duration',1)),0,1)
  draw_arc(p,radius+4,-PI/2,-PI/2+TAU*left,32,Color('78e0c5'),2,true)

func _draw_plate(o:Dictionary,p:Vector2)->void:
 var pressed=sim.active_ids.any(func(id):return state.robots[id].pos==o.pos)
 var rect=Rect2(p-tile*.41,tile*.82)
 draw_rect(rect,Color('536a79'))
 draw_rect(rect.grow(-2),Color('9ad7c9') if pressed else Color('b7c3cb'))
 draw_rect(rect.grow(-3),Color('458976') if pressed else Color('657d92'),false,1)
 # Two boot marks: standing on this surface is the trigger, no interaction needed.
 for dx in [-1,1]:
  var foot=p+Vector2(dx*cell_size*.13,0)
  draw_line(foot+Vector2(0,-cell_size*.15),foot+Vector2(0,cell_size*.06),Color('376757') if pressed else Color('496074'),maxf(2,cell_size*.12),true)
  draw_line(foot+Vector2(0,cell_size*.13),foot+Vector2(0,cell_size*.19),Color('376757') if pressed else Color('496074'),maxf(2,cell_size*.12),true)
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
  draw_circle(p+corner*cell_size*.31,1.3,Color('d3fff0') if pressed else Color('7f92a0'))

func _draw_camera(c:Dictionary)->void:
 var mount=c.pos
 if not sim.walls.has(mount) and sim.walls.has(mount-c.facing):mount-=c.facing
 var p=point(mount)+Vector2(c.facing)*cell_size*.3
 var active=sim.camera_on(c,state.tick,state.objects)
 var indicator=Color('f2b85a') if active else Color('719ca8')
 draw_set_transform(p,Vector2(c.facing).angle(),Vector2.ONE*clampf(cell_size/28,.75,1.2))
 # Wall plate, articulated bracket, pale metal CCTV housing and hooded lens.
 draw_rect(Rect2(-8,-8,4,16),Color('8eabb5'))
 draw_line(Vector2(-6,-5),Vector2(-6,5),Color('d6e3e6'),1,true)
 draw_line(Vector2(-4,1),Vector2(4,1),Color('142936'),5,true)
 draw_line(Vector2(-4,0),Vector2(4,0),Color('9cb2bb'),2,true)
 draw_circle(Vector2(2,0),3,Color('607e8c'))
 var body=PackedVector2Array([Vector2(2,-7),Vector2(13,-7),Vector2(18,-4),Vector2(18,5),Vector2(12,8),Vector2(2,8)])
 var shadow=body.duplicate()
 for i in shadow.size():shadow[i]+=Vector2(1,3)
 draw_colored_polygon(shadow,Color('152634',.23))
 draw_colored_polygon(body,Color('dbe6e7'))
 draw_line(Vector2(3,-6),Vector2(14,-6),Color('f8fbf6'),2,true)
 draw_line(Vector2(3,7),Vector2(12,7),Color('829ca8'),2,true)
 draw_rect(Rect2(13,-4,6,10),Color('172c3c'))
 draw_circle(Vector2(16,1),3.3,Color('466e82'))
 draw_circle(Vector2(16,1),2.1,Color('0c1b2b'))
 draw_circle(Vector2(16.5,.1),.9,Color('a6deeb'))
 draw_line(Vector2(11,-7),Vector2(20,-5),Color('f1f5ef'),3,true)
 draw_circle(Vector2(5,-3),1.4,indicator)
 draw_set_transform(Vector2.ZERO)
 _device_badge(p,c.id,indicator)

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

