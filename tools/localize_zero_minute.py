import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'data/i18n/catalog.json';d=json.loads(p.read_text())
rows=[
('Нулевая минута','Zero Minute','Нөлдік минут'),('Ранний шум','Early noise','Ерте шу'),('Поздний терминал','Late terminal','Кешіккен терминал'),
('Шум готов','Noise ready','Шу дайын'),('Плита занята','Plate occupied','Тақта басылған'),('Охранник патрулирует','Guard patrolling','Күзетші патрульде'),('Охранник на паузе','Guard paused','Күзетші тоқтап тұр'),('Охранник осматривает нишу','Guard inspecting alcove','Күзетші қуысты тексеруде'),('Охранник идёт на шум','Guard approaching noise','Күзетші шуға барады'),('Охранник смотрит на восток','Guard facing east','Күзетші шығысқа қарап тұр'),('Охранник смотрит вдоль коридора','Guard facing along corridor','Күзетші дәліз бойына қарап тұр'),('Камера активна','Camera active','Камера белсенді'),('Лазер включён','Laser active','Лазер қосулы'),('Через, с','Look ahead, s','Қанша секундтан кейін'),('через','in','кейін'),
('Кнопка ждёт нового взлома','Button awaiting a fresh hack','Батырма жаңа бұзуды күтуде'),('Дверь галереи закрылась: истекли 120 тиков. Продлите окно кнопкой.','Gallery door closed after 120 ticks. Extend the window with the button.','Галерея есігі 120 тактіден кейін жабылды. Батырмамен уақытын ұзартыңыз.'),('Дверь галереи закрылась в занятом проёме. Вторая кнопка не нажата.','Gallery door closed on an occupied doorway. The button was not pressed again.','Галерея есігі робот тұрған өткелде жабылды. Батырма екінші рет басылмады.'),('столкновение с охранником','collision with guard','күзетшімен соқтығыс'),('Шум: нужна прямая видимость и радиус 5 клеток','Noise requires line of sight and a range of 5 cells','Шу үшін тікелей көріну және 5 ұяшықтық қашықтық қажет'),('Неверный объект взаимодействия:','Invalid interaction target:','Әрекет нысаны жарамсыз:'),('ждёт сигнал','awaits signal','сигналды күтуде'),('но никто его не отправляет','but nobody sends it','бірақ оны ешкім жібермейді'),('сценария','scenarios','сценарий'),('Сохранённая устойчивость этой программы:','Saved reliability for this program:','Осы бағдарламаның сақталған тұрақтылығы:'),('Одна программа','One program','Бір бағдарлама'),
('Робот в проёме задерживает закрытие тяжёлой двери на уровнях 1–3.','On levels 1–3, a robot in a doorway prevents a heavy door from closing.','1–3-деңгейде өткелде тұрған робот ауыр есіктің жабылуын тоқтатады.'),('Финал: дверь галереи закрывается строго по таймеру, даже в занятом проёме.','Finale: the gallery door closes on its timer, even with a robot in the doorway.','Финалда галерея есігі өткелде робот болса да таймер бойынша жабылады.'),('Первое нажатие — в первые 60 тиков после взлома T_S; повторное — до закрытия.','First press: within 60 ticks of hacking T_S. Press again before the door closes.','Алғашқы басу: T_S бұзылғаннан кейінгі 60 такт ішінде. Есік жабылмай тұрып қайта басыңыз.'),('Конус 90°, длина 3–5 клеток.','90° cone, 3–5 cells long.','90° көру аймағы, ұзындығы 3–5 ұяшық.'),('Ночная смена: три сценария. Нулевая минута: четыре сценария после победы.','Night Shift: three scenarios. Zero Minute: four scenarios after victory.','Түнгі ауысым: үш сценарий. Нөлдік минут: жеңістен кейін төрт сценарий.')]
hint=json.loads((root/'data/levels/09.json').read_text())['hint']
rows.append((hint,'Finale: three robots, three artifacts. The gallery button accepts its first press within 60 ticks of a hack. The door closes after 120 ticks even if occupied; press again to extend it. Coordinate noise and security windows for the return trip.','Финал: үш робот, үш жәдігер. Галерея батырмасын бұзудан кейінгі 60 такт ішінде алғаш рет басыңыз. Өткелде робот тұрса да есік 120 тактіден кейін жабылады; уақытын ұзарту үшін қайта басыңыз. Қайтар жолда шу мен қорғаныс аралықтарын үйлестіріңіз.'))
for ru,en,kk in rows:d[ru]={'en':en,'kk':kk}
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
# Reuse the verified rules translation and replace only the changed rules.
source=(root/'scripts/main.gd').read_text()
new_rules=json.loads('"'+re.search(r'help_dialog.dialog_text="((?:[^"\\]|\\.)*)"',source).group(1)+'"')
old=next(v for k,v in d.items() if k.startswith('РОБОТЫ НЕ БЛОКИРУЮТ') and 'три сценария.' in k and 'Финал:' not in k)
translated={}
for lang in ['en','kk']:
 lines=old[lang].splitlines()
 lines[6]='\n'.join(d[key][lang] for key in ['Робот в проёме задерживает закрытие тяжёлой двери на уровнях 1–3.','Финал: дверь галереи закрывается строго по таймеру, даже в занятом проёме.','Первое нажатие — в первые 60 тиков после взлома T_S; повторное — до закрытия.'])
 lines[11]=d['Конус 90°, длина 3–5 клеток.'][lang]
 lines[-1]=d['Ночная смена: три сценария. Нулевая минута: четыре сценария после победы.'][lang]
 translated[lang]='\n'.join(lines)
d[new_rules]=translated
d[new_rules.replace('Смена этапа — сверху.','После победы нажмите «Следующий этап» в хронике или под картой.')]=translated
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
