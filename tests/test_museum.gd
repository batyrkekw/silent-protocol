extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
const Board=preload('res://scripts/board.gd')
var failed=0
func check(ok,label):
 if not ok:failed+=1;push_error(label)
func _initialize():call_deferred('test')
func test():
 var sim=Sim.new();sim.set_level(3)
 var b=Board.new();b.sim=sim;b.state=sim.view();b.hover=Vector2i(2,2)
 var initial=sim.view().duplicate(true);var snapshot=b.state.duplicate(true)
 b.museum.prepare(b)
 var term=b.museum.focused_terminal(b);check(term.id=='T_S','T_S hover')
 var links=b.museum.links(b,term);check(links.size()==2 and links[0].id=='gallery' and links[1].id=='D_G','T_S actual circuit and door authorization only')
 b.hover=Vector2i(5,16);links=b.museum.links(b,b.museum.focused_terminal(b));check(links.size()==1 and links[0].id=='vault','T_V controls only vault')
 b.hover=Vector2i(-1,-1);b.preview_cell=Vector2i(2,2);check(b.museum.focused_terminal(b).id=='T_S','Command preview resolves terminal')
 b.state.outcome='running';check(b.museum.focused_terminal(b).is_empty(),'Circuit overlays hidden during execution');b.state.outcome='planning'
 check(sim.view()==initial and b.state==snapshot,'Lighting and links leave world and replay snapshot unchanged')
 b.free()
 for id in 9:
  var s=Sim.new();s.set_level(0 if id<6 else id-5,id if id<6 else 0);s.record=false;s.reset(s.solution());s.start()
  while s.outcome=='running' and s.tick<12000:s.step()
  # Read the established baselines for existing missions from the checked-in report.
  var view=Board.new();view.sim=s;view.state=s.view()
  for dimensions in [Vector2(700,320),Vector2(860,500),Vector2(1100,700)]:
   view.size=dimensions;view.cell_size=minf((dimensions.x-40)/s.width,(dimensions.y-60)/s.height);view.tile=Vector2.ONE*view.cell_size;view.origin=(dimensions-Vector2(0,26)-Vector2(s.width,s.height)*view.tile)/2
   view._layout_badges()
   var labels=s.objects.filter(func(o):return o.type=='terminal').size()+s.cameras.size()
   check(view.badge_rects.size()==labels,'All device labels have free space '+str(id))
   for box in view.badge_rects.values():
    for y in s.height:
     for x in s.width:
      if not s.walls.has(Vector2i(x,y)):check(not box.intersects(Rect2(view.origin+Vector2(x,y)*view.tile,view.tile)),'Label overlaps floor')
  view.museum.prepare(view)
  var fixtures=view.museum.lights.filter(func(l):return l.sconce)
  check(fixtures.size()<=6,'Sparse lighting')
  var positions=fixtures.map(func(l):return l.pos);view.museum.cache_key='';view.museum.prepare(view)
  check(view.museum.lights.filter(func(l):return l.sconce).map(func(l):return l.pos)==positions,'Lighting positions are stable')
  if id==8:print('FINAL LEVEL LIGHTS: ',fixtures.size())
  view.free()
  var old=JSON.parse_string(FileAccess.get_file_as_string('res://design/verification.json'))
  var expected=int(old.reference[id].tick) if id<8 else 4179
  check(s.outcome=='won' and s.tick==expected,'Unchanged reference timing '+str(id+1));print('MAP ',id+1,' ',s.outcome,' tick=',s.tick)
 for v in range(1,4):
  var s=Sim.new();s.set_level(3,0,v);s.record=false;s.reset(s.solution());s.start()
  while s.outcome=='running' and s.tick<12000:s.step()
  check(s.outcome=='won' and s.tick==[4179,4299,4119,4239][v],'Unchanged final scenario '+str(v))
 print('MUSEUM: lighting/circuit isolation and all reference timings; failures=',failed)
 quit(1 if failed else 0)
