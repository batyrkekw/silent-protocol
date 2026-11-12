extends RefCounted
## Read-only presentation: lighting and circuit diagrams never modify the simulation.
const Loc=preload('res://scripts/localization.gd')
var glow:ImageTexture
var cache_key=''
var lights=[]
func _init():
 var img=Image.create(96,96,false,Image.FORMAT_RGBA8)
 for y in 96:
  for x in 96:
   var radius=Vector2(x-47.5,y-47.5).length()/47.5
   img.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-radius),2.0)))
 glow=ImageTexture.create_from_image(img)
func floor_cell(b,p:Vector2i)->bool:
 return p.x>=0 and p.y>=0 and p.x<b.sim.width and p.y<b.sim.height and not b.sim.walls.has(p)
func prepare(b):
 var key=str(b.sim.level)+':'+str(b.sim.stage)+':'+str(b.sim.width)
 if key==cache_key:return
 cache_key=key;lights.clear()
 # Fixed wall sconces and exhibit spots. Light is clipped to actual floor cells.
 for y in b.sim.height:
  for x in b.sim.width:
   var p=Vector2i(x,y)
   if floor_cell(b,p) and b.sim.walls.has(p+Vector2i.UP) and x%4==2:
    add_light(b,p,2.8,Color('fff0ca',.78),true)
 for o in b.state.objects:
  if o.type=='item':add_light(b,o.pos,2.2,Color('ffe4a8',.85),false)
  elif o.type=='terminal':add_light(b,o.pos,1.5,Color('80d8e4',.32),false)
func add_light(b,p:Vector2i,radius:float,color:Color,sconce:bool):
 var cells=[]
 for y in range(p.y-ceili(radius),p.y+ceili(radius)+1):
  for x in range(p.x-ceili(radius),p.x+ceili(radius)+1):
   var cell=Vector2i(x,y)
   if floor_cell(b,cell) and Vector2(cell-p).length()<=radius+1 and wall_clear(b,p,cell):cells.append(cell)
 lights.append({'pos':p,'radius':radius,'color':color,'cells':cells,'sconce':sconce})
func wall_clear(b,a:Vector2i,z:Vector2i)->bool:
 var distance=Vector2(z-a);var n=maxi(1,ceili(distance.length()*8))
 for i in range(1,n+1):
  var p=Vector2(a)+Vector2(.5,.5)+distance*float(i)/n
  if b.sim.walls.has(Vector2i(floori(p.x),floori(p.y))):return false
 return true
func architecture(b):
 prepare(b)
 b.draw_rect(Rect2(Vector2.ZERO,b.size),Color('101d2c'))
 for y in b.sim.height:
  for x in b.sim.width:
   var p=Vector2i(x,y);var r=Rect2(b.origin+Vector2(p)*b.tile,b.tile)
   if b.sim.walls.has(p):
    b.draw_rect(r,Color('273749'))
    # Narrow limestone edges distinguish actual walls from empty background.
    for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if not floor_cell(b,p+d):continue
     var edge=r.position+b.tile*.5+Vector2(d)*b.cell_size*.5
     var side=Vector2(d).orthogonal()*b.cell_size*.5
     b.draw_line(edge-side,edge+side,Color('c5c9c3'),5,true)
     b.draw_line(edge-side-Vector2(d)*3,edge+side-Vector2(d)*3,Color('eef0e8'),1,true)
   else:
    b.draw_rect(r,Color('d8e1e3') if (x+y)%4 else Color('d2dcde'))
    # Sparse marble veins, deterministic and much subtler than a full grid.
    if (x*3+y*7)%11==0:
     b.draw_line(r.position+b.tile*Vector2(.05,.2),r.position+b.tile*Vector2(.63,.43),Color('a3b3b5',.19),1,true)
     b.draw_line(r.position+b.tile*Vector2(.63,.43),r.position+b.tile*Vector2(.97,.72),Color('a3b3b5',.14),1,true)
    if b.sim.walls.has(p+Vector2i.UP):
     b.draw_rect(Rect2(r.position,Vector2(b.cell_size,b.cell_size*.17)),Color('273c52',.18))
    if b.sim.walls.has(p+Vector2i.LEFT):b.draw_rect(Rect2(r.position,Vector2(3,b.cell_size)),Color('273c52',.12))
 for lamp in lights:
  var radius=lamp.radius*b.cell_size
  var rect=Rect2(b.point(lamp.pos)-Vector2.ONE*radius,Vector2.ONE*radius*2)
  for cell in lamp.cells:
   var dest=Rect2(b.origin+Vector2(cell)*b.tile,b.tile).intersection(rect)
   if not dest.has_area():continue
   var src=Rect2((dest.position-rect.position)/rect.size*96,dest.size/rect.size*96)
   b.draw_texture_rect_region(glow,dest,src,lamp.color)
  if lamp.sconce:
   var at=b.point(lamp.pos)-Vector2(0,b.cell_size*.48)
   b.draw_texture_rect(glow,Rect2(at-Vector2(16,11),Vector2(32,22)),false,Color('ffd591',.48))
   b.draw_line(at-Vector2(5,0),at+Vector2(5,0),Color('b29561'),4,true)
   b.draw_line(at-Vector2(4,0),at+Vector2(4,0),Color('fff0c9'),2,true)
