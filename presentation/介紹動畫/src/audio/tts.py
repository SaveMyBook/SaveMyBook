import asyncio, subprocess, json, os, sys
import numpy as np, edge_tts
from script import LINES

import imageio_ffmpeg
FF = imageio_ffmpeg.get_ffmpeg_exe()
VOICE = sys.argv[1] if len(sys.argv) > 1 else "zh-TW-HsiaoChenNeural"
SR = 48000
os.makedirs("tts", exist_ok=True)

def decode(mp3):
    raw = subprocess.run([FF, "-v", "error", "-i", mp3, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).copy()
    # 去頭尾靜音
    thr = 0.01 * np.abs(x).max()
    idx = np.where(np.abs(x) > thr)[0]
    a, b = max(0, idx[0] - int(0.02 * SR)), min(len(x), idx[-1] + int(0.08 * SR))
    return x[a:b]

async def gen(text, rate, path):
    await edge_tts.Communicate(text, VOICE, rate=f"{rate:+d}%").save(path)

async def main():
    meta = []
    for i, (st, en, text) in enumerate(LINES):
        rate = -8 if i >= len(LINES) - 2 else 0   # 結尾兩句放慢
        for _ in range(6):
            mp3 = f"tts/{i:02d}.mp3"
            await gen(text, rate, mp3)
            x = decode(mp3)
            dur = len(x) / SR
            win = en - st
            if dur <= win or rate >= 35:
                break
            rate = min(35, rate + int(np.ceil((dur / win - 1) * 100)) + 2)
        np.save(f"tts/{i:02d}.npy", x)
        meta.append(dict(i=i, start=st, end=st + dur, win_end=en, rate=rate, text=text))
        flag = "  <-- OVER" if dur > win else ""
        print(f"{i:02d} {st:6.1f}-{st+dur:6.1f} (win {en:6.1f}) rate {rate:+d}%  {text}{flag}")
    json.dump(meta, open("tts/meta.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

asyncio.run(main())
