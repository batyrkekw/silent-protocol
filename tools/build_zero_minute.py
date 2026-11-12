"""Immutable supplied geometry; level-four-only devices and four deterministic variants."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
f=json.loads((root/'design/zero_minute/preflight.json').read_text())
d={'id':8,'name':'Нулевая минута','grid':f['grid'],'robots':[{'id':i,'pos':[3,13+i]} for i in range(3)],'objects':[], 'guards':[{'pos':[12,11],'facing':[-1,0],'route':[[16,11],[12,11]],'index':0,'wait':60,'pause':60,'radius':3,'inspect':220,'nearest_return':True}], 'cameras':[{'id':'CAM1','pos':[1,11],'facing':[1,0],'cells':[[x,11] for x in range(2,9)],'period':240,'active':80,'phase':0}], 'lasers':[], 'noise':{'range':5,'hearing':8,'inspect':220,'cooldown':200},'noise_targets':[[14,13]],'hint':'Финал: три робота, три предмета. Кнопка галереи принимает первое нажатие в течение 60 тиков после взлома. Дверь закрывается через 120 тиков даже в занятом проёме; продлите её кнопкой. Для обратного пути согласуйте шум и окна защиты.','win':{'all_items_delivered':True,'all_active_robots_at_exit':True}}
o=d['objects']
for ident,pos,window,cooldown,circuit in [('T_S',[2,2],260,400,'gallery'),('T_V',[5,16],160,300,'vault')]:o.append({'id':ident,'type':'terminal','pos':pos,'hack':60,'window':window,'cooldown':cooldown,'circuit':circuit})
o.extend([{'id':'D_G','type':'door','pos':[20,7],'mode':'heavy','duration':120,'hold_occupied':False,'authorization_terminal':'T_S','authorization_ticks':60}, {'id':'B_G','type':'button','pos':[8,12],'door':'D_G'}, {'id':'D_V','type':'door','pos':[24,13],'mode':'plate','hold_occupied':True}, {'id':'P_V','type':'plate','pos':[22,12],'door':'D_V'}])
for ident,pos,name in [('E1',[19,6],'Золотой слиток'),('E2',[19,2],'Золотой банан'),('A',[24,16],'Алмаз')]:o.append({'id':ident,'type':'item','pos':pos,'name':name})
for i in range(3):o.append({'id':'exit'+str(i+1),'type':'exit','pos':[1,13+i]})
for ident,pos in [('near',[20,6]),('far',[20,2]),('staging',[20,8])]:o.append({'id':ident,'type':'marker','pos':pos,'name':ident})
for ident,xs,ys,excluded in [('gallery',range(18,23),range(2,7),[(19,6),(19,2)]),('vault',range(23,27),range(14,17),[(24,16)])]:d['lasers'].append({'id':ident,'circuit':ident,'cells':[[x,y] for y in ys for x in xs if (x,y) not in excluded]})
d['lasers'].append({'id':'LZ_M','cells':[[18,11]],'period':240,'off_start':160,'off_length':80,'phase':0})
d['scenarios']=[]
for name,phase,pos,facing,wait,index,ts,tv,noise in [('База',0,[12,11],[-1,0],60,0,0,0,0),('Сдвиг',120,[16,11],[1,0],30,1,0,0,0),('Поздний терминал',60,[14,11],[-1,0],0,1,150,0,0),('Ранний шум',180,[13,11],[1,0],0,0,0,100,120)]:
 d['scenarios'].append({'name':name,'laser_phases':[0,0,phase],'camera_phase':phase,'guard_pos':pos,'guard_facing':facing,'guard_wait':wait,'guard_index':index,'terminal_cooldowns':{'T_S':ts,'T_V':tv},'noise_remaining':noise})
(root/'data/levels/09.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
