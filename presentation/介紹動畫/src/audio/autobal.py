"""逐一檢查重要音效：若比音樂小，就單獨補強（最多 +9 dB），寫入 cue_boost.json"""
import json, os, numpy as np
from synth import SR, hp
mu = hp(np.load("stems/_m.npy").mean(1), 300, 4); fx = hp(np.load("stems/_s.npy").mean(1), 300, 4)
db = lambda x: 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
cues = json.load(open("cues.json", encoding="utf-8"))["cues"]
AMB = {'door_close', 'swell', 'riser_short', 'bump', 'whoosh', 'process', 'slide', 'door_open', 'scan'}
B = json.load(open("cue_boost.json")) if os.path.exists("cue_boost.json") else {}
TARGET = 3.0
v_all = []
for i, c in enumerate(cues):
    if c["type"] in AMB: continue
    k = int(c["t"] * SR); w = int(.15 * SR)
    v = db(fx[k:k + w]) - db(mu[k:k + w]); v_all.append(v)
    if v < TARGET:
        B[str(i)] = round(min(9.0, B.get(str(i), 0) + (TARGET - v)), 2)
json.dump(B, open("cue_boost.json", "w"))
v_all = np.array(v_all)
print(f"important={len(v_all)} median={np.median(v_all):+.1f}dB masked={np.mean(v_all < 0) * 100:.0f}% below-3dB={np.mean(v_all < -3) * 100:.0f}% boosted={len(B)}")
