"""把每句旁白 wav 依 out/line_starts.json 放到時間軸上，輸出 out/narration_full.wav（48 kHz 單聲道）。"""
import json, wave, numpy as np
starts = json.load(open("out/line_starts.json"))
total = json.load(open("../src/timeline.json"))["duration"]
SR = 48000
buf = np.zeros(int((total + 1) * SR), np.float32)
for i, t0 in starts.items():
    w = wave.open(f"tts/{i}.wav"); assert w.getframerate() == SR and w.getnchannels() == 1
    x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
    a = int(t0 * SR); buf[a:a + len(x)] += x
buf = buf[:int(total * SR)]
o = wave.open("out/narration_full.wav", "wb"); o.setnchannels(1); o.setsampwidth(2); o.setframerate(SR)
o.writeframes((np.clip(buf, -1, 1) * 32767).astype(np.int16).tobytes())
print("ok", round(len(buf) / SR, 2))
