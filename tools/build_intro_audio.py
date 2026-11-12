"""Original 19-second intro cue: soft synth pads, plucked minor melody, final chime."""
import math
import struct
import wave
from pathlib import Path
RATE = 22050
DURATION = 19
notes = [(0, 50), (.6, 57), (1.2, 62), (2.4, 65), (3, 64), (4, 57),
         (5, 62), (5.5, 69), (6, 65), (7, 64), (8, 60), (9, 57),
         (10, 62), (10.5, 65), (11, 69), (12, 74), (13, 77), (14, 74),
         (15, 69), (16, 62)]
out = bytearray()
for i in range(RATE * DURATION):
    t = i / RATE
    fade = min(1, t / .8, max(0, (DURATION - t) / 2.5))
    value = 0.0
    for n in [38, 50, 57, 65]:
        f = 440 * 2 ** ((n - 69) / 12)
        value += .022 * math.sin(math.tau*f*t + .2*math.sin(t*.7))
    for start, n in notes:
        age = t - start
        if 0 <= age < 3:
            f = 440 * 2 ** ((n - 69) / 12)
            env = min(1, age / .018) * math.exp(-age*2.1)
            value += env * (.12*math.sin(math.tau*f*age) + .035*math.sin(math.tau*f*2*age))
    out += struct.pack('<h', int(max(-1,min(1,value*fade)) * 32767))
path = Path(__file__).resolve().parents[1] / 'assets/audio/intro.wav'
with wave.open(str(path), 'wb') as wav:
    wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE); wav.writeframes(out)
