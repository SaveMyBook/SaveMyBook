"""混音：旁白 + 音樂（自動閃避）+ 音效 → mix.wav、各分軌、字幕"""
import json, os
import numpy as np
from scipy.io import wavfile
from scipy.ndimage import uniform_filter1d
from synth import SR, TOTAL, Track, hp, lp
from script import LINES, subtitle_text

N = int(TOTAL * SR) + 1
music = np.load("stems/music.npy")[:N]
sfx = np.load("stems/sfx.npy")[:N]
sfx_pt = np.load("stems/sfx_point.npy")[:N] * 1.40
meta = json.load(open("tts/meta.json", encoding="utf-8"))

# ---- 旁白
def load_clip(i):
    """讀取旁白片段：有解碼快取就用，否則從 tts/*.mp3 解碼（與 tts.py 相同的去頭尾靜音）"""
    p = f"tts/{i:02d}.npy"
    if os.path.exists(p): return np.load(p).astype(np.float64)
    import subprocess, imageio_ffmpeg
    raw = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-i", f"tts/{i:02d}.mp3", "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    idx = np.where(np.abs(x) > .01 * np.abs(x).max())[0]
    x = x[max(0, idx[0] - int(.02 * SR)):min(len(x), idx[-1] + int(.08 * SR))]
    np.save(p, x.astype(np.float32)); return x

voice = np.zeros(N)
for m in meta:
    x = load_clip(m["i"])
    x = hp(x, 90)
    x /= np.sqrt(np.mean(x ** 2)) + 1e-9
    i = int(m["start"] * SR)
    voice[i:i + len(x)] += x[:N - i] * .10
voice_st = np.stack([voice, voice], 1)

# ---- 閃避：旁白出現時把音樂壓低約 5 dB
mask = np.zeros(N)
for m in meta:
    a, b = int((m["start"] - .25) * SR), int((m["end"] + .35) * SR)
    mask[max(0, a):b] = 1
mask = uniform_filter1d(mask, int(.35 * SR))
duck = 1 - .5 * mask

def rms(x): return np.sqrt(np.mean(x ** 2))
sp = mask > .5
vh = rms(hp(voice[sp], 200, 4))
music *= vh * 10 ** (-7.5 / 20) / rms(hp(music.mean(1)[~sp], 200, 4))
sfx *= 1.40   # 固定增益：不隨單一最大峰值浮動

# ---- 音效側鏈閃避（分頻段）：音效響起時，音樂在音效所在的頻段讓出空間
from scipy.ndimage import maximum_filter1d
from scipy import signal as _sg
def zp(x, f, kind):   # 零相位濾波，三個頻段相加可完美還原
    sos = _sg.butter(4, f, kind, fs=SR, output="sos"); return _sg.sosfiltfilt(sos, x, axis=0)
_cues = json.load(open("cues.json", encoding="utf-8"))["cues"]
_AMB = {'door_close', 'swell', 'riser_short', 'bump', 'whoosh', 'process', 'slide', 'door_open', 'scan'}
_HERO = {'slam', 'book', 'unlock', 'success', 'notify', 'cash', 'coin_land', 'impact', 'shutter', 'core', 'final', 'tap', 'key', 'pin', 'alert', 'block', 'node'}
_n = int(.2 * SR); _t = np.arange(_n) / SR
_bump = np.where(_t < .008, _t / .008, np.where(_t < .048, 1, np.exp(-(_t - .048) / .05)))
amt_cue = np.zeros(N)
for c in _cues:
    if c["type"] in _AMB: continue
    i = max(0, int((c["t"] - .006) * SR)); m_ = min(_n, N - i)
    w = 1.0 if c["type"] in _HERO else .7
    amt_cue[i:i + m_] = np.maximum(amt_cue[i:i + m_], _bump[:m_] * w)
env = np.abs(hp(sfx_pt.mean(1), 300, 4))       # 只看點狀音效
env = maximum_filter1d(env, int(.015 * SR))                # 抓住瞬間峰值
env = uniform_filter1d(env, int(.035 * SR))                # 平滑：約 35ms 起落，只在音效瞬間讓位
env = np.roll(env, -int(.008 * SR))                        # 預視 8ms，讓音樂比音效早一點點讓位
ref = np.percentile(env[env > 1e-4], 85)
amt = amt_cue                                   # 只在音效起音時短暫讓位（約 0.15 秒）
music_low = zp(music, 250, "low")
music_high = zp(music, 1500, "high")
music_mid = music - music_low - music_high
DEPTH = {"low": .1, "mid": .4, "high": .6}              # 低頻幾乎不動、高頻讓最多（約 -9 dB）
music = (music_low * (1 - DEPTH["low"] * amt)[:, None] + music_mid * (1 - DEPTH["mid"] * amt)[:, None]
         + music_high * (1 - DEPTH["high"] * amt)[:, None])

np.save("stems/_m.npy", (music * duck[:, None]).astype(np.float32)); np.save("stems/_s.npy", sfx.astype(np.float32))
mix = music * duck[:, None] + sfx + voice_st
peak = np.abs(mix).max()
mix = np.tanh(mix / peak * 1.2) / np.tanh(1.2) * .89   # 輕度軟限幅

os.makedirs("out", exist_ok=True)
wavfile.write("out/mix.wav", SR, mix.astype(np.float32))
wavfile.write("out/旁白.wav", SR, (voice_st / np.abs(voice_st).max() * .9).astype(np.float32))
wavfile.write("out/配樂.wav", SR, (music / np.abs(music).max() * .9).astype(np.float32))
wavfile.write("out/音效.wav", SR, (sfx / np.abs(sfx).max() * .9).astype(np.float32))

# ---- SRT 字幕
def ts(s):
    h, r = divmod(s, 3600); mnt, sec = divmod(r, 60)
    return f"{int(h):02d}:{int(mnt):02d}:{int(sec):02d},{int(round((sec % 1) * 1000)):03d}"
with open("out/旁白字幕.srt", "w", encoding="utf-8-sig") as f:
    for j, m in enumerate(meta, 1):
        f.write(f"{j}\n{ts(m['start'])} --> {ts(m['end'] + .3)}\n{subtitle_text(m['text'])}\n\n")
print("done; voice peak", np.abs(voice).max(), "music rms", rms(music), "pre-limit peak", peak)
