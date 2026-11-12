extends SceneTree
const Sim=preload('res://scripts/simulation_v5.gd')
var passed=0
var failures=0
func check(ok:bool,title:String):
 if ok:passed+=1;print('PASS ',title)
 else:failures+=1;push_error(title)
func scene(level:int=2,lesson:int=0):
 var s=Sim.new();s.set_level(level,lesson);s.record=false;return s
func _initialize():
 check(Sim.LEVEL_NAMES.size()==4 and FileAccess.file_exists('res://data/levels/09.json'),'Fourth mission is the new Zero Minute map')
 var malformed=[{'type':'timer','ticks':20},{'type':'timer','seconds':1,'timer':7},{'type':'repeat','count':.5},{'type':'repeat','count':INF},{'type':'wait','ticks':.5},{'type':'wait','seconds':NAN},{'type':'send','signal':'A','value':'yes'},{'type':'noise','target':[1.5,2]},{'type':'noise','target':[NAN,2]},{'type':'interact','object':42},{'type':'condition','any':7},{'type':'condition','all':[false]},{'type':'condition','condition':'front_clear','negate':'no'},{'type':'condition','condition':'camera_safe','ticks':-1},{'type':'end'},{'type':'else'}]
 for c in malformed:
  var p=[[c],[],[]]
  check(not Sim.validate(p).is_empty(),'Reject malformed block '+str(c))
  var s=scene(0);s.reset(p);s.start()
  check(s.outcome=='lost','Malformed block cannot enter execution')
 check(Sim.validate([[],[],[]],true).is_empty(),'Empty draft is valid for loading')
 check(not Sim.validate([[],[],[]]).is_empty(),'Empty draft cannot start a run')
 var s=scene(0);s.reset([[{'type':'wait','ticks':1}],[],[]]);s.start();s.step()
 check(s.outcome=='lost' and 'Программы завершены' in s.events.back().message,'Exhausted programs end with a clear failure instead of hanging forever')
 s=scene(0,5);s.reset([[],[{'type':'interact','object':'item1'},{'type':'interact','object':'item2'}],[]]);s.active_ids=[1];s.robots[1].pos=Vector2i(3,2);s.start()
 for i in 41:s.step()
 check(s.outcome=='lost' and s.robots[1].item=='item1' and s.object('item2').carrier==-1,'Second pickup cannot overwrite the carried exhibit')
 s=scene(0,5);s.reset([[{'type':'select'},{'type':'select'},{'type':'wait','seconds':1}],[],[]]);s.active_ids=[0];s.robots[0].pos=Vector2i(2,1);s.start();s.step();s.robots[0].pos=Vector2i(2,3);s.step()
 check(s.object('item1').owner==-1 and s.object('item2').owner==0,'Reselecting releases the old reservation')
 s=scene();s.reset([[{'type':'interact','object':'item3'},{'type':'interact'},{'type':'interact'},{'type':'wait','seconds':1}],[],[]]);s.active_ids=[0];s.guards=[];s.cameras=[];s.lasers=[];s.robots[0].pos=Vector2i(17,5);s.start()
 for i in 40:s.step()
 s.robots[0].pos=Vector2i(1,13);s.step()
 check(s.object('item3').delivered and s.robots[0].target_item.is_empty(),'Delivery clears the selected exhibit')
 s.robots[0].pos=Vector2i(13,12);s.step()
 check(s.object('door1').until>s.tick and not s.robots[0].blocked,'Interaction after delivery uses the nearby button')
 s=scene();s.reset([[{'type':'interact','object':'missing'}],[],[]]);s.active_ids=[0];s.robots[0].pos=Vector2i(13,12);s.start();s.step()
 check(s.outcome=='lost' and not s.object('door1').open,'Invalid explicit object does not silently press a different button')
 s=scene();s.reset([[{'type':'noise','target':[17,9]},{'type':'wait','seconds':20}],[],[]]);s.active_ids=[0];s.robots[0].pos=Vector2i(15,9);s.start();s.step()
 check(s.guard.state=='inspect','Noise on the guard cell starts inspection immediately')
 for i in 300:s.step()
 check(s.guard.state=='patrol' and s.guard.pos==Vector2i(17,9),'Guard leaves same-cell inspection without getting stuck')
 s=scene();s.reset([[{'type':'noise','target':[14,10]},{'type':'wait','seconds':20}],[],[]]);s.active_ids=[0];s.robots[0].pos=Vector2i(13,12)
 for p in [Vector2i(14,9),Vector2i(15,10),Vector2i(14,11)]:
  var row:String=s.data.grid[p.y];s.data.grid[p.y]=row.substr(0,p.x)+'W'+row.substr(p.x+1)
 s.start();s.step()
 check(s.guard.state=='patrol' and not s.robots[0].blocked,'Unreachable visible noise does not trap the sentry in investigation')
 s=scene();var frame=s.view();var vault=s.lasers.back();s.object('terminal1').off_until=1000
 check(s.laser_active(vault,frame.tick,frame.objects) and not s.laser_active(vault,frame.tick),'Replay laser state uses the recorded terminal, not the current one')
 print('REGRESSION RESULT ',passed,' passed; ',failures,' failed');quit(1 if failures else 0)
