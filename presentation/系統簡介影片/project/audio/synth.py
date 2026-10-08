import numpy as np
from scipy import signal

SR = 48000
import json as _json, os as _os
TOTAL = _json.load(open(_os.path.join(_os.path.dirname(__file__), '../src/timeline.json'), encoding='utf-8'))['duration']
_rng = np.random.default_rng(1)

class Track:
    def __init__(self, seconds):
        self.buf = np.zeros((int(seconds * SR) + 1, 2), np.float64)
    def add(self, t, x, pan=0.0):
        if x.ndim == 1:
            a = (pan + 1) * np.pi / 4
            x = np.stack([x * np.cos(a), x * np.sin(a)], 1) * np.sqrt(2)
        i = int(round(t * SR))
        if i < 0: x, i = x[-i:], 0
        n = min(len(x), len(self.buf) - i)
        if n > 0: self.buf[i:i + n] += x[:n]

def mtof(m): return 440.0 * 2 ** ((m - 69) / 12)
def tt(d): return np.arange(int(d * SR)) / SR

def lp(x, f, order=2):
    sos = signal.butter(order, f, "low", fs=SR, output="sos"); return signal.sosfilt(sos, x, axis=0)
def hp(x, f, order=2):
    sos = signal.butter(order, f, "high", fs=SR, output="sos"); return signal.sosfilt(sos, x, axis=0)
def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], "band", fs=SR, output="sos"); return signal.sosfilt(sos, x, axis=0)

def env_adsr(n, a, r, total_hold):
    e = np.ones(n)
    na = max(1, int(a * SR)); e[:na] = np.linspace(0, 1, na)
    h = int(total_hold * SR)
    if h < n:
        nr = n - h
        e[h:] *= np.exp(-np.arange(nr) / (r * SR) * 5)
    return e

# ---------------- 樂器 ----------------
def piano(f, dur, vel=.2):
    d = dur + 1.2
    t = tt(d)
    x = np.zeros_like(t)
    B = .00035
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > 16000: break
        amp = (1 / k) ** 1.6
        dec = .9 + .55 * k + f / 900
        x += amp * np.exp(-t * dec) * np.sin(2 * np.pi * fk * t + _rng.uniform(0, 6))
    x *= env_adsr(len(t), .004, .35, dur)
    # 琴槌輕微敲擊聲
    nn = int(.012 * SR)
    x[:nn] += lp(_rng.standard_normal(nn), 2500) * np.linspace(.15, 0, nn)
    return x * vel

def pad(notes, dur, attack=.8, release=.8):
    d = dur + release
    t = tt(d)
    x = np.zeros_like(t)
    for m in notes:
        f = mtof(m)
        for det in (-7, 0, 7):
            fd = f * 2 ** (det / 1200)
            ph = _rng.uniform(0, 6)
            for h in range(1, int(min(14, 5000 / fd)) + 1):
                x += (1 / h) * np.sin(2 * np.pi * fd * h * t + ph * h) * (.9 ** h)
    x /= (len(notes) * 3 * 2.2)
    x = lp(x, 1600)
    e = np.ones_like(t)
    na = int(attack * SR); e[:na] = np.linspace(0, 1, na) ** 1.5
    nh = int(dur * SR); e[nh:] = np.linspace(1, 0, len(t) - nh) ** 2
    trem = 1 + .06 * np.sin(2 * np.pi * .25 * t)
    return x * e * trem

def bell(f, dur, vel=.1, decay=3.0, ratio=3.5):
    t = tt(dur + .5)
    I = 2.2 * np.exp(-t * 6)
    x = np.sin(2 * np.pi * f * t + I * np.sin(2 * np.pi * f * ratio * t))
    x *= np.exp(-t * decay)
    na = int(.002 * SR); x[:na] *= np.linspace(0, 1, na)
    return x * vel

def bass(f, dur, vel=.25):
    t = tt(dur + .15)
    x = np.sin(2 * np.pi * f * t) + .35 * np.sin(4 * np.pi * f * t) + .1 * np.sin(6 * np.pi * f * t)
    x = np.tanh(1.4 * x) / 1.1
    e = env_adsr(len(t), .01, .12, dur) * (0.75 + .25 * np.exp(-t * 3))
    return lp(x * e, 900) * vel

