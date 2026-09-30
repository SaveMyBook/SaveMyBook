"""精緻卡點音效（v3）：玻璃音、拇指琴、柔和空氣聲；所有有音高的音效都調到當下音樂的調性。
時間全部來自動畫原始碼推導的 cues.json。輸出 stems/sfx.npy"""
import json
import numpy as np
from synth import SR, TOTAL, Track, tt, lp, hp, bp, mtof, reverb, clack

D = json.load(open("cues.json", encoding="utf-8"))
PT = Track(TOTAL); AM = Track(TOTAL)       # 點狀音效（會觸發音樂讓位）／氛圍音效（咻聲等，不觸發）
send = Track(TOTAL)
AMB = {'door_close', 'swell', 'riser_short', 'bump', 'whoosh', 'process', 'slide', 'door_open', 'scan'}
import os
BOOST = json.load(open("cue_boost.json")) if os.path.exists("cue_boost.json") else {}
S = PT
rng = np.random.default_rng(5)

# ── 調性表（與 music.py 的段落一致）──
KEYS = [(0, 30.2, 64, "min"), (30.2, 53.7, 57, "min"), (53.7, 91.6, 62, "maj"), (91.6, 112.2, 64, "min"),
        (112.2, 117.8, 60, "maj"), (117.8, 142.1, 60, "min"), (142.1, 999, 57, "maj")]
PENT = {"maj": [0, 2, 4, 7, 9], "min": [0, 3, 5, 7, 10]}
TRIAD = {"maj": [0, 4, 7], "min": [0, 3, 7]}

def key_at(t):
    for a, b, tonic, mode in KEYS:
        if a <= t < b: return tonic, mode
    return 57, "maj"

def pn(t, i, octv=1):
    """當下調性五聲音階的第 i 個音（可超過 5 自動升八度）"""
    tonic, mode = key_at(t)
    sc = PENT[mode]; i = int(round(i))
    return tonic + 12 * octv + sc[i % 5] + 12 * (i // 5)

def put(t, x, g, pan=0, verb=.3):
    globals()['S'].add(t, x * g, pan); send.add(t, x * g * verb, pan)

# ── 音色 ──
def glass(m, d=.6, bright=1.0):
    t = tt(d); f = mtof(m)
    x = np.sin(2 * np.pi * f * t) + .25 * bright * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 6) + .12 * bright * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 10)
    return x * np.exp(-t * (4.5 + f / 900)) * np.minimum(1, t / .003)

def kalimba(m, d=.7):
    t = tt(d); f = mtof(m)
    x = np.sin(2 * np.pi * f * t) + .35 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 25) + .08 * np.sin(2 * np.pi * f * 2 * t)
    return x * np.exp(-t * 6) * np.minimum(1, t / .002)

def bubble(m, d=.12):
    t = tt(d); f1 = mtof(m)
    f = f1 * (.55 + .45 * (1 - np.exp(-t * 90)))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 30) * np.minimum(1, t / .002)

def soft_click(bright=4500, d=.02):
    t = tt(d)
    return lp(hp(rng.standard_normal(len(t)), 1200), bright) * np.exp(-t * 350) + np.sin(2 * np.pi * 1900 * t) * np.exp(-t * 200) * .3

def air(d, ease="inout", bright=1.0):
    """柔和空氣聲；包絡依動畫緩動曲線：inout 中段最大、emph 前段最大、in 尾段最大"""
    t = tt(d); p = t / d
    if ease == "emph":  e = (1 - p) ** 2 * np.minimum(1, p / .08)
    elif ease == "in":  e = p ** 2 * np.minimum(1, (1 - p) / .1)
    else:               e = np.sin(np.pi * p) ** 2
    n = rng.standard_normal(len(t))
    pink = lp(n, 900 * bright) + .35 * bp(n, 900 * bright, 3200 * bright)
    x = hp(pink, 120) * e
    pan_ = np.linspace(-.5, .5, len(t))
    return np.stack([x * (1 - pan_) * .8, x * (1 + pan_) * .8], 1)

def gliss(m0, m1, d, vib=True):
    """畫線：跟著線條長出來的滑音"""
    t = tt(d); p = t / d
    mm = m0 + (m1 - m0) * (1 - (1 - p) ** 2)
    f = 440 * 2 ** ((mm - 69) / 12) * (1 + (.004 * np.sin(2 * np.pi * 6 * t) if vib else 0))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + .2 * np.sin(2 * ph)
    return x * np.sin(np.pi * p) ** 1.2

