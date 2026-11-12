"""Original procedural score and SFX. Standard library only; no external recordings."""
import math, wave, struct, pathlib, random
OUT = pathlib.Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050
random.seed(41)
def save(name, seconds, sample, stereo=False):
    n = int(RATE*seconds)
    data = bytearray()
    for i in range(n):
        t=i/RATE
        value=sample(t, i)
        channels=value if stereo else (value,)
        for v in channels:
            data.extend(struct.pack('<h', int(max(-.94,min(.94,v))*32767)))
    with wave.open(str(OUT/(name+'.wav')), 'wb') as f:
        f.setnchannels(2 if stereo else 1); f.setsampwidth(2); f.setframerate(RATE);f.writeframes(data)
def note(m):return 440*2**((m-69)/12)
def music(t,i):
    # 32s, four suspended minor chords, soft felt-like arpeggios, long pad tails.
    chords=[[50,57,60,64],[46,53,57,60],[48,55,58,62],[45,52,57,60]]
    total=[0.,0.]
    for c,chord in enumerate(chords):
        age=(t-c*8)%32
        if age<11:
            env=min(1,age/2)*max(0,min(1,(11-age)/3))*.035
            for j,m in enumerate(chord):
                hz=note(m)
                for channel in range(2):
                    total[channel]+=env*(math.sin(2*math.pi*hz*t)+.22*math.sin(2*math.pi*(hz*2)*t+channel*.2))/(1+j*.2)
    step=int(t/.5);age=t% .5
    chord=chords[int(t/8)%4];m=chord[[0,2,1,3,2,1,3,1][step%8]]+12
    # Repeat each note in the opposite ear as a gentle delay.
    for delay,gain in [(0,1),(.25,.35),(.5,.15)]:
        tt=(t-delay)%32;st=int(tt/.5);a=tt%.5;ch=chords[int(tt/8)%4]
        hz=note(ch[[0,2,1,3,2,1,3,1][st%8]]+12)
        pluck=(1-math.exp(-a*100))*math.exp(-a*8)*(.065*math.sin(2*math.pi*hz*a)+.012*math.sin(2*math.pi*hz*3*a))
        total[0]+=pluck*gain*(.8 if st%2 else 1)
        total[1]+=pluck*gain*(1 if st%2 else .8)
    fade = min(1, t/.04, (32-t)/.04)
    return tuple(v*max(0,fade) for v in total)
save('museum_night',32,music,True)
save('laser_hum',2,lambda t,i: .12*math.sin(2*math.pi*110*t)+.035*math.sin(2*math.pi*660*t)*(0.7+.3*math.sin(2*math.pi*2*t)))
for name,up in [('laser_off',False),('laser_on',True)]:
    save(name,.45,lambda t,i,up=up: .25*math.sin(2*math.pi*((180 if up else 900)*t+(750 if up else -750)*t*t))*(1-t/.45)**2)
save('hack',.16,lambda t,i: .18*math.sin(2*math.pi*1200*t)*math.exp(-t*35))
save('signal',.22,lambda t,i: .13*math.sin(2*math.pi*(880 if t<.11 else 1320)*t)*math.sin(math.pi*t/.22)**2)
save('diamond',1.1,lambda t,i: sum(.13*math.sin(2*math.pi*note(m)*t)*math.exp(-t*(3+j)) for j,m in enumerate([86,90,93])))
save('noise',.4,lambda t,i: (random.random()-.5)*.25*math.exp(-t*12)+.12*math.sin(2*math.pi*190*t)*math.exp(-t*9))
save('alarm',.8,lambda t,i: .17*math.sin(2*math.pi*550*t+8*math.sin(2*math.pi*4*t))*math.sin(math.pi*t/.8)**.5)
save('success',1.4,lambda t,i: sum((.14*math.sin(2*math.pi*note(m)*(t-j*.14))*math.exp(-(t-j*.14)*3) if t>=j*.14 else 0) for j,m in enumerate([62,65,69,74])))
print('Generated original ambient loop and 8 sound effects')
