"""把 tts_new.py 產生的旁白（tts/<id>.wav）與 timeline_new.py 的開始時間（out/line_starts.json）
轉成 mix.py 需要的格式：tts/meta.json（i、start、end、text）與 tts/<i:02d>.npy。"""
import json, wave, numpy as np
N = json.load(open("narration.json", encoding="utf-8"))["lines"]
starts = json.load(open("out/line_starts.json"))
meta = []
for i, l in enumerate(N, 1):
    w = wave.open(f"tts/{l['id']}.wav")
    x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
    np.save(f"tts/{i:02d}.npy", x)
    s = starts[l["id"]]
    meta.append({"i": i, "id": l["id"], "start": s, "end": round(s + len(x) / w.getframerate(), 3), "text": l["tts"]})
json.dump(meta, open("tts/meta.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("meta", len(meta), "last end", meta[-1]["end"])
