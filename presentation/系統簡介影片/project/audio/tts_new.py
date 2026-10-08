"""系統簡介影片旁白：依 narration.json 逐句呼叫 edge-tts（循序、失敗重試），
輸出 tts/<id>.mp3 → 去頭尾靜音的 48 kHz 單聲道 tts/<id>.wav，並寫入 tts/durations.json。

  python tts_new.py            # 只重做文字／聲音／語速有變動的句子
  python tts_new.py --force    # 全部重做
ffmpeg 來源：環境變數 FFMPEG → imageio_ffmpeg → PATH。
"""
import asyncio, json, os, shutil, subprocess, sys, time
import numpy as np
import edge_tts

HERE = os.path.dirname(os.path.abspath(__file__))
TTS_DIR = os.path.join(HERE, "tts")
SR = 48000
THR_DB = -45.0          # 低於此音量（dBFS，10 ms RMS）視為靜音
HEAD_KEEP = 0.010       # 句首保留 10 ms
TAIL_KEEP = 0.030       # 句尾保留 30 ms 自然尾音
FADE_IN, FADE_OUT = 0.003, 0.012
RETRIES = 6


def find_ffmpeg():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        pass
    p = shutil.which("ffmpeg")
    if not p:
        sys.exit("找不到 ffmpeg：請設定 FFMPEG 環境變數")
    return p


FF = find_ffmpeg()


def decode(mp3):
    raw = subprocess.run([FF, "-v", "error", "-i", mp3, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()


def trim(x):
    hop = int(0.010 * SR)
    n = len(x) // hop
    rms = np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    loud = np.where(20 * np.log10(rms) > THR_DB)[0]
    if len(loud) == 0:
        raise RuntimeError("整段都是靜音")
    a = max(0, loud[0] * hop - int(HEAD_KEEP * SR))
    b = min(len(x), (loud[-1] + 1) * hop + int(TAIL_KEEP * SR))
    y = x[a:b].copy()
    fi, fo = int(FADE_IN * SR), int(FADE_OUT * SR)
    y[:fi] *= np.linspace(0, 1, fi, dtype=np.float32)
    y[-fo:] *= np.linspace(1, 0, fo, dtype=np.float32)
    return y


def write_wav(path, y):
    subprocess.run([FF, "-v", "error", "-y", "-f", "f32le", "-ac", "1", "-ar", str(SR), "-i", "-",
                    "-c:a", "pcm_s16le", path], input=y.astype(np.float32).tobytes(), check=True)


async def synth(text, voice, rate, out):
    last = None
    for k in range(RETRIES):
        try:
            tmp = out + ".part"
            await edge_tts.Communicate(text, voice, rate=rate).save(tmp)
            if os.path.getsize(tmp) < 1000:
                raise RuntimeError("回傳音檔過小")
            os.replace(tmp, out)
            return
        except Exception as e:  # 網路／服務端暫時性錯誤：等一下再試
            last = e
            wait = 2 * (k + 1)
            print(f"   重試 {k + 1}/{RETRIES}（{type(e).__name__}: {e}），{wait}s 後再試", flush=True)
            time.sleep(wait)
    raise RuntimeError(f"edge-tts 連續失敗：{last}")


async def main():
    force = "--force" in sys.argv
    cfg = json.load(open(os.path.join(HERE, "narration.json"), encoding="utf-8"))
    voice, rate = cfg["voice"], cfg["rate"]
    os.makedirs(TTS_DIR, exist_ok=True)
    cache_path = os.path.join(TTS_DIR, "cache.json")
    cache = json.load(open(cache_path, encoding="utf-8")) if os.path.exists(cache_path) else {}
    durs = {}
    for ln in cfg["lines"]:
        lid, text = ln["id"], ln["tts"]
        mp3 = os.path.join(TTS_DIR, f"{lid}.mp3")
        wav = os.path.join(TTS_DIR, f"{lid}.wav")
        key = {"tts": text, "voice": voice, "rate": rate}
        if force or not os.path.exists(mp3) or cache.get(lid) != key:
            await synth(text, voice, rate, mp3)        # 循序執行：同時送出多個請求會失敗
            cache[lid] = key
            json.dump(cache, open(cache_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            src = "新產生"
        else:
            src = "沿用"
        y = trim(decode(mp3))
        write_wav(wav, y)
        durs[lid] = round(len(y) / SR, 3)
        print(f"{lid:4s} {durs[lid]:6.2f}s  {src}  {text}", flush=True)
    json.dump(durs, open(os.path.join(TTS_DIR, "durations.json"), "w", encoding="utf-8"), indent=1)
    print(f"共 {len(durs)} 句，旁白合計 {sum(durs.values()):.2f}s")


asyncio.run(main())