def kick():
    t = tt(.45)
    f = 48 + 90 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t * 7.5)
    n = int(.004 * SR); x[:n] += _rng.standard_normal(n) * .25
    return x

def hat():
    t = tt(.06)
    return hp(_rng.standard_normal(len(t)), 7500) * np.exp(-t * 70)

def clap():
    t = tt(.35)
    x = np.zeros_like(t)
    for off in (0, .011, .022):
        i = int(off * SR)
        x[i:] += np.exp(-(t[:len(t) - i]) * (60 if off < .02 else 16))
    return bp(_rng.standard_normal(len(t)), 900, 3200) * x * .6

def crash():
    t = tt(2.5)
    return hp(_rng.standard_normal(len(t)), 5000) * np.exp(-t * 1.8) * .5

def riser(d):
    t = tt(d)
    p = t / d
    n = _rng.standard_normal(len(t))
    # 以分段高通模擬掃頻
    x = np.zeros_like(t)
    segs = 12
    for s in range(segs):
        a, b = int(s * len(t) / segs), int((s + 1) * len(t) / segs)
        fc = 400 * (12 ** (s / segs))
        seg = bp(n, fc, min(fc * 3, 18000))
        w = np.zeros_like(t); w[a:b] = 1
        x += seg * w
    x = lp(x, 12000)
    sw = np.sin(2 * np.pi * np.cumsum(220 + 700 * p ** 2) / SR) * .25
    return (x * .6 + sw) * p ** 2.2

def impact():
    t = tt(2.0)
    f = 40 + 70 * np.exp(-t * 12)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    x += lp(_rng.standard_normal(len(t)), 600) * np.exp(-t * 6) * .5
    return x

def reverb(x, seconds=2.5, wet=.3):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    for c in range(2):
        ir = _rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        ir = lp(ir, 6000)
        ir[:int(.012 * SR)] = 0
        ir /= np.sqrt((ir ** 2).sum())
        out[:, c] = signal.oaconvolve(x[:, c], ir)[:len(x)]
    return out * wet

# ---------------- 音效 ----------------
def whoosh(d=.6, bright=1.0):
    t = tt(d)
    p = t / d
    e = np.sin(np.pi * p ** .8) ** 2
    n = _rng.standard_normal(len(t))
    x = np.zeros_like(t)
    segs = 10
    for s in range(segs):
        a, b = int(s * len(t) / segs), int((s + 1) * len(t) / segs)
        c = (np.sin(np.pi * (s + .5) / segs))
        fc = 300 + 2200 * c * bright
        w = np.zeros_like(t); w[a:b] = 1
        x += bp(n, fc * .6, fc * 1.6) * w
    x = lp(x, 5000) * e
    L = x * (1 - .6 * p); R = x * (.4 + .6 * p)
    return np.stack([L, R], 1)

def tick(f=2600, d=.03, v=1.0):
    t = tt(d)
    return (np.sin(2 * np.pi * f * t) * np.exp(-t * 180) + hp(_rng.standard_normal(len(t)), 4000) * np.exp(-t * 400) * .3) * v

def pop(f0=450, f1=950, d=.09):
    t = tt(d)
    f = f0 + (f1 - f0) * (1 - np.exp(-t * 60))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 45)

def chime(notes=(88, 95), gap=.06, decay=5.0):
    out = np.zeros(int((1.6 + gap * len(notes)) * SR))
    for j, n in enumerate(notes):
        x = bell(mtof(n), 1.4, vel=1, decay=decay, ratio=2.0) + .4 * np.sin(2 * np.pi * mtof(n) * tt(1.9)) * np.exp(-tt(1.9) * decay)
        i = int(j * gap * SR); out[i:i + len(x)] += x[:len(out) - i]
    return out / len(notes)

def notify():
    return chime((81, 88), gap=.11, decay=5)

def keytap():
    t = tt(.04)
    x = bp(_rng.standard_normal(len(t)), 1800, 5000) * np.exp(-t * 220)
    x += np.sin(2 * np.pi * 180 * t) * np.exp(-t * 120) * .5
    return x

