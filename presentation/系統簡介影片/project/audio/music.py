"""原創配樂（MIXPOP 風格）：一首歌裡切換多種曲風，每次切換都對準動畫的換場點。
輸出 stems/music.npy"""
import json
import numpy as np
from synth import *
from inst import *

TL = json.load(open("../src/timeline.json", encoding="utf-8"))
# 系統簡介影片：把介紹動畫的段落名稱對應到新的段落，曲風切換點對準新片的章節換場
_NEW = {x["id"]: x["start"] for x in TL["sections"]}
_L = {x["id"]: _NEW[x["sec"]] + x["at"] for x in TL["lines"]}
SEC = {"intro": 0.0, "list": _NEW["overview"], "deal": _NEW["find"], "pay": _NEW["pay"], "deposit": _NEW["cabinet"],
       "transit": _L["16"] - 0.3, "pickup": _NEW["after"], "after": _L["18"] - 0.4, "gov": _NEW["account"], "system": _NEW["tech"], "end": _NEW["end"]}
LINE = dict(_L, end2=_L["25"] + 3.0)
COLD_END = _L["03"] - 0.3
# 曲風切換點：對準畫面的換場（AI 段內的時間取自 src/scenes/ai.ts 的節拍）
A = SEC["after"]
T = dict(
    cold=(0.0, COLD_END), brass=(COLD_END, SEC["list"]), fb=(SEC["list"], SEC["deal"]), jersey=(SEC["deal"], SEC["pay"]),
    secure=(SEC["pay"], SEC["deposit"]), dnb=(SEC["deposit"], SEC["transit"]), transit=(SEC["transit"], SEC["pickup"]),
    ai_break=(SEC["pickup"], SEC["after"]), fb2=(A, SEC["gov"]), gov=(SEC["gov"], SEC["system"]),
    climax=(SEC["system"], SEC["end"]), outro=(SEC["end"], TOTAL),
)
N = int(TOTAL * SR) + 1
master = np.zeros((N, 2))
send = np.zeros((N, 2))
SECTION_LOG = []

class Sec:
    """一個曲風段落：自己的速度、小節格線、緩衝區與 pumping"""
    def __init__(self, name, t0, t1, bpm_hint, level=1.0, beats_per_bar=4):
        self.name, self.t0, self.t1, self.level = name, t0, t1, level
        L = t1 - t0
        bar_hint = beats_per_bar * 60 / bpm_hint
        self.bars = max(1, round(L / bar_hint))
        self.bar = L / self.bars
        self.beat = self.bar / beats_per_bar
        self.step = self.beat / 4          # 16 分音符
        self.bpm = 60 / self.beat
        n = int((L + 4) * SR)
        self.bed = np.zeros((n, 2)); self.dry = np.zeros((n, 2)); self.snd = np.zeros((n, 2))
        self.kicks = []
        SECTION_LOG.append((name, round(t0, 3), round(t1, 3), self.bars, round(self.bpm, 1)))

    def _add(self, buf, t, x, pan):
        if x.ndim == 1:
            a = (pan + 1) * np.pi / 4
            x = np.stack([x * np.cos(a), x * np.sin(a)], 1) * np.sqrt(2)
        i = int(round(t * SR))
        if i < 0: x, i = x[-i:], 0
        m = min(len(x), len(buf) - i)
        if m > 0: buf[i:i + m] += x[:m]

    # t 為段落內的相對秒數
    def bed_(self, t, x, pan=0, verb=0): self._add(self.bed, t, x, pan); verb and self._add(self.snd, t, x * verb, pan)
    def dry_(self, t, x, pan=0, verb=0): self._add(self.dry, t, x, pan); verb and self._add(self.snd, t, x * verb, pan)
    def at(self, bar, step=0): return bar * self.bar + step * self.step
    def kick(self, t, x, g=.5): self.dry_(t, x * g); self.kicks.append(t)

    def finish(self, end_fx=None, pump=.55, fade_in=0.0):
        n = len(self.bed)
        if self.kicks and pump:
            env = np.ones(n); Lp = int(min(.3, self.beat * .8) * SR)
            shape = 1 - pump * (1 - np.linspace(0, 1, Lp)) ** 2
            for t in self.kicks:
                i = int(t * SR); m = min(Lp, n - i)
                if m > 0: env[i:i + m] = np.minimum(env[i:i + m], shape[:m])
            self.bed *= env[:, None]
        mix = self.bed + self.dry
        Ls = int((self.t1 - self.t0) * SR)
        # 段落本身的音量：以中高頻 RMS 對齊，再乘上段落強度
        body = hp(mix[:Ls].mean(1), 150, 2)
        r = np.sqrt(np.mean(body ** 2)) + 1e-9
        g = .05 * self.level / r
        mix *= g; snd = self.snd * g
        if fade_in:
            k = int(fade_in * SR); mix[:k] *= np.linspace(0, 1, k)[:, None]
        if end_fx:
            end_fx(mix, snd, Ls)
        i0 = int(self.t0 * SR)
        m = min(len(mix), N - i0)
        master[i0:i0 + m] += mix[:m]; send[i0:i0 + m] += snd[:m]

