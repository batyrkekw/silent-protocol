extends Node
## Presentation-only localization: never changes simulation state or user-entered IDs.
static var catalog:Dictionary={}
static var templates:Array=[]
static var fragments:RegEx
static var cache:Dictionary={}
static var active_locale=""
static var cyrillic:RegEx
static var paragraphs:Array=[]
static func install() -> void:
 if not catalog.is_empty():return
 cyrillic=RegEx.new();cyrillic.compile('[А-Яа-яЁё]')
 catalog=JSON.parse_string(FileAccess.get_file_as_string('res://data/i18n/catalog.json'))
 for row in JSON.parse_string(FileAccess.get_file_as_string('res://data/i18n/templates.json')):
  var regex=RegEx.new();regex.compile(row.pattern);row.regex=regex;templates.append(row)
 var keys=catalog.keys();keys.sort_custom(func(a,b):return a.length()>b.length())
 for key in keys:
  if '\n' in key and key.length()>100:paragraphs.append(key)
 var escaped:Array[String]=[]
 var escape=RegEx.new();escape.compile('[\\\\.\\^$|?*+()\\[\\]{}]')
 for key in keys:
  if '%' in key or key in ['Русский','Қазақша']:continue
  var literal=escape.sub(key,'\\$0',true)
  escaped.append('(?<![\\p{L}\\p{N}_])'+literal+'(?![\\p{L}\\p{N}_])' if not key.begins_with(' ') and not key.ends_with(' ') else literal)
 fragments=RegEx.new();fragments.compile('|'.join(escaped))
 for locale in ['ru','kk','en']:
  var translation=Translation.new();translation.locale=locale
  for key in catalog:translation.add_message(key,key if locale=='ru' else catalog[key][locale])
  TranslationServer.add_translation(translation)
 var config=ConfigFile.new();config.load('user://language.cfg')
 TranslationServer.set_locale(config.get_value('ui','language','ru'))
static func set_language(locale:String) -> void:
 TranslationServer.set_locale(locale)
 var config=ConfigFile.new();config.set_value('ui','language',locale);config.save('user://language.cfg')
static func text(value:String,depth:int=0)->String:
 var locale=TranslationServer.get_locale().substr(0,2)
 if locale not in ['kk','en'] or value.is_empty() or cyrillic.search(value)==null:return value
 if locale!=active_locale:cache.clear();active_locale=locale
 if cache.has(value):return cache[value]
 var result=value
 if catalog.has(value):result=catalog[value][locale]
 elif depth<4:
  if '\n' in value:
   var expanded=value
   for paragraph in paragraphs:expanded=expanded.replace(paragraph,str(catalog[paragraph][locale]))
   var lines:Array[String]=[]
   for line in expanded.split('\n'):lines.append(text(line,depth+1))
   var joined='\n'.join(lines)
   cache[value]=joined
   return joined
  var found=false
  for row in templates:
   var matched=row.regex.search(value)
   if matched==null:continue
   result=catalog[row.key][locale]
   for i in row.slots.size():
    var slot=row.slots[i];var at=result.find(slot)
    if at>=0:result=result.substr(0,at)+text(matched.get_string(i+1),depth+1)+result.substr(at+slot.length())
   found=true;break
  if not found:
   result='';var previous=0
   for match_result in fragments.search_all(value):
    result+=value.substr(previous,match_result.get_start()-previous)+str(catalog[match_result.get_string()][locale])
    previous=match_result.get_end()
   result+=value.substr(previous)
 if cache.size()>12000:cache.clear()
 cache[value]=result
 return result
func _ready():process_priority=1000
func _process(_delta):refresh(get_parent())
func refresh(node:Node)->void:
 if node==self:return
 if node is Control: _property(node,'tooltip_text')
 if node is Label or node is RichTextLabel or node is Button: _property(node,'text')
 if node is LineEdit:_property(node,'placeholder_text')
 if node is Window:_property(node,'title')
 if node is OptionButton or node is PopupMenu:
  for i in node.item_count:
   var key='locale_item_'+str(i);var current=node.get_item_text(i);var saved=node.get_meta(key,{'raw':current,'shown':current})
   if current!=saved.shown:saved.raw=current
   saved.shown=text(saved.raw);node.set_item_text(i,saved.shown);node.set_meta(key,saved)
 for child in node.get_children():refresh(child)
func _property(node:Node,property:String)->void:
 if node.get_meta('localization_manual',false):return
 var key='locale_'+property;var current=str(node.get(property));var saved=node.get_meta(key,{'raw':current,'shown':current})
 var locale=TranslationServer.get_locale()
 if current==saved.shown and saved.get('locale','')==locale:return
 saved.locale=locale
 if current!=saved.shown:saved.raw=current
 saved.shown=text(saved.raw)
 if current!=saved.shown:node.set(property,saved.shown)
 node.set_meta(key,saved)
