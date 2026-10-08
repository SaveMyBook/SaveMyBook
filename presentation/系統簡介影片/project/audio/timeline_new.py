"""系統簡介影片時間軸：依 narration.json 的句子順序與 tts/durations.json 的實際長度，
產生 ../src/timeline.json（段落起訖、每句在段落內的開始秒數）與 out/line_starts.json（每句絕對開始秒數，給 subs_new.py）。

句與句之間的停頓：同段 GAP_IN；換段時在下一段第一句之前多留 LEAD（段落轉場）。
各段可在 HOLD 補加段落開頭的額外時間（例如片頭先看 logo）、TAIL 補加段落結尾的停留。

  python timeline_new.py
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
N = json.load(open(os.path.join(HERE, "narration.json"), encoding="utf-8"))
D = json.load(open(os.path.join(HERE, "tts/durations.json"), encoding="utf-8"))

GAP_IN = 0.32     # 同段相鄰兩句
LEAD = 0.95       # 每段開頭到第一句（轉場時間）
FIRST = 0.8       # 片頭第一句前
HOLD = {}         # 段落 id → 額外開頭時間
EXTRA = {}        # 句子 id → 該句之前額外停頓
END_TAIL = 2.6    # 最後一句結束後片尾停留
LIMIT = 179.0     # 規定 3 分鐘，保留餘裕

lines = N["lines"]
sections, out_lines, starts = [], [], {}
t = 0.0
cur = None
for i, l in enumerate(lines):
    sec = l["section"]
    if sec != cur:
        if cur is not None:
            sections[-1]["end"] = round(t, 3)
        sections.append({"id": sec, "start": round(t, 3), "end": None})
        cur = sec
        t += (FIRST if i == 0 else LEAD) + HOLD.get(sec, 0)
    else:
        t += GAP_IN
    t += EXTRA.get(l["id"], 0)
    starts[l["id"]] = round(t, 3)
    out_lines.append({"id": l["id"], "sec": sec, "at": round(t - sections[-1]["start"], 3), "dur": D[l["id"]], "text": l["sub"]})
    t += D[l["id"]]
t += END_TAIL
sections[-1]["end"] = round(t, 3)
total = round(t, 3)
assert total <= LIMIT, f"總長 {total} 秒超過 {LIMIT}"

json.dump({"duration": total, "sections": sections, "lines": out_lines},
          open(os.path.join(HERE, "../src/timeline.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
json.dump(starts, open(os.path.join(HERE, "out/line_starts.json"), "w"), indent=1)
for s in sections:
    print(f"{s['id']:9s} {s['start']:7.2f} – {s['end']:7.2f}  ({s['end'] - s['start']:5.2f}s)")
print("總長", total)
