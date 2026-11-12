"""Authoring tool only: writes explicit step/turn blocks; never used by the game."""
import json
from pathlib import Path
from collections import deque
ROOT = Path(__file__).resolve().parents[1]

def load(i):
    return json.loads((ROOT / f'data/levels/{i:02}.json').read_text())

def save(i, d):
    (ROOT / f'data/levels/{i:02}.json').write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n')

def rect(grid, x1, y1, x2, y2, ch='.'):
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            grid[y][x] = ch
d = load(8)
g = [list(r) for r in d['grid']]
rect(g, 13, 10, 14, 11)
g[11][13] = 'W'
g[10][13] = '#'
g[9][10] = '.'
g[9][17] = 'G'
g[12][12] = 'T'
d['grid'] = [''.join(r) for r in g]
d['objects'] = [o for o in d['objects'] if o['id'] not in ['terminal2', 'staging']]
d['objects'] += [dict(id='terminal2', type='terminal', pos=[12, 12], hack=40, window=480, cooldown=80, circuit='security'), dict(id='staging', type='marker', pos=[17, 7], name='Шлюз')]
d['objects'][0]['window'] = 280
for o in d['objects']:
    if o['type'] == 'item':
        o['name'] = ['Алмаз', 'Золотой слиток', 'Золотой банан'][int(o['id'][-1]) - 1]
d['guards'] = [dict(pos=[17, 9], facing=[1, 0], route=[[17, 9]], index=0, wait=0, pause=0, radius=5, mode='post', inspect=260)]
d['cameras'] = [c for c in d['cameras'] if c['id'] == 'CAM1'] + [dict(id='CAM2', pos=[22, 11], facing=[-1, 0], cells=[[21, y] for y in range(9, 14)], circuit='security')]
for v in d['scenarios']:
    v.update(guard_pos=[17, 9], guard_facing=[1, 0], guard_wait=0, guard_index=0)
d['noise_targets'] = [[14, 10]]
d['hint'] = 'Пост у шлюза не патрулирует. МОНА: камера, шум через окно и кнопка двери. Согласуйте каждый проход сигналами.'
save(8, d)
DIR = [(1, 0), (0, 1), (-1, 0), (0, -1)]

class Plan:

    def __init__(self, d, id):
        self.d = d
        self.pos = tuple(next((r['pos'] for r in d['robots'] if r['id'] == id)))
        self.facing = 0
        self.p = []

    def add(self, t, **kw):
        self.p.append(dict(type=t, **kw))
        return self

    def face(self, f):
        delta = (f - self.facing) % 4
        if delta == 3:
            self.add('left')
        else:
            for _ in range(delta):
                self.add('right')
        self.facing = f
        return self

    def steps(self, n, back=False, compact=False):
        if compact and n >= 3:
            self.add('repeat', count=n)
        for _ in range(1 if compact and n >= 3 else n):
            self.add('backward' if back else 'forward')
        if compact and n >= 3:
            self.add('end')
        v = DIR[self.facing]
        sign = -1 if back else 1
        self.pos = (self.pos[0] + sign * n * v[0], self.pos[1] + sign * n * v[1])
        return self

    def path(self, target):
        target = tuple(target)
        q = deque([self.pos])
        prev = {self.pos: None}
        items = [tuple(o['pos']) for o in self.d['objects'] if o['type'] == 'item']
        while q:
            p = q.popleft()
            if p == target:
                break
            for dx, dy in DIR:
                c = (p[0] + dx, p[1] + dy)
                if c in prev or c in items or (not (0 <= c[1] < len(self.d['grid']) and 0 <= c[0] < len(self.d['grid'][0]))) or (self.d['grid'][c[1]][c[0]] in '#W'):
                    continue
                prev[c] = p
                q.append(c)
        assert target in prev, (self.pos, target)
        out = []
        p = target
        while p != self.pos:
            out.append(p)
            p = prev[p]
        return out[::-1]

    def walk(self, *target):
        if len(target) == 1:
            if target[0] == 'exit':
                target = min([tuple(o['pos']) for o in self.d['objects'] if o['type'] == 'exit'], key=lambda p: len(self.path(p)))
            else:
                target = next((o['pos'] for o in self.d['objects'] if o['id'] == target[0]))
        for p in self.path(target):
            f = DIR.index((p[0] - self.pos[0], p[1] - self.pos[1]))
            back = (f - self.facing) % 4 == 2
            if not back:
                self.face(f)
            self.steps(1, back)
        return self

    def cond(self, name, **kw):
        return self.add('condition', condition=name, **kw)

    def send(self, name, value=True):
        return self.add('send', signal=name, value=value)

    def waitsig(self, name, value=True):
        return self.add('wait_signal', signal=name, value=value)

    def interact(self, id=None):
        return self.add('interact', **{'object': id} if id else {})

