"""MIXPOP 用的額外音色"""
import numpy as np
from synth import SR, tt, lp, hp, bp, mtof, _rng, bell, crash

def saw(f, n, ph0=None):
    """polyBLEP 抗鋸齒鋸齒波；f 可為常數或逐樣本陣列"""
    f = np.broadcast_to(np.asarray(f, float), (n,))
    dt = f / SR
    ph = ((_rng.random() if ph0 is None else ph0) + np.cumsum(dt) - dt[0]) % 1.0
    y = 2 * ph - 1
    m = ph < dt
    x = ph[m] / dt[m]; y[m] -= x + x - x * x - 1
    m = ph > 1 - dt
    x = (ph[m] - 1) / dt[m]; y[m] -= x * x + x + x + 1
    return y

def blend_filter(x, lo, hi, env):
    """以包絡在暗／亮兩個濾波版本間混合，模擬濾波器包絡"""
    d = lp(x, lo); b = lp(x, hi)
    return d + env * (b - d)

def brass(notes, dur, vel=.2):
    d = dur + .12
    t = tt(d); n = len(t)
    x = np.zeros(n)
    scoop = 2 ** ((-1.2 * np.exp(-t * 45)) / 12)
    for m in notes:
        f = mtof(m) * scoop
        for c in (-9, 0, 9):
            x += saw(f * 2 ** (c / 1200), n)
    x /= len(notes) * 3
    env_f = np.exp(-t * 9) * .85 + .15
    y = blend_filter(x, 600, 5200, env_f)
    amp = np.minimum(1, t / .006) * np.where(t < dur, 1, np.exp(-(t - dur) * 40)) * (0.75 + .25 * np.exp(-t * 6))
    return np.tanh(y * amp * 1.8) * vel

def supersaw(notes, dur, vel=.12, cutoff=4200, attack=.02, release=.25):
    d = dur + release
    t = tt(d); n = len(t)
    x = np.zeros(n)
    for m in notes:
        for c in (-28, -17, -8, 0, 8, 17, 28):
            x += saw(mtof(m) * 2 ** (c / 1200), n)
    x /= len(notes) * 7 / 2.2
    x = lp(x, cutoff)
    amp = np.minimum(1, t / attack) * np.where(t < dur, 1, np.exp(-(t - dur) / release * 4))
    return x * amp * vel

def sub808(m, dur, vel=.5, glide_from=None, drive=2.2):
    t = tt(dur + .05); n = len(t)
    f0 = mtof(m)
    f = f0 * (1 + .9 * np.exp(-t * 55))
    if glide_from is not None:
        g = mtof(glide_from)
        f = f0 + (g - f0) * np.exp(-t * 18)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    amp = np.minimum(1, t / .003) * np.exp(-t / max(dur * .7, .12)) * np.where(t < dur, 1, np.exp(-(t - dur) * 60))
    y = np.tanh(drive * x * amp) / np.tanh(drive)
    return lp(y, 2500) * vel

def kick_hard():
    t = tt(.5)
    f = 46 + 150 * np.exp(-t * 38)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    x = np.tanh(x * 1.6)
    k = int(.006 * SR); x[:k] += hp(_rng.standard_normal(k), 2000) * np.linspace(.6, 0, k)
    return x

def snare(tone=190, bright=1.0):
    t = tt(.32)
    x = np.sin(2 * np.pi * tone * t) * np.exp(-t * 20) * .6
    x += bp(_rng.standard_normal(len(t)), 1400, 9000) * np.exp(-t * 17) * bright
    return x * .8

def trap_hat(open_=False):
    t = tt(.2 if open_ else .035)
    return hp(_rng.standard_normal(len(t)), 8500) * np.exp(-t * (14 if open_ else 110))

def rim():
    t = tt(.06)
    return (bp(_rng.standard_normal(len(t)), 1500, 5000) * np.exp(-t * 120) + np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 90) * .5)

def squeak():
    """jersey club 招牌的床墊彈簧聲"""
    t = tt(.12)
    f = 1500 + 1300 * np.sin(np.pi * t / .12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / .12) ** 2 * .5

def reese(m, dur, vel=.2):
    t = tt(dur + .05); n = len(t)
    f = mtof(m)
    x = saw(f * 2 ** (-14 / 1200), n) + saw(f * 2 ** (14 / 1200), n) + .6 * np.sin(2 * np.pi * f / 2 * t)
    lfo = .5 + .5 * np.sin(2 * np.pi * .7 * t)
    y = blend_filter(x, 280, 1100, lfo)
    amp = np.minimum(1, t / .01) * np.where(t < dur, 1, np.exp(-(t - dur) * 50))
    return np.tanh(y * amp * 1.3) * vel

