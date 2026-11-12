extends SceneTree
## Geometry and visibility audit against the supplied map and production level.
const Sim=preload('res://scripts/simulation_v5.gd')
var report={'map':{},'distances':[],'visibility':[],'conflicts':[]}
func _initialize():call_deferred('audit')
func audit():
 var fixture=JSON.parse_string(FileAccess.get_file_as_string('res://design/zero_minute/preflight.json'))
 var sim=Sim.new();sim.set_level(3)
 assert(sim.data.grid==fixture.grid)
 assert(sim.data.cameras[0].cells==fixture.camera_cells)
 sim.width=28;sim.height=18;sim.data.grid=fixture.grid
 sim.walls.clear();sim.objects.clear();sim.guards.clear();sim.cameras.clear()
 for y in sim.height:
  for x in sim.width:
   if fixture.grid[y][x]=='#':sim.walls[Vector2i(x,y)]=true
 report.map={'width':28,'height':18,'rows_valid':fixture.grid.size()==18 and fixture.grid.all(func(row):return row.length()==28)}
 # Artifacts are impassable; closed doors are ignored for the quoted geometric distances.
 for pos in [Vector2i(19,6),Vector2i(19,2),Vector2i(24,16)]:sim.objects.append({'id':str(pos),'type':'item','pos':pos})
 for pair in [[Vector2i(8,12),Vector2i(20,7),17],[Vector2i(3,2),Vector2i(20,8),29],[Vector2i(3,2),Vector2i(8,12),15],[Vector2i(4,16),Vector2i(24,12),26],[Vector2i(4,16),Vector2i(22,12),24],[Vector2i(4,8),Vector2i(14,9),11],[Vector2i(3,2),Vector2i(14,9),18],[Vector2i(4,16),Vector2i(14,9),17]]:
  var length=sim.route(pair[0],pair[1],true).size()
  assert(length==pair[2])
  report.distances.append({'from':str(pair[0]),'to':str(pair[1]),'expected':pair[2],'actual':length})
  print('BFS ',pair[0],' -> ',pair[1],': ',length,' (expected ',pair[2],')')
 var spur=Vector2i(14,9)
 for radius in [3,4,5]:
  var poses=[]
  for x in range(12,17):
   for direction in [Vector2i.LEFT,Vector2i.RIGHT]:poses.append([Vector2i(x,11),direction])
  for g in poses:
   var seen=sim.visible(g[0],g[1],spur,radius)
   report.visibility.append({'from':str(g[0]),'target':str(spur),'radius':radius,'visible':seen,'expected':false})
   print('GUARD radius=',radius,' from=',g[0],' spur visible=',seen)
   if seen:report.conflicts.append('Test 7: spur visible from %s with radius %d'%[g[0],radius])
 print('NOISE range=',spur.distance_to(Vector2i(14,13)),' clear=',sim.line_clear(spur,Vector2i(14,13)))
 for radius in [3,4,5]:
  for target in [Vector2i(14,10),Vector2i(14,9),Vector2i(14,8)]:
   assert(sim.visible(Vector2i(14,11),Vector2i.UP,target,radius))
 var camera={'id':'CAM1','pos':Vector2i(1,11),'facing':Vector2i.RIGHT,'cells':[],'phase':0,'period':240,'active':80}
 for x in range(2,9):camera.cells.append(Vector2i(x,11))
 assert(not sim.camera_line_clear(camera,Vector2i(8,12)))
 assert(not sim.camera_line_clear(camera,Vector2i(4,10)))
 assert(not sim.camera_line_clear(camera,Vector2i(4,12)))
 for t in 240:
  sim.tick=t
  for target in [Vector2i(4,10),Vector2i(4,12),Vector2i(8,12)]:assert(not sim.camera_sees(camera,target))
  assert(sim.camera_sees(camera,Vector2i(4,11))==(t<80))
 print('CAMERA: 240 phases checked; button pocket and excluded cells safe')
 print('NORTH RETURN: all three column cells visible at every allowed radius')
 # Confirm the other claimed safe staging cells, as a control.
 for target in [Vector2i(20,9),Vector2i(20,10),Vector2i(24,12)]:
  var seen=false
  for x in range(12,17):
   for facing in [Vector2i.LEFT,Vector2i.RIGHT]:seen=seen or sim.visible(Vector2i(x,11),facing,target,5)
  print('STAGING ',target,' visible at max allowed radius=',seen)
  assert(not seen)
 var path='res://design/zero_minute/preflight_results.json'
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close()
 print('PREFLIGHT conflicts: ',report.conflicts.size(),' contradictions')
 quit(1 if not report.conflicts.is_empty() else 0)