def output(i, ps):
    (ROOT / f'data/programs/{i:02}.json').write_text(json.dumps([p.p if p else [] for p in ps], ensure_ascii=False, indent=2) + '\n')
d = load(1)
p = Plan(d, 0)
p.add('forward').interact('button1').add('repeat', count=3).add('forward').add('end')
output(1, [p, None, None])
d['hint'] = 'Откройте дверь кнопкой и выведите Лувра в светящуюся арку. Программа управляет им сама.'
save(1, d)
d = load(2)
p = Plan(d, 0)
p.walk('terminal1').interact('terminal1').cond('laser_safe', device='L', ticks=50).walk('exit')
output(2, [p, None, None])
d = load(3)
a, b, c = [Plan(d, i) for i in range(3)]
a.walk('plate1').send('ЛЕВАЯ_ПЛИТА').waitsig('ПРАВАЯ_ПЛИТА').walk('exit').send('ЛЕВЫЙ_ВЫШЕЛ')
b.waitsig('ЛЕВАЯ_ПЛИТА').walk('plate2').send('ПРАВАЯ_ПЛИТА').waitsig('ЛЕВЫЙ_ВЫШЕЛ').walk('exit')
c.waitsig('ПРАВАЯ_ПЛИТА').walk('exit')
output(3, [a, b, c])
d = load(4)
a, b, c = [Plan(d, i) for i in range(3)]
a.walk(6, 1).add('noise', target=[6, 5]).cond('guard_in_niche').send('ЗАЛ_СВОБОДЕН').walk(11, 1).walk('exit')
for p in [b, c]:
    p.waitsig('ЗАЛ_СВОБОДЕН').walk(6, 1).walk(11, 1).walk('exit')
