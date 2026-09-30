"""量測每個音效響起的 150ms 內，音效比音樂大（或小）幾 dB。以 300Hz 以上計算（人耳辨識音效的主要頻段）"""
import json, collections
import numpy as np
from synth import SR, hp

mu = np.load("stems/_m.npy").mean(1); fx = np.load("stems/_s.npy").mean(1)
mu_h = hp(mu, 300, 4); fx_h = hp(fx, 300, 4)
db = lambda x: 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
cues = json.load(open("cues.json", encoding="utf-8"))["cues"]
rel = collections.defaultdict(list); allv = []
for c in cues:
    i = int(c["t"] * SR); w = int(.15 * SR)
    v = db(fx_h[i:i + w]) - db(mu_h[i:i + w])
    rel[c["type"]].append(v); allv.append(v)
allv = np.array(allv)
print(f"全部 {len(allv)} 個音效：中位數 {np.median(allv):+.1f} dB，被音樂蓋過（<0 dB）的比例 {np.mean(allv < 0) * 100:.0f}%")
worst = sorted(((np.median(v), k, len(v)) for k, v in rel.items()))[:12]
print("最容易被蓋住的類型：", ", ".join(f"{k}({m:+.1f})" for m, k, n in worst))
