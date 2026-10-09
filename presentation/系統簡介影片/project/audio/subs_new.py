"""系統簡介影片字幕（學校規定格式）：畫面下方置中、微軟正黑體、白字黑框、僅中文。
取代舊版 subs.py 的白色圓角卡片樣式。

輸入：narration.json、tts/durations.json、時間軸 JSON {id: 起始秒數}
輸出：out/subs.ass、out/subs.srt

  python subs_new.py                         # 用暫時的連續時間軸（自動產生 out/timeline_temp.json）
  python subs_new.py --timeline 檔案.json     # 用正式時間軸

燒字幕：ffmpeg -vf "ass=out/subs.ass:fontsdir=fonts"
fonts/ 內放 微軟正黑體（msjhbd.ttc 第 0 個字面 = "Microsoft JhengHei" Bold；msjh.ttf = Regular），
不進版控（.gitignore）。
"""
import argparse, json, os, re, sys, wave
import numpy as np
from PIL import ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
P = lambda *a: os.path.join(HERE, *a)

# ── 樣式（1920×1080 座標）──
PLAY_W, PLAY_H = 1920, 1080
FONT_NAME = "Microsoft JhengHei"          # 與字型檔內 family name 相同（fc-scan 驗證）
# Bold 可能是 Windows 的 msjhbd.ttc 或單獨的 msjhbd.ttf；只有 Regular 時粗體由 libass 合成（度量值與 Bold 相同）
FONT_FILE = next(f for f in (P("fonts", n) for n in ("msjhbd.ttc", "msjhbd.ttf", "msjh.ttf")) if os.path.exists(f))
FONT_INDEX = 0
WIN_SUM, UPEM = 2203 + 521, 2048          # usWinAscent + usWinDescent；libass 依此換算字級
EM_PX = 50                                # 實際字身（中文字高）px
FONT_SIZE = round(EM_PX * WIN_SUM / UPEM) # ASS 字級（≈ 66.5 → 67）
OUTLINE, SHADOW = 4, 1
MARGIN_LR, MARGIN_V = 120, 48
MAX_CJK = 24                              # 單行上限：24 個全形字寬
MAX_W = MAX_CJK * EM_PX
TAIL = 0.25                               # 字幕比旁白多留 0.25 s
MIN_GAP = 0.04                            # 與下一則字幕至少相隔
BREAK_AFTER = "，、；：。？！"

FONT = ImageFont.truetype(FONT_FILE, EM_PX, index=FONT_INDEX)
width = lambda s: FONT.getlength(s)

STYLE = (f"Style: Default,{FONT_NAME},{FONT_SIZE},&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,"
         f"-1,0,0,0,100,100,0,0,1,{OUTLINE},{SHADOW},2,{MARGIN_LR},{MARGIN_LR},{MARGIN_V},1")


def split_points(s):
    return [i + 1 for i, ch in enumerate(s) if ch in BREAK_AFTER and i + 1 < len(s)]


def split_sub(s):
    """太長就在標點處切成兩段（依序出現），選兩段都放得下且最平均的位置"""
    if width(s) <= MAX_W:
        return [s]
    best = None
    for k in split_points(s):
        a, b = s[:k].rstrip(), s[k:].lstrip()
        if width(a) <= MAX_W and width(b) <= MAX_W:
            weak = s[k - 1] == "、"                  # 頓號只在沒有逗號等可切時才用
            score = (weak, max(width(a), width(b)))
            if best is None or score < best[0]:
                best = (score, k)
    if best is None:
        sys.exit(f"字幕過長且找不到可切的標點：{s}")
    k = best[1]
    return [s[:k].rstrip(), s[k:].lstrip()]


def count(s):
    return len(re.sub(r"\s", "", s))


def tts_ratio(tts, sub, k_sub):
    """切點前的比例：盡量用 TTS 文字（數字唸法較長）在同一個標點處計算，對不上才用字幕字數"""
    nth = sum(1 for ch in sub[:k_sub] if ch in BREAK_AFTER)
    pts = [i + 1 for i, ch in enumerate(tts) if ch in BREAK_AFTER]
    if [c for c in sub if c in BREAK_AFTER] == [c for c in tts if c in BREAK_AFTER] and 0 < nth <= len(pts):
        k = pts[nth - 1]
        return count(tts[:k]) / count(tts)
    return count(sub[:k_sub]) / count(sub)