def bloom(d=1.6):
    t = tt(d)
    x = np.sin(2 * np.pi * np.cumsum(55 + 25 * np.exp(-t * 4)) / SR) * np.exp(-t * 2.2) * np.minimum(1, t / .02)
    x += lp(rng.standard_normal(len(t)), 700) * np.exp(-t * 5) * .3
    return x

def sparkle(t0, n=6, g=.04, octv=2, spread=.35, pan=0):
    for k in range(n):
        put(t0 + spread * k / n, glass(pn(t0, rng.integers(0, 5), octv), .5), g * (1 - .5 * k / n), pan + rng.uniform(-.5, .5), .6)

def thud_soft(f=90, d=.25):
    t = tt(d)
    return np.sin(2 * np.pi * np.cumsum(f + 50 * np.exp(-t * 35)) / SR) * np.exp(-t * 18) + lp(rng.standard_normal(len(t)), 600) * np.exp(-t * 40) * .3

# 依重要程度微調（dB）：重點時刻放大、背景細節收小
ADJ = {"slam": 10, "book": 8, "tap": 6, "key": 6, "whoosh": 18, "coin_fly": 6, "door_close": 20, "swell": 20,
       "riser_short": 10, "clock": 3, "coin_s": -6, "box": -6, "coin_land": -3, "beep": -3, "success": -3,
       "power": -5, "notify": -2, "flag": -5, "lock": -4, "ring": -5, "pin": -2, "block": -2, "sparkle": -3,
       "bump": 14, "card": 14, "swipe": 12, "check": -3, "process": 7, "typing": 6, "tick": 4, "sprinkle": 6, "glint": 4}
