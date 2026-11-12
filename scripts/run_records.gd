extends RefCounted
## Local-only personal bests. Separate time/size records and exact-plan reliability.
const Sim = preload('res://scripts/simulation_v5.gd')
var path: String
var entries: Dictionary = {}
var save_error = ""
func _init(file_path: String = 'user://personal_bests.json'):
 path=file_path
 if FileAccess.file_exists(path):
  var parser=JSON.new()
  if parser.parse(FileAccess.get_file_as_string(path))!=OK:return
  var data=parser.data
  if data is Dictionary and data.get('version')==1 and data.get('entries') is Dictionary:
   for key in data.entries:
    var entry=data.entries[key]
    if entry is Dictionary and _positive(entry.get('ticks')) and _positive(entry.get('blocks')):
     entries[key]=entry
func _positive(value)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=0
static func command_count(plan: Array) -> int:
 var count=0
 for program in plan:
  for c in program:
   if c.type not in ['end','else']:count+=1
 return count
static func signature(plan: Array) -> String:
 # JSON normalization makes hashes independent of int/float and dictionary key order.
 return JSON.stringify(plan,'',true,true).sha256_text()
static func key(sim) -> String:
 return '%d/%d/%d/%s'%[Sim.LEVEL_VERSION,sim.level,sim.stage,JSON.stringify(sim.data).sha256_text().substr(0,12)]
func best(sim) -> Dictionary:
 return entries.get(key(sim),{}).duplicate(true)
func finish(sim, plan: Array, eligible: bool = true) -> Dictionary:
 var blocks=command_count(plan)
 var previous=best(sim)
 var result={'ticks':sim.tick,'blocks':blocks,'previous':previous,'eligible':eligible,'new_time':false,'new_size':false}
 if not eligible or sim.outcome!='won':return result
 result.new_time=previous.is_empty() or sim.tick<int(previous.ticks)
 result.new_size=previous.is_empty() or blocks<int(previous.blocks)
 var entry=previous.duplicate(true)
 entry.ticks=mini(int(previous.get('ticks',sim.tick)),sim.tick)
 entry.blocks=mini(int(previous.get('blocks',blocks)),blocks)
 entry.last_ticks=sim.tick;entry.last_blocks=blocks
 entries[key(sim)]=entry
 _save()
 return result
func reliability(sim, plan: Array, successes: int, eligible: bool = true) -> void:
 if not eligible:return
 var entry=best(sim)
 if entry.is_empty():return
 entry.reliable_signature=signature(plan)
 entry.reliable_count=clampi(successes,0,sim.data.scenarios.size())
 entries[key(sim)]=entry;_save()
func _save() -> void:
 save_error=''
 var temporary=path+'.tmp'
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:save_error='Не удалось сохранить рекорд';return
 file.store_string(JSON.stringify({'version':1,'entries':entries},'  '));file.close()
 var error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
 if error!=OK:save_error='Не удалось обновить файл рекордов'