def snap_to_pause(wav_path, t_est, dur, win=0.7):
    """把估計切點對齊到附近最安靜的一段（旁白在標點處的停頓）"""
    try:
        with wave.open(wav_path) as w:
            sr = w.getframerate()
            x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
    except Exception:
        return t_est
    hop = int(0.01 * sr)
    n = len(x) // hop
    db = 20 * np.log10(np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, axis=1)) + 1e-9)
    sm = np.convolve(db, np.ones(8) / 8, mode="same")       # 80 ms 平滑
    lo, hi = max(1, int((t_est - win) * 100)), min(n - 2, int((t_est + win) * 100))
    if hi <= lo:
        return t_est
    i = lo + int(np.argmin(sm[lo:hi]))
    if sm[i] > -38:              # 附近沒有明顯停頓
        return t_est
    return min(max(i / 100, 0.3), dur - 0.3)


def temp_timeline(lines, durs, start=1.0, gap=0.45):
    tl, t = {}, start
    for ln in lines:
        tl[ln["id"]] = round(t, 3)
        t += durs[ln["id"]] + gap
    return tl


def ts_ass(t):
    cs = int(round(t * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def ts_srt(t):
    ms = int(round(t * 1000))
    return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeline", help="JSON {id: 起始秒數}；省略則產生暫時的連續時間軸")
    ap.add_argument("--out", default=P("out"))
    args = ap.parse_args()

    cfg = json.load(open(P("narration.json"), encoding="utf-8"))
    durs = json.load(open(P("tts", "durations.json"), encoding="utf-8"))
    lines = cfg["lines"]
    os.makedirs(args.out, exist_ok=True)
    if args.timeline:
        tl = json.load(open(args.timeline, encoding="utf-8"))
    else:
        tl = temp_timeline(lines, durs)
        json.dump(tl, open(os.path.join(args.out, "timeline_temp.json"), "w"), indent=1)

    order = sorted(lines, key=lambda l: tl[l["id"]])
    events = []                                   # (t0, t1, text, id)
    for n, ln in enumerate(order):
        lid, sub = ln["id"], ln["sub"]
        t0, dur = tl[lid], durs[lid]
        t_end = t0 + dur + TAIL
        if n + 1 < len(order):
            t_end = min(t_end, tl[order[n + 1]["id"]] - MIN_GAP)
        parts = split_sub(sub)
        if len(parts) == 1:
            events.append((t0, t_end, sub, lid))
            continue
        k = len(parts[0])
        while sub[k] == " ":
            k += 1
        t_split = snap_to_pause(P("tts", f"{lid}.wav"), dur * tts_ratio(ln["tts"], sub, k), dur)
        events.append((t0, t0 + t_split, parts[0], lid))
        events.append((t0 + t_split, t_end, parts[1], lid))

    ass = ["[Script Info]", "ScriptType: v4.00+", f"PlayResX: {PLAY_W}", f"PlayResY: {PLAY_H}",
           "WrapStyle: 2", "ScaledBorderAndShadow: yes", "YCbCr Matrix: TV.709", "",
           "[V4+ Styles]",
           "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
           "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
           "Alignment, MarginL, MarginR, MarginV, Encoding",
           STYLE, "", "[Events]",
           "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"]
    # 畫面上已有和旁白一模一樣的文字時，該句（或該句的第 n 段，寫成 "08.2"）不燒入字幕；SRT 字幕檔仍保留全部
    hide_path = P("subs_hide.json")
    hide = set(json.load(open(hide_path, encoding="utf-8"))["hide"]) if os.path.exists(hide_path) else set()
    part_no = {}
    srt = []
    for i, (a, b, text, lid) in enumerate(events, 1):
        part_no[lid] = part_no.get(lid, 0) + 1
        srt += [str(i), f"{ts_srt(a)} --> {ts_srt(b)}", text, ""]
        if lid in hide or f"{lid}.{part_no[lid]}" in hide:
            print(f"{lid:4s} {a:7.2f}-{b:7.2f}  （畫面已有相同文字，不燒入）{text}")
            continue
        ass.append(f"Dialogue: 0,{ts_ass(a)},{ts_ass(b)},Default,{lid},0,0,0,,{text}")
        print(f"{lid:4s} {a:7.2f}-{b:7.2f}  {width(text) / EM_PX:4.1f}字寬  {text}")
    open(os.path.join(args.out, "subs.ass"), "w", encoding="utf-8").write("\n".join(ass) + "\n")
    open(os.path.join(args.out, "subs.srt"), "w", encoding="utf-8").write("\n".join(srt))
    last = order[-1]["id"]
    print(f"{len(events)} 則字幕；最後一句旁白結束於 {tl[last] + durs[last]:.2f}s")
    print(STYLE)


if __name__ == "__main__":
    main()