func focused_terminal(b)->Dictionary:
 if b.state.get('outcome','')!='planning':return {}
 for cell in [b.hover,b.preview_cell]:
  for o in b.state.objects:
   if o.type=='terminal' and o.pos==cell:return o
 return {}
func links(b,t:Dictionary)->Array:
 var result=[]
 for l in b.state.lasers:
  if l.get('circuit','')==t.get('circuit','') and not l.get('circuit','').is_empty():result.append({'kind':'laser','id':l.id,'cells':l.cells})
 for c in b.state.cameras:
  if c.get('circuit','')==t.get('circuit','') and not c.get('circuit','').is_empty():result.append({'kind':'camera','id':c.id,'cells':[c.pos]})
 for d in b.state.objects:
  if d.get('authorization_terminal','')==t.id:result.append({'kind':'door','id':d.id,'cells':[d.pos],'ticks':d.get('authorization_ticks',0)})
 return result
func connections(b):
 if b.state.get('outcome','')!='planning' or not b.state.objects.any(func(o):return o.type=='terminal'):return
 var terminal=focused_terminal(b)
 var footer=Rect2(8,b.size.y-29,b.size.x-16,24)
 b.draw_rect(footer,Color('101d2c',.97))
 if terminal.is_empty():
  b._text(footer.position+Vector2(8,17),'Наведите на терминал — покажем его устройства',Color('a5b9c8'),14)
  return
 var accent=Color('68e4e2');var labels=[]
 for link in links(b,terminal):
  var center=Vector2.ZERO
  for cell in link.cells:
   center+=b.point(cell)
   b.draw_rect(Rect2(b.point(cell)-b.tile*.5,b.tile),Color(accent,.13))
   for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    if cell+d in link.cells:continue
    var edge=b.point(cell)+Vector2(d)*b.cell_size*.5
    var side=Vector2(d).orthogonal()*b.cell_size*.5
    b.draw_line(edge-side,edge+side,Color(accent,.8),1.5,true)
  center/=maxi(1,link.cells.size())
  var start=b.point(terminal.pos);var bend=Vector2(center.x,start.y)
  var path=PackedVector2Array([start,bend,center])
  b.draw_polyline(path,Color('071724',.65),5,true)
  for n in 2:b.draw_dashed_line(path[n],path[n+1],accent,1.5,6)
  var length=start.distance_to(bend)+bend.distance_to(center)
  var travel=fmod(b.clock*45,maxf(length,1))
  var dot=start.move_toward(bend,travel) if travel<start.distance_to(bend) else bend.move_toward(center,travel-start.distance_to(bend))
  b.draw_circle(dot,3,Color('e8ffff'))
  var title={'laser':'Лазеры','camera':'Камера','door':'Допуск'}[link.kind]
  var name={'gallery':'галерея','vault':'хранилище'}.get(link.id,link.id)
  labels.append(Loc.text(title)+' '+Loc.text(name)+(' %.0f '%(link.ticks/20.0)+Loc.text('с') if link.kind=='door' else ''))
 b.draw_arc(b.point(terminal.pos),b.cell_size*.6,0,TAU,32,accent,2,true)
 b._text(footer.position+Vector2(8,17),terminal.id+' → '+', '.join(labels)+'  ·  '+Loc.text('окно')+' %.1f '%(terminal.window/20.0)+Loc.text('с'),accent,14)