roll_i = 0
for ci, c in enumerate(D["cues"]):
    ty, t, g, pan = c["type"], c["t"], c["gain"], c["pan"]
    g *= 10 ** ((ADJ.get(ty, 0) + BOOST.get(str(ci), 0)) / 20)
    S = AM if ty in AMB else PT
    dur = c.get("dur", .5)
    if ty == "whoosh":
        d = float(np.clip(dur, .25, 1.8)); ease = c.get("ease", "inout")
        start = t if ease != "inout" else t + dur / 2 - d / 2
        put(start, air(d, ease, 1.0 if d < .8 else .7), .07 * g, 0, .1)
    elif ty == "textin":    put(t - .02, air(.35, "emph", 1.4), .03 * g); put(t + .05, glass(pn(t, 4, 2), .8), .02 * g, 0, .6)
    elif ty == "pop":       put(t, bubble(pn(t, rng.integers(1, 5), 1)), .08 * g, pan, .3)
    elif ty == "roll":
        k = 0.0; j = 0
        while k < dur:
            put(t + k, soft_click(3500), .05 * g, pan, .1); j += 1
            k += 1 / (30 - 22 * (k / dur) ** .7)          # 先快後慢，貼合 emph 緩動
    elif ty == "land":      put(t, soft_click(5000), .07 * g, pan); put(t, glass(pn(t, 2 + roll_i % 3, 2), .5), .035 * g, pan, .5); roll_i += 1
    elif ty == "riser_short": put(t, gliss(pn(t, 0, 0), pn(t, 0, 1), dur) * .5, .04 * g, 0, .6)
    elif ty == "line":
        d = max(dur, .2)
        put(t, gliss(pn(t, 0, 1), pn(t, 4, 1), d), .022 * g, pan, .6)
    elif ty == "impact":    put(t, bloom(), .16 * g, 0, .5); [put(t + j * .02, glass(pn(t, i, 1), 2.0, .6), .04 * g, -.3 + .3 * j, .6) for j, i in enumerate((0, 2, 3))]
    elif ty == "shimmer":   sparkle(t, 8, .035 * g, 2, .5)
    elif ty == "type":      put(t, kalimba(pn(t, int(round((t - int(t)) * 20)) % 5 + 3, 1), .4), .04 * g, pan, .4)
    elif ty == "tick":      put(t, soft_click(4000), .06 * g, pan)
    elif ty == "dot":       put(t, glass(pn(t, 3, 2), .3), .03 * g, pan)
    elif ty == "build":     put(t - .1, air(.5, "inout", .6), .06 * g); put(t + .1, bloom(1.0), .08 * g)
    elif ty == "power":     put(t, glass(pn(t, 0, 1), .4), .05 * g, pan); put(t + .09, glass(pn(t, 3, 1), .6), .05 * g, pan, .5)
    elif ty == "glint":     sparkle(t, 3, .02 * g, 3, .25, pan)
    elif ty == "scan":      put(t, gliss(pn(t, 0, 2), pn(t, 4, 2), dur, vib=False) * .5, .012 * g, pan, .4)
    elif ty == "beep":      put(t, glass(pn(t, 4, 2), .25, .5), .06 * g, pan); put(t + .09, glass(pn(t, 4, 2), .35, .5), .06 * g, pan)
    elif ty == "ring":      put(t, glass(pn(t, 0, 1), 1.2, .3), .03 * g, pan, .8)
    elif ty == "success":
        for j, i in enumerate((0, 2, 5)): put(t + j * .07, kalimba(pn(t, i, 1), .9), .07 * g, pan, .5)
    elif ty == "swap":      put(t, soft_click(3000), .04 * g, pan)
    elif ty in ("tap", "key"): put(t, soft_click(3800, .025), .12 * g, pan); put(t, thud_soft(200, .06), .03 * g, pan)
    elif ty == "zip":       put(t, gliss(pn(t, 2, 2), pn(t, 5, 2), min(dur, .4), vib=False) * .6, .018 * g, pan, .5)
    elif ty == "digital":   put(t, glass(pn(t, 1, 2), .2, .4), .04 * g, pan); put(t + .06, glass(pn(t, 3, 2), .3, .4), .04 * g, pan)
    elif ty == "lift":      put(t, gliss(pn(t, 0, 1), pn(t, 3, 1), .3), .03 * g, pan)
    elif ty == "process":
        k = 0.0
        while k < dur: put(t + k, soft_click(2500), .02 * g, pan); k += 1 / 10
    elif ty == "unlock":    put(t, lp(clack(), 6000), .17 * g, pan)
    elif ty == "door_open": put(t, air(dur, "emph", .5), .06 * g, pan)
    elif ty == "bump":      put(t, thud_soft(100), .05 * g, pan)
    elif ty == "clock":     put(t, soft_click(2600, .03), .07 * g, pan); put(t, glass(pn(t, 0, 2), .15, .2), .012 * g, pan)
    elif ty == "book":      put(t, thud_soft(110), .13 * g, pan); put(t, lp(hp(rng.standard_normal(4000), 800), 3000) * np.exp(-np.arange(4000) / 700), .03 * g, pan)
    elif ty == "slide":     put(t, air(dur, "emph", .5), .03 * g, pan)
    elif ty == "door_close": put(t, air(dur, "in", .5), .06 * g, pan)
    elif ty == "slam":      put(t, thud_soft(80, .3), .15 * g, pan); put(t + .01, lp(clack(), 5000), .07 * g, pan)
    elif ty == "lock":      put(t, soft_click(5000), .06 * g, pan); put(t + .05, soft_click(4000), .05 * g, pan)
    elif ty == "notify":    put(t, kalimba(pn(t, 4, 1), .6), .09 * g, pan, .5); put(t + .11, kalimba(pn(t, 7, 1), .8), .09 * g, pan, .5)
    elif ty == "core":      put(t, bloom(1.8), .10 * g, 0, .6); sparkle(t + .1, 10, .03 * g, 2, .8)
    elif ty == "node":      put(t, kalimba(pn(t, c["i"], 1), .8), .06 * g, pan, .5)
    elif ty == "shutter":   put(t, soft_click(6000, .02), .12 * g, pan); put(t + .07, soft_click(4500, .02), .09 * g, pan); put(t, air(.18, "emph", 1.2), .03 * g, pan)
    elif ty == "box":       put(t, glass(pn(t, 3, 2), .3, .5), .03 * g, pan)
    elif ty == "sheet":     put(t, air(.35, "emph", 1.1), .045 * g, pan)
    elif ty == "coin_s":    put(t, glass(pn(t, 4, 2), .5), .035 * g, pan, .4)
    elif ty == "check":     put(t, kalimba(pn(t, 5, 1), .5), .05 * g, pan, .4)
    elif ty == "select":    put(t, glass(pn(t, 2, 2), .25), .04 * g, pan); put(t + .06, glass(pn(t, 4, 2), .4), .04 * g, pan, .4)
    elif ty == "sweep":     put(t, gliss(pn(t, 0, 1), pn(t, 4, 1), dur), .02 * g, pan)
    elif ty == "sparkle":   sparkle(t, 5, .03 * g, 2, .3, pan)
    elif ty == "fill":      put(t, soft_click(3500), .05 * g, pan); put(t, glass(pn(t, 1 + int(t * 3.6) % 4, 2), .25, .3), .018 * g, pan)
    elif ty == "sprinkle":
        for k in range(14): put(t + dur * k / 14, glass(pn(t, rng.integers(0, 5), 3), .25, .3), .01 * g, rng.uniform(-.7, .7), .6)
    elif ty == "sonar":     put(t, glass(pn(t, 0, 1), 1.3, .3), .035 * g, pan, .8)
    elif ty == "typing":
        n = c.get("n", 20)
        for k in range(n): put(t + dur * k / n + rng.uniform(-.012, .012), soft_click(rng.uniform(3000, 4500), .018), .05 * g, pan)
    elif ty == "send":      put(t - .03, air(.2, "in", 1.3), .04 * g, pan); put(t + .03, bubble(pn(t, 4, 1)), .07 * g, pan)
    elif ty == "swipe":     put(t, air(.25, "inout", 1.3), .025 * g, pan)
    elif ty == "bubble":    put(t, bubble(pn(t, 2, 1)), .08 * g, pan)
    elif ty == "card":      put(t, air(.18, "emph", 1.2), .03 * g, pan)
    elif ty == "warn_pop":  put(t, glass(pn(t, 1, 1), .5, .4), .05 * g, pan); put(t + .08, glass(pn(t, 0, 1), .6, .4), .05 * g, pan)
    elif ty == "coin_up":   put(t, bubble(pn(t, 4, 1)), .05 * g, pan)
    elif ty == "coin_fly":  put(t, gliss(pn(t, 0, 2), pn(t, 4, 2), dur) * .5, .02 * g, pan); put(t, air(dur, "inout", 1.1), .035 * g, pan)
    elif ty == "coin_land": put(t, glass(pn(t, 4, 2), .7, 1.2), .06 * g, pan, .5)
    elif ty == "cash":
        for j, i in enumerate((4, 7)): put(t + j * .08, glass(pn(t, i, 2), .9, 1.3), .07 * g, pan, .5)
    elif ty == "pin":       put(t, soft_click(4000, .02), .09 * g, pan); put(t, glass(pn(t, c["i"], 1), .2, .3), .025 * g, pan)
    elif ty == "flag":      put(t, glass(pn(t, 0, 1) + 1, .25, .6), .03 * g, pan)
    elif ty == "alert":     put(t, glass(pn(t, 2, 1), .4, .6), .05 * g, pan); put(t + .14, glass(pn(t, 0, 1), .5, .6), .05 * g, pan)
    elif ty == "banner":    put(t - .03, air(.25, "emph", 1.0), .035 * g, pan); put(t, glass(pn(t, 0, 0) + 1, .6, .5), .03 * g, pan)
    elif ty == "block":     put(t, kalimba(pn(t, c["i"], 1), .6), .06 * g, pan, .4); put(t, thud_soft(120, .12), .04 * g, pan)
    elif ty == "grow":      put(t, gliss(pn(t, 0, 1), pn(t, 3 + c.get("up", 1), 1), dur), .025 * g, pan)
    elif ty == "swell":     put(t, air(dur, "in", .6), .06 * g, pan, .5)
    elif ty == "final":     sparkle(t, 12, .035 * g, 2, 1.0)
    else: raise ValueError(ty)

rv = reverb(send.buf, 1.6, .5)
np.save("stems/sfx_point.npy", (PT.buf + rv).astype(np.float32))
np.save("stems/sfx_amb.npy", AM.buf.astype(np.float32))
out = PT.buf + AM.buf + rv
np.save("stems/sfx.npy", out.astype(np.float32))
print("sfx peak", np.abs(out).max(), "cues", len(D["cues"]))
