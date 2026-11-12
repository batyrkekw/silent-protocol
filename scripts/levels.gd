extends RefCounted
static func make(index:int,stage:int=0)->Dictionary:
 if index<0 or index>=4 or stage<0 or stage>=6:return {}
 var id=stage if index==0 else index+5
 return JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%02d.json"%(id+1)))
