"""旁白：依 ../src/timeline.json 產生每句的語音與實際起訖時間（tts/meta.json）。
與第一版文字相同的句子沿用 tts_src/ 的錄音；新句子才呼叫 edge-tts 產生。"""
import asyncio, subprocess, json, os, shutil
import numpy as np, edge_tts
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
VOICE = "zh-TW-HsiaoChenNeural"
SR = 48000
TL = json.load(open("../src/timeline.json", encoding="utf-8"))
SEC = {s["id"]: s["start"] for s in TL["sections"]}
OLD = {m["text"]: f"tts_src/{m['i']:02d}.mp3" for m in json.load(open("tts_src/meta.json", encoding="utf-8"))}
os.makedirs("tts", exist_ok=True)


def speech(text):
    """TTS 讀音：品牌名稱的引號會被唸出來，改用無引號寫法。"""
    return text.replace("救「舊」我的書", "救舊我的書")


def decode(mp3):
    raw = subprocess.run([FF, "-v", "error", "-i", mp3, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).copy()
    thr = 0.01 * np.abs(x).max()
    idx = np.where(np.abs(x) > thr)[0]
    return x[max(0, idx[0] - int(0.02 * SR)):min(len(x), idx[-1] + int(0.08 * SR))]


async def main():
    lines = TL["lines"]
    cached = {m["i"]: m["text"] for m in json.load(open("tts/meta.json", encoding="utf-8"))} if os.path.exists("tts/meta.json") else {}
    meta = []
    for i, ln in enumerate(lines):
        start = SEC[ln["sec"]] + ln["at"]
        nxt = SEC[lines[i + 1]["sec"]] + lines[i + 1]["at"] if i + 1 < len(lines) else TL["duration"]
        mp3 = f"tts/{i:02d}.mp3"
        text = speech(ln["text"])
        if text in OLD:
            shutil.copy(OLD[text], mp3)
            src = "沿用"
        elif os.path.exists(mp3) and cached.get(i) == ln["text"]:
            src = "已存在"
        else:
            rate = -8 if ln["id"] in ("end1", "end2") else 0
            await edge_tts.Communicate(text, VOICE, rate=f"{rate:+d}%").save(mp3)
            src = "新產生"
        x = decode(mp3)
        np.save(f"tts/{i:02d}.npy", x)
        dur = len(x) / SR
        meta.append(dict(i=i, id=ln["id"], start=start, end=start + dur, text=ln["text"]))
        flag = "  <-- 與下一句重疊" if start + dur > nxt - 0.3 else ""
        print(f"{i:02d} {ln['id']:9s} {start:6.1f}-{start + dur:6.1f} (下一句 {nxt:6.1f}) {src}  {ln['text']}{flag}")
    json.dump(meta, open("tts/meta.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


asyncio.run(main())