output(4, [a, b, c])
d = load(5)
p = Plan(d, 0)
p.add('timer', timer='СТАРТ', seconds=0.5).cond('timer_done', timer='СТАРТ').walk(4, 1)
p.add('if', condition='camera_safe', ticks=50).walk(11, 1).add('else')
p.pos = (4, 1)
p.facing = 0
p.walk(3, 3).face(0).cond('laser_safe', device='L', ticks=21).walk(11, 3).walk(11, 1).add('end')
output(5, [p, None, None])
d = load(6)
a, b, c = [Plan(d, i) for i in range(3)]
a.walk('plate1').send('ЛЕВАЯ_ПЛИТА').waitsig('ПРАВАЯ_ПЛИТА').walk('exit').send('ЛЕВЫЙ_ВЫШЕЛ')
b.waitsig('ЛЕВАЯ_ПЛИТА').walk(3, 2).face(0).add('while', condition='items_free').add('select').interact('selected').steps(8, compact=True).interact().steps(8, back=True, compact=True).add('end').walk(6, 2).walk('plate2').send('ПРАВАЯ_ПЛИТА').waitsig('ЛЕВЫЙ_ВЫШЕЛ').walk('exit')
c.waitsig('ЛЕВАЯ_ПЛИТА').walk('exit')
output(6, [a, b, c])
d = load(7)
source = [[{'type': 'goto', 'target': [12, 14]}, {'type': 'wait_signal', 'signal': 'ПЛИТА_ДЕРЖИТСЯ'}, {'type': 'wait_signal', 'signal': 'НОСИТЕЛЬ_ГОТОВ'}, {'type': 'interact', 'object': 'terminal1'}, {'type': 'goto', 'target': 'exit'}], [{'type': 'goto', 'target': [4, 6]}, {'type': 'goto', 'target': [7, 6]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ2', 'ticks': 21}, {'type': 'goto', 'target': [9, 6]}, {'type': 'goto', 'target': [13, 4]}, {'type': 'goto', 'target': [13, 3]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ1', 'ticks': 21}, {'type': 'goto', 'target': [15, 3]}, {'type': 'goto', 'target': 'plate1'}, {'type': 'send', 'signal': 'ПЛИТА_ДЕРЖИТСЯ', 'value': True}, {'type': 'wait_signal', 'signal': 'ДОБЫЧА_ВЫНЕСЕНА'}, {'type': 'goto', 'target': [15, 3]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ1', 'ticks': 21}, {'type': 'goto', 'target': [13, 3]}, {'type': 'goto', 'target': [13, 4]}, {'type': 'goto', 'target': [13, 6]}, {'type': 'goto', 'target': [9, 6]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ2', 'ticks': 21}, {'type': 'goto', 'target': [7, 6]}, {'type': 'goto', 'target': [4, 6]}, {'type': 'goto', 'target': 'exit'}], [{'type': 'goto', 'target': [4, 6]}, {'type': 'goto', 'target': [7, 6]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ2', 'ticks': 21}, {'type': 'goto', 'target': [9, 6]}, {'type': 'goto', 'target': [13, 4]}, {'type': 'goto', 'target': [13, 3]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ1', 'ticks': 21}, {'type': 'goto', 'target': [15, 3]}, {'type': 'goto', 'target': [18, 3]}, {'type': 'wait_signal', 'signal': 'ПЛИТА_ДЕРЖИТСЯ'}, {'type': 'send', 'signal': 'НОСИТЕЛЬ_ГОТОВ', 'value': True}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'VAULT'}, {'type': 'goto', 'target': [21, 3]}, {'type': 'interact', 'object': 'item1'}, {'type': 'goto', 'target': [18, 3]}, {'type': 'send', 'signal': 'ДОБЫЧА_ВЫНЕСЕНА', 'value': True}, {'type': 'goto', 'target': [15, 3]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ1', 'ticks': 41}, {'type': 'goto', 'target': [13, 3]}, {'type': 'goto', 'target': [13, 4]}, {'type': 'goto', 'target': [13, 6]}, {'type': 'goto', 'target': [9, 6]}, {'type': 'condition', 'condition': 'laser_safe', 'device': 'LZ2', 'ticks': 41}, {'type': 'goto', 'target': [7, 6]}, {'type': 'goto', 'target': [4, 6]}, {'type': 'goto', 'target': 'exit'}, {'type': 'interact'}]]
ps = []
for id, old in enumerate(source):
    p = Plan(d, id)
    for i, c in enumerate(old):
        if c['type'] == 'goto':
            t = c['target']
            p.walk(*t) if isinstance(t, list) else p.walk(t)
        else:
            if c['type'] == 'condition' and i + 1 < len(old) and (old[i + 1]['type'] == 'goto') and isinstance(old[i + 1]['target'], list):
                path = p.path(old[i + 1]['target'])
                if path:
                    f = DIR.index((path[0][0] - p.pos[0], path[0][1] - p.pos[1]))
                    if (f - p.facing) % 4 != 2:
                        p.face(f)
            p.p.append(c)
    ps.append(p)
output(7, ps)
for level in [8]:
    d = load(level)
    a, b, c = [Plan(d, i) for i in range(3)]
    stage = (17, 7)
    stand = (13, 12)
    lure = [14, 10]
    a.walk(4, 11).face(3).cond('camera_safe', device='CAM1', ticks=41).walk(4, 7).walk(3, 1).face(0)
    apos = a.pos
    a.add('while', condition='items_pending').cond('ready_or_done', signal='ВЗЛОМ_ЗАПРОС').add('if', condition='signal_on', signal='ВЗЛОМ_ЗАПРОС')
    a.cond('terminal_ready', device='terminal1')
    a.interact('terminal1')
    a.send('ВЗЛОМ_ГОТОВ').cond('signal_off', signal='ВЗЛОМ_ЗАПРОС').send('ВЗЛОМ_ГОТОВ', False)
    a.add('end').add('end')
    a.walk(4, 7).face(1).cond('camera_safe', device='CAM1', ticks=41).walk(4, 11).walk('exit')
    b.walk(8, 13).face(0).cond('laser_safe', device='LZ_S1', ticks=21).walk(10, 13).walk(*stand)
    b.add('while', condition='items_pending')
    b.add('if', condition='signal_on', signal='ПРОХОД_ЗАПРОС').add('if', condition='signal_off', signal='ПРОХОД_ГОТОВ')
    b.cond('guard_posted').cond('terminal_ready', device='terminal2').interact('terminal2').add('noise', target=lure).cond('guard_distracted', ticks=250).send('ПРОХОД_ГОТОВ').add('end').add('end')
    b.add('if', condition='signal_on', signal='У_ДВЕРИ').interact('button1').add('end')
    b.add('timer', timer='ОБНОВЛЕНИЕ', seconds=2).cond('timer_done', timer='ОБНОВЛЕНИЕ').add('end')
    b.walk(10, 13).face(2).cond('laser_safe', device='LZ_S1', ticks=21).walk(8, 13).walk('exit')
    home = (3, 13)
    c.walk(*home).face(0)
    c.add('while', condition='items_free').add('select')
    c.walk(8, 13).face(0).cond('laser_safe', device='LZ_S1', ticks=21).walk(10, 13).walk(17, 13).face(0).cond('laser_safe', device='LZ_S2', ticks=21).walk(19, 13).walk(20, 13)
    c.send('ПРОХОД_ГОТОВ', False).send('ПРОХОД_ЗАПРОС').waitsig('ПРОХОД_ГОТОВ')
    c.walk(21, 13).walk(21, 9).walk(17, 9).walk(*stage)
    c.send('ПРОХОД_ЗАПРОС', False).send('У_ДВЕРИ').send('ВЗЛОМ_ГОТОВ', False).send('ВЗЛОМ_ЗАПРОС')
    c.waitsig('ВЗЛОМ_ГОТОВ').cond('door_open', device='door1').face(3)
    c.add('while', condition='selected_near', negate=True).add('forward').add('end').interact('selected')
    c.add('while', condition='at_marker', device='staging', negate=True).add('backward').add('end')
    c.pos = stage
    c.facing = 3
    c.send('ВЗЛОМ_ЗАПРОС', False)
    c.send('У_ДВЕРИ', False).send('ПРОХОД_ГОТОВ', False).send('ПРОХОД_ЗАПРОС').waitsig('ПРОХОД_ГОТОВ')
    c.walk(17, 9).walk(21, 9).walk(21, 13).walk(19, 13)
    c.send('ПРОХОД_ЗАПРОС', False)
    c.face(2).cond('laser_safe', device='LZ_S2', ticks=41).walk(17, 13).walk(10, 13).face(2).cond('laser_safe', device='LZ_S1', ticks=41).walk(8, 13).walk(1, 13).interact().walk(*home)
    c.face(0).add('end')
    c.walk('exit')
    output(level, [a, b, c])
print('Wrote eight maps/programs with relative movement only.')