def chord_notes(root, kind):
    iv = {"m": [0, 3, 7], "M": [0, 4, 7], "m7": [0, 3, 7, 10], "M7": [0, 4, 7, 11], "7": [0, 4, 7, 10], "sus": [0, 5, 7], "add9": [0, 4, 7, 14]}[kind]
    return [root + i for i in iv]

def cut_tail(mix, snd, Ls, fade=.03):
    k = int(fade * SR); mix[Ls - k:Ls] *= np.linspace(1, 0, k)[:, None]; mix[Ls:] = 0

def tape(mix, snd, Ls, d=.5):
    tape_stop(mix, Ls - int(d * SR), Ls)

def glitch(mix, snd, Ls, d=.42, sl=.0525):
    stutter(mix, Ls - int(d * SR), Ls, int(sl * SR))

# ════════════════ 1. 冷開場：第一拍就爆（E 小調 Trap）0 → 13.7 ════════════════
SIG_MIN = [(0, 1.2, 0), (3, 1.2, 0), (6, 2, 3), (10, 1.2, 5), (12, 3, 7)]      # 招牌 hook（原創）
SIG_ANS = [(0, 1.2, 10), (2, 1.2, 7), (4, 2, 5), (8, 3, 3)]                     # 回應句
S = Sec("intro_coldopen", *T["cold"], 96, level=.6)
prog = [(40, "m"), (36, "M"), (33, "m"), (35, "M")]   # Em C Am B
for b in range(S.bars):
    root, kd = prog[b % 4]
    notes = chord_notes(root + 24, kd)
    S.bed_(S.at(b), pad(notes, S.bar + .2, attack=.4, release=.6) * .09, verb=.6)
    for st in range(0, 16, 2):
        n = notes[(st // 2) % len(notes)] + 12
        S.bed_(S.at(b, st), pluck(n, .5, .035), pan=-.3 + .6 * ((st // 2) % 2), verb=.4)
    if b >= 2:
        S.kick(S.at(b, 0), kick_hard(), .28)
        S.dry_(S.at(b, 8), rim() * .1, pan=-.2)
    if b == S.bars - 1:
        S.dry_(S.at(b) - S.bar * .3, riser(S.bar * 1.3) * .14)
S.finish(fade_in=.6, end_fx=lambda m, s, L: cut_tail(m, s, L), pump=.2)

# ════════════════ 2. Girl-crush 銅管 Hip-hop（E 小調）13.7 → 30.2 ════════════════
def brass_pop(name, t0, t1, level=1.0):
  global S
  S = Sec(name, t0, t1, 116, level=level)
  prog = [(40, "m"), (38, "M"), (36, "M"), (35, "7")]   # Em D C B7
  hook = [0, 3, 6, 10, 12]
  for b in range(S.bars):
      root, kd = prog[b % 4]
      notes = chord_notes(root + 24, kd)
      top = [notes[-1] + 12, notes[-1] + 12, notes[-2] + 12, notes[-1] + 12, notes[0] + 24]
      for j, s in enumerate(hook):
          dur = S.step * (2 if j in (2, 4) else 1.2)
          S.dry_(S.at(b, s), brass(notes + [top[j]], dur, .20), verb=.25)
      S.kick(S.at(b, 0), kick_hard(), .55); S.kick(S.at(b, 6), kick_hard(), .42); S.kick(S.at(b, 8), kick_hard(), .5)
      for s in (4, 12):
          S.dry_(S.at(b, s), mx(snare(), clap() * 1.2) * .45, verb=.3)
      for s in range(0, 16, 2): S.dry_(S.at(b, s), trap_hat() * (.13 if s % 4 == 2 else .08), pan=.25)
      if b % 2 == 1:
          for k in range(4): S.dry_(S.at(b, 14) + k * S.step / 2, trap_hat() * .08, pan=.25)
      S.dry_(S.at(b, 0), sub808(root, S.beat * 1.4, .55))
      S.dry_(S.at(b, 8), sub808(root, S.beat * 1.4, .5, glide_from=root + 7 if b % 2 else None))
      S.bed_(S.at(b), pad(notes, S.bar + .1, attack=.05, release=.2) * .06)
  S.dry_(0, impact() * .6, verb=.5); S.dry_(0, crash() * .25)
  S.finish(end_fx=lambda m, s, L: tape(m, s, L, .5), pump=.5)
brass_pop("brass_pop", *T["brass"])
brass_pop("transit_brass", *T["transit"], level=.9)

# ════════════════ 3. Jersey Club（A 小調）30.2 → 53.7 ════════════════
S = Sec("jersey_club", *T["jersey"], 143, level=.95)
prog = [(45, "m"), (41, "M"), (43, "M"), (40, "m")]   # Am F G Em
for b in range(S.bars):
    root, kd = prog[b % 4]
    notes = chord_notes(root + 12, kd)
    for s in (0, 3, 6, 10, 12):
        S.kick(S.at(b, s), kick_hard(), .5 if s in (0, 6, 12) else .38)
    for s in (4, 12): S.dry_(S.at(b, s), clap() * .5, verb=.2)
    for s in range(2, 16, 4): S.dry_(S.at(b, s), trap_hat(open_=True) * .07, pan=.3)
    if b % 2 == 1: S.dry_(S.at(b, 14), squeak() * .5, pan=-.4)
    # 撥弦和弦反拍
    for s in (2, 6, 10, 14):
        for n in notes: S.bed_(S.at(b, s), pluck(n + 12, .16, .045), pan=-.2, verb=.3)
    # vox 切片
    vs = [(0, notes[2] + 12, 'a'), (3, notes[1] + 12, 'o'), (7, notes[2] + 12, 'a'), (11, notes[0] + 24, 'e')]
    if b >= 2:
        for s, n, v in vs: S.bed_(S.at(b, s), vox(n, S.step * 1.6, .07, v, vib=False), pan=.3, verb=.4)
    for s in (0, 6, 12): S.dry_(S.at(b, s), sub808(root, S.step * 2.5, .45))
S.finish(end_fx=lambda m, s, L: glitch(m, s, L, .42, S.step * .5), pump=.45)

# ════════════════ 4. AI 前導：空靈（D 大調）53.7 → 61.6 ════════════════
S = Sec("ai_break", *T["ai_break"], 122, level=.6)
prog = [(50, "M7"), (47, "m7"), (43, "M7"), (45, "sus")]   # Dmaj7 Bm7 Gmaj7 Asus
for b in range(S.bars):
    root, kd = prog[b % 4]
    notes = chord_notes(root + 12, kd)
    S.bed_(S.at(b), supersaw(notes, S.bar, .05, cutoff=1400 + 700 * b, attack=.4, release=.6), verb=.6)
    for s in range(0, 16, 2):
        n = notes[(s // 2) % len(notes)] + 24
        S.bed_(S.at(b, s), bell(mtof(n), .5, vel=.05, decay=6, ratio=2.0), pan=np.sin(s) * .6, verb=.8)
    S.bed_(S.at(b, 0), vox(notes[1] + 12, S.bar * .9, .05, 'o'), pan=0, verb=.8)
lb = S.bars - 1
for k in range(8): S.dry_(S.at(lb, 8) + k * S.step, snare(230) * (.1 + .35 * k / 8), verb=.3)
S.dry_(S.at(lb - 1, 8), riser(S.bar * 1.5) * .2)
S.finish(fade_in=.4, end_fx=lambda m, s, L: cut_tail(m, s, L), pump=0)

# ════════════════ 5. Future Bass（D 大調）61.6 → 91.6 ════════════════
def future_bass(name, t0, t1, level=.9):
  global S
  S = Sec(name, t0, t1, 152, level=level)
  prog = [(47, "m7"), (43, "M7"), (50, "add9"), (45, "sus")]    # Bm7 Gmaj7 Dadd9 Asus
  for b in range(S.bars):
      root, kd = prog[b % 4]
      notes = chord_notes(root + 12, kd)
      full = b >= 4
      # 半拍速：kick 1、snare 3
      S.kick(S.at(b, 0), kick_hard(), .5)
      if full: S.kick(S.at(b, 11), kick_hard(), .35)
      S.dry_(S.at(b, 8), mx(snare(200), clap()) * .45, verb=.35)
      for s in range(0, 16, 2): S.dry_(S.at(b, s), trap_hat() * (.1 if s % 4 else .06), pan=.25)
      if b % 4 == 3:
          for k in range(8): S.dry_(S.at(b, 12) + k * S.step / 2, trap_hat() * .07, pan=.25)
      # supersaw 和弦（future bass 的「哇哇」律動）
      pattern = [0, 3, 6, 10, 12, 14] if full else [0, 6, 12]
      for s in pattern:
          d = S.step * (2.6 if s in (0, 6) else 1.6)
          S.bed_(S.at(b, s), supersaw(notes, d, .085 if full else .05, cutoff=3800 if full else 2200, release=.08), verb=.35)
      S.dry_(S.at(b, 0), sub808(root - 12, S.beat * 2.2, .5))
      S.dry_(S.at(b, 10), sub808(root - 12, S.beat * 1.2, .4))
      # vox 旋律
      if full:
          mel = [(0, notes[2] + 12, 'a'), (2, notes[-1] + 12, 'e'), (4, notes[2] + 12, 'a'), (7, notes[1] + 12, 'o'), (10, notes[0] + 24, 'a')]
          for s, n, v in mel: S.bed_(S.at(b, s), vox(n, S.step * 1.7, .06, v), pan=.15, verb=.5)
  S.finish(end_fx=lambda m, s, L: cut_tail(m, s, L), pump=.6)

future_bass("future_bass", *T["fb"])
future_bass("after_fb", *T["fb2"], level=.8)

# ════════════════ 6. Drum & Bass（E 小調）91.6 → 112.2 ════════════════
S = Sec("dnb", *T["dnb"], 174, level=.95)
prog = [(40, "m7"), (36, "M7"), (43, "M"), (38, "M")]     # Em7 Cmaj7 G D
for b in range(S.bars):
    root, kd = prog[b % 4]
    notes = chord_notes(root + 24, kd)
    for s in (0, 10): S.kick(S.at(b, s), kick_hard(), .5)
    for s in (4, 12): S.dry_(S.at(b, s), snare(210) * .55, verb=.2)
    for s in (7, 14): S.dry_(S.at(b, s), snare(230, .6) * .12)
    for s in range(0, 16, 2): S.dry_(S.at(b, s), trap_hat() * (.1 if s % 4 == 2 else .06), pan=.3)
    S.dry_(S.at(b, 2), shaker() * .1, pan=-.3); S.dry_(S.at(b, 6), shaker() * .08, pan=-.3)
    S.dry_(S.at(b), reese(root, S.bar * .95, .16))
    S.bed_(S.at(b), pad(notes, S.bar + .1, attack=.15, release=.3) * .09, verb=.5)
    for s in (0, 3, 6, 9, 12):
        S.bed_(S.at(b, s), bell(mtof(notes[(s // 3) % len(notes)] + 12), .3, vel=.035, decay=10), pan=.5 if s % 2 else -.5, verb=.6)
S.finish(end_fx=lambda m, s, L: tape(m, s, L, .5), pump=.35)

# ════════════════ 7. AI 治理：間奏（C 大調）112.2 → 117.8 ════════════════
S = Sec("gov_break", *T["gov"], 128, level=.5)
for b in range(S.bars):
    notes = chord_notes([48, 45, 41][b % 3] + 12, ["add9", "m7", "M7"][b % 3])
    S.bed_(S.at(b), pad(notes, S.bar + .2, attack=.3, release=.5) * .14, verb=.7)
    for s in range(0, 16, 3):
        S.bed_(S.at(b, s), musicbox(notes[s % len(notes)] + 12, .8, .06), pan=np.sin(s) * .5, verb=.8)
    for s in range(0, 16, 4): S.dry_(S.at(b, s), rim() * .12, pan=-.3)
S.dry_(S.t1 - S.t0 - 1.0, downlifter(1.0) * .1)
S.finish(fade_in=.25, end_fx=lambda m, s, L: cut_tail(m, s, L), pump=0)

# ════════════════ 8. 交易安全：沉穩 Trap（C 小調）117.8 → 142.1 ════════════════
S = Sec("secure_trap", *T["secure"], 140, level=.9)
prog = [(36, "m"), (32, "M"), (29, "m"), (31, "M")]      # Cm Ab Fm G
for b in range(S.bars):
    root, kd = prog[b % 4]
    notes = chord_notes(root + 24, kd)
    last = b == S.bars - 1
    S.bed_(S.at(b), pad(notes, S.bar + .1, attack=.1, release=.3) * .1, verb=.4)
    for s in (0, 3, 8, 11):
        S.bed_(S.at(b, s), brass(notes, S.step * 1.3, .1), verb=.2)
    if not last:
        S.kick(S.at(b, 0), kick_hard(), .5)
        if b % 2: S.kick(S.at(b, 7), kick_hard(), .38)
        S.dry_(S.at(b, 8), mx(snare(), clap()) * .45, verb=.3)
        S.dry_(S.at(b, 0), sub808(root, S.bar * .45, .55))
        S.dry_(S.at(b, 7), sub808(root, S.beat * 1.4, .45, glide_from=root + 7 if b % 2 else None))
        for s in range(16):
            if s % 2 == 0: S.dry_(S.at(b, s), trap_hat() * .1, pan=.2)
        if b % 2 == 1:
            for k in range(8): S.dry_(S.at(b, 12) + k * S.step / 2, trap_hat() * (.05 + .06 * k / 8), pan=.2)
# 高潮前：小鼓連擊 + riser
lb = S.bars - 1
for k in range(16): S.dry_(S.at(lb) + k * S.step, snare(200 + k * 10) * (.1 + .4 * k / 16), verb=.3)
S.dry_(S.at(lb) - S.bar * .5, riser(S.bar * 1.5 - .12) * .25)
S.bed_(S.at(lb - 1, 8), choir([52, 56, 59, 64], S.bar * 1.5, .16), verb=.7)
S.finish(end_fx=lambda m, s, L: cut_tail(m, s, L - int(.12 * SR)), pump=.4)

# ════════════════ 9. 高潮：轉調 Dance-pop（A 大調）142.1 → 166.1 ════════════════
S = Sec("climax_pop", *T["climax"], 128, level=1.15)
prog = [(42, "m"), (38, "M"), (45, "M"), (40, "M")]      # F#m D A E
HOOK = [(0, 2, 76), (2, 2, 78), (4, 4, 81), (8, 2, 78), (10, 2, 76), (12, 4, 73),
        (16, 2, 76), (18, 2, 78), (20, 3, 81), (23, 3, 83), (26, 6, 85)]
for b in range(S.bars):
    root, kd = prog[b % 4]
    notes = chord_notes(root + 24, kd)
    for s in (0, 4, 8, 12): S.kick(S.at(b, s), kick_hard(), .55)
    for s in (4, 12): S.dry_(S.at(b, s), mx(clap() * 1.2, snare(220) * .5) * .45, verb=.3)
    for s in range(2, 16, 4): S.dry_(S.at(b, s), trap_hat(open_=True) * .08, pan=.3)
    for s in range(16): S.dry_(S.at(b, s), shaker() * (.05 if s % 2 else .025), pan=-.3)
    for s in (0, 3, 6, 10, 12):
        S.bed_(S.at(b, s), supersaw(notes, S.step * 1.5, .06, cutoff=5000, release=.06), verb=.25)
    for s in (0, 3, 8, 11, 14): S.dry_(S.at(b, s), sub808(root, S.step * 2.5, .45))
    # 銅管 hook（每兩小節一句）
    ph = b % 2
    for st, ln, n in HOOK:
        if st // 16 != ph: continue
        S.dry_(S.at(b, st % 16), brass([n - 12, n], S.step * ln * .9, .13), pan=.05, verb=.3)
        S.bed_(S.at(b, st % 16), bell(mtof(n + 12), S.step * ln + .2, vel=.04, decay=4, ratio=2.0), verb=.5)
    if b % 4 == 0: S.dry_(S.at(b), crash() * .2); S.dry_(S.at(b), vox_shout(69, .18), verb=.35)
S.dry_(0, impact() * .7, verb=.5)
S.finish(end_fx=lambda m, s, L: cut_tail(m, s, L), pump=.55)

# ════════════════ 10. 片尾：音樂盒 hook（A 大調）166.1 → 177 ════════════════
S = Sec("outro", *T["outro"], 80, level=.55)
ob = .55   # 每 16 分音符秒數（rubato）
for st, ln, n in HOOK[:6]:
    S.bed_(.35 + st * ob / 2, musicbox(n, 1.6, .12), pan=.1, verb=.9)
for t_, notes in [(0.3, chord_notes(62, "M")), (2.35, chord_notes(64, "M"))]:
    S.bed_(t_, pad(notes, 2.0, attack=.3, release=.5) * .12, verb=.6)
fin = LINE["end2"] + .25 - S.t0
final = chord_notes(57, "add9")
S.bed_(fin, pad(final, 4.5, attack=.02, release=1.8) * .16, verb=.7)
for j, n in enumerate(final + [69, 73, 76]):
    S.bed_(fin + j * .025, piano(mtof(n), 4.0, vel=.12), pan=-.4 + .12 * j, verb=.7)
S.dry_(fin, sub808(45, 2.5, .35)); S.dry_(fin, impact() * .35, verb=.5)
for j, n in enumerate([81, 85, 88, 93]):
    S.bed_(fin + .1 + j * .07, musicbox(n, 2.5, .07), pan=-.4 + .27 * j, verb=.9)
def outro_fx(m, s, L):
    k0 = int((TOTAL - 1.1 - S.t0) * SR); k1 = int((TOTAL - S.t0) * SR)
    m[k0:k1] *= np.linspace(1, 0, k1 - k0)[:, None]; m[k1:] = 0
S.finish(end_fx=outro_fx, pump=0)

def addm(t, x, g=1.0):
    i = int(t * SR); x = np.stack([x, x], 1) * g if x.ndim == 1 else x * g
    m = min(len(x), N - i); master[i:i + m] += x[:m]
out = master + reverb(send, seconds=2.2, wet=.5)
out = hp(out, 30)
out = out - .72 * lp(out, 190, 2)          # 低頻擱架衰減，避免 808 過重
np.save("stems/music.npy", out.astype(np.float32))
for row in SECTION_LOG: print("%-12s %7.3f-%7.3f  %2d bars  %5.1f BPM" % row)
# 節拍格線：各曲風段落的小節線與拍點（絕對秒數），場景把換場與浮出對齊到這裡
json.dump({"sections": [{"name": n, "t0": t0, "t1": t1, "bars": b, "bpm": bpm,
                         "bar_times": [round(t0 + i * (t1 - t0) / b, 4) for i in range(b + 1)],
                         "beat": round((t1 - t0) / b / 4, 5)} for n, t0, t1, b, bpm in SECTION_LOG]},
          open("../src/beats.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("peak", np.abs(out).max())