def beep():
    t = tt(.12)
    x = np.sign(np.sin(2 * np.pi * 1760 * t)) * .5 + np.sin(2 * np.pi * 1760 * t) * .5
    x = lp(x, 5000)
    e = np.ones_like(t); e[-int(.02 * SR):] = np.linspace(1, 0, int(.02 * SR)); e[:48] = np.linspace(0, 1, 48)
    return x * e

def clack():
    t = tt(.3)
    x = hp(_rng.standard_normal(len(t)), 2500) * np.exp(-t * 300)
    x += np.sin(2 * np.pi * 130 * t) * np.exp(-t * 35) * .9
    i = int(.055 * SR)
    x[i:] += hp(_rng.standard_normal(len(t) - i), 3000) * np.exp(-t[:len(t) - i] * 350) * .7
    return x

def thud(f=85):
    t = tt(.35)
    x = np.sin(2 * np.pi * np.cumsum(f + 40 * np.exp(-t * 30)) / SR) * np.exp(-t * 16)
    x += lp(_rng.standard_normal(len(t)), 800) * np.exp(-t * 30) * .5
    return x

def shutter():
    t = tt(.25)
    x = np.zeros_like(t)
    for off, g in ((0, 1), (.075, .8)):
        i = int(off * SR)
        seg = bp(_rng.standard_normal(len(t) - i), 1500, 7000) * np.exp(-t[:len(t) - i] * 120) * g
        seg += np.sin(2 * np.pi * 900 * t[:len(t) - i]) * np.exp(-t[:len(t) - i] * 90) * .3 * g
        x[i:] += seg
    return x

def shimmer(d=1.0, n=10, lo=2000, hi=6500):
    out = np.zeros((int((d + .6) * SR), 2))
    for j in range(n):
        f = _rng.uniform(lo, hi)
        x = np.sin(2 * np.pi * f * tt(.6)) * np.exp(-tt(.6) * 9)
        i = int(_rng.uniform(0, d) * SR * (j / n) ** .5)
        pan = _rng.uniform(-.8, .8); a = (pan + 1) * np.pi / 4
        out[i:i + len(x), 0] += x * np.cos(a); out[i:i + len(x), 1] += x * np.sin(a)
    return out / 3

def coin():
    a = bell(mtof(95), .8, vel=1, decay=6, ratio=1.41)
    b = bell(mtof(100), 1.0, vel=1, decay=4, ratio=1.41)
    out = np.zeros(len(b) + int(.08 * SR)); out[:len(a)] += a; out[int(.08 * SR):] += b
    return out * .6

def alert():
    out = np.zeros(int(.5 * SR))
    for j, n in enumerate((81, 77)):
        t = tt(.16)
        x = lp(np.sign(np.sin(2 * np.pi * mtof(n) * t)), 2500) * np.exp(-t * 12)
        i = int(j * .15 * SR); out[i:i + len(x)] += x
    return out * .5

def sweep_up(d=.8):
    t = tt(d)
    f = 300 * (3 ** (t / d))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) ** 2
    return x

def typing(d, rate=14):
    out = np.zeros(int((d + .1) * SR))
    t = 0.0
    while t < d:
        x = tick(_rng.uniform(1800, 3000), .025, _rng.uniform(.5, 1))
        i = int(t * SR); out[i:i + len(x)] += x
        t += _rng.uniform(.6, 1.4) / rate
    return out

def roll(d, start_rate=30, end_rate=10):
    """數字跳動：越來越慢的 tick"""
    out = np.zeros(int((d + .1) * SR))
    t = 0.0
    while t < d:
        p = t / d
        x = tick(2200 + 900 * _rng.random(), .025, .8)
        i = int(t * SR); out[i:i + len(x)] += x
        t += 1 / (start_rate + (end_rate - start_rate) * p)
    return out

def hat_open():
    t = tt(.18)
    return hp(_rng.standard_normal(len(t)), 8000) * np.exp(-t * 22)

def shaker():
    t = tt(.07)
    e = np.minimum(1, t / .012) * np.exp(-t * 55)
    return bp(_rng.standard_normal(len(t)), 5000, 12000) * e