def pluck(m, dur=.25, vel=.1):
    t = tt(dur + .2); n = len(t)
    x = saw(mtof(m), n) + .5 * saw(mtof(m) * 2.003, n)
    y = blend_filter(x, 500, 6000, np.exp(-t * 22))
    return y * np.exp(-t * 7) * np.minimum(1, t / .002) * vel

FORMANTS = {"a": (800, 1150, 2900), "o": (480, 850, 2800), "e": (420, 2050, 2650), "u": (350, 700, 2500)}
def vox(m, dur, vel=.12, vowel="a", vib=True):
    t = tt(dur + .08); n = len(t)
    f = mtof(m) * (1 + (.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / .2) if vib else 0))
    src = saw(f, n) + .3 * _rng.standard_normal(n) * .05
    F = FORMANTS[vowel]
    y = sum(bp(src, fc * .85, fc * 1.15) * g for fc, g in zip(F, (1, .6, .25)))
    amp = np.minimum(1, t / .012) * np.where(t < dur, 1, np.exp(-(t - dur) * 45))
    return y * amp * vel * 2.2

def musicbox(m, dur=1.5, vel=.1):
    t = tt(dur)
    x = bell(mtof(m), dur, vel=1, decay=2.6, ratio=3.5)[:len(t)] + .3 * np.sin(2 * np.pi * mtof(m) * 2 * t) * np.exp(-t * 5)
    return x[:len(t)] * vel

def rev_crash(d=1.5):
    x = crash()[:int(d * SR)][::-1]
    return x * np.linspace(0, 1, len(x)) ** 2

def downlifter(d=1.0):
    t = tt(d)
    f = 1200 * np.exp(-t * 3) + 60
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * .4 + lp(_rng.standard_normal(len(t)), 3000) * .3) * np.exp(-t * 2.5)

def tape_stop(buf, i0, i1):
    """把 buf[i0:i1] 做成唱盤停轉（越來越慢、音高下降），之後靜音"""
    n = i1 - i0
    speed = np.linspace(1, 0, n) ** 1.6
    pos = i0 + np.cumsum(speed)
    idx = np.clip(pos, 0, len(buf) - 2)
    a = idx.astype(int); fr = (idx - a)[:, None]
    seg = buf[a] * (1 - fr) + buf[a + 1] * fr
    buf[i0:i1] = seg * np.linspace(1, .3, n)[:, None]
    buf[i1:] = 0

def stutter(buf, i0, i1, slice_len):
    """把 i0 開始的一小段重複到 i1（glitch）"""
    s = buf[i0:i0 + slice_len].copy()
    k = i0
    j = 0
    while k < i1:
        m = min(slice_len, i1 - k)
        g = .9 ** j
        buf[k:k + m] = s[:m] * g
        k += m; j += 1
    buf[i1:] = 0

def mx(*xs):
    """把長度不同的訊號相加"""
    out = np.zeros(max(len(x) for x in xs))
    for x in xs: out[:len(x)] += x
    return out

def vox_shout(m=64, vel=.2):
    """合唱式「嘿！」喊聲：多聲部 e 母音、音高快速下滑"""
    d = .26
    t = tt(d); n = len(t)
    y = np.zeros(n)
    for k, det in enumerate((-18, -6, 5, 16)):
        f = mtof(m + (12 if k == 3 else 0)) * 2 ** (det / 1200) * (1 + .25 * np.exp(-t * 18))
        src = saw(f, n) + _rng.standard_normal(n) * .25
        F = FORMANTS["e"]
        y += sum(bp(src, fc * .85, fc * 1.15) * g for fc, g in zip(F, (1, .7, .35)))
    amp = np.minimum(1, t / .008) * np.exp(-t * 9)
    return np.tanh(y * amp * 1.5) * vel

def choir(notes, dur, vel=.1, vowel="a"):
    """人聲和聲墊：每個音兩聲部、帶顫音"""
    out = None
    for m in notes:
        for det in (-7, 7):
            x = vox(m + det / 100, dur, vel / len(notes), vowel)
            out = x if out is None else mx(out, x)
    t = np.arange(len(out)) / SR
    return out * np.minimum(1, t / (dur * .5))

def scratch(d=.35):
    """刮盤聲"""
    t = tt(d)
    pos = np.sin(2 * np.pi * (1 / d) * 1.5 * t) ** 2
    f = 200 + 1800 * np.abs(np.gradient(pos)) * SR / 60
    src = saw(np.clip(f, 60, 4000), len(t)) * .6 + _rng.standard_normal(len(t)) * .3
    return bp(src, 300, 5000) * np.sin(np.pi * t / d) ** .5 * .5
