"""v3 字幕（NTUB 風格）：深色字、字重 500、不描邊，只加極淡的白色柔光，固定在畫面底部的字幕帶（y ≥ 976）。

字幕的拆段與時間沿用 subs_new.py（同一套斷句與停頓對齊），畫面標題與旁白相同的句子依 subs_hide.json 不燒入中文。
英文由本檔的 EN 提供，依中文拆段逐段對應；中英版中，中文被隱藏的句子仍顯示英文。

輸入：narration.json、tts/durations.json、out/line_starts.json
輸出：
  out/subs_v3_zh.ass      中文（燒入 4K 與 1080p 成品）
  out/subs_v3_zhen.ass    中英（燒入中英字幕版）
  out/subs_v3_zh.srt      中文全部句子
  out/subs_v3_zhen.srt    中英全部句子
燒入：ffmpeg -vf "ass=out/subs_v3_zh.ass:fontsdir=<含 PingFang.ttc 的資料夾>"（字型名稱用 PostScript 名稱 PingFangTC-Medium 才會選到字重 500）
"""
import json, os, re
import subs_new as S

HERE = os.path.dirname(os.path.abspath(__file__))
P = lambda *a: os.path.join(HERE, *a)

# 字級：libass 的字級是字身上下總高，PingFang 的 32px 字（瀏覽器）對應 ASS 46；英文 22px 對應 31
ZH_SIZE, EN_SIZE = 46, 31
INK, SUB = "&H001F1D1D", "&H006F624D"           # #1D1D1F、#4D626F（ASS 為 BGR）
GLOW = "&H40FFFFFF"                             # 白色、約 75% 不透明，再以 \\blur 柔化成極淡的光暈
# 字幕帶內的位置（MarginV 為字框下緣到畫面底的距離，以實際算圖量測校正）：
#   中文版單行中心約 y=1028；中英版中文中心約 y=1006、英文中心約 y=1048
ZH_ONLY_MV, ZH_MV, EN_MV = 27, 49, 14

EN = {
    ("01", 1): "In secondhand book trading, the biggest worries are no-shows at meetups and the hassle of shipping.",
    ("02", 1): "In our survey, 57.4% of respondents said",
    ("02", 2): "the most appealing feature of the locker is 24-hour self-service.",
    ("03", 1): "SaveMyBook combines an app with smart lockers,",
    ("03", 2): "so buyers and sellers never need to arrange a meeting.",
    ("04", 1): "Check the book's condition and pay online;",
    ("04", 2): "the seller drops off, the buyer picks up, and payment is released only after acceptance.",
    ("05", 1): "Sellers scan the ISBN, and the system fills in the title, author, and publisher automatically.",
    ("06", 1): "Take photos of the book, and AI assesses its condition and suggests a price range.",
    ("07", 1): "Listings then pass a two-layer review by rules and AI to ensure quality.",
    ("08", 1): "Buyers can search by title, author, or ISBN,",
    ("08", 2): "and also receive personalized recommendations.",
    ("09", 1): "Describe your needs and budget, and the AI book advisor helps you choose.",
    ("10", 1): "Chat supports text, images, and voice messages,",
    ("10", 2): "with instant fraud alerts whenever a high-risk message appears.",
    ("11", 1): "Payments are verified by a transaction PIN or biometrics, and the platform holds the funds in escrow.",
    ("12", 1): "A single ESP32-S3 controls",
    ("12", 2): "the locker's four electromagnetic-lock doors and its screen.",
    ("13", 1): "To open a door, you must be within 200 meters of the locker",
    ("13", 2): "and scan its QR code, which refreshes every 30 seconds,",
    ("14", 1): "then enter the two-digit number on its screen within 60 seconds",
    ("14", 2): "before the assigned door opens.",
    ("15", 1): "Once the door is closed, the system records the drop-off and notifies the buyer.",
    ("16", 1): "The app also integrates Taipei City open data",
    ("16", 2): "to show MRT, bus, and YouBike options for getting to the locker.",
    ("17", 1): "Buyers pick up the same way and check the book on the spot;",
    ("17", 2): "if there is no dispute within 24 hours, payment goes to the seller automatically.",
    ("18", 1): "If the condition does not match, buyers can file a dispute with photos,",
    ("18", 2): "and AI compares it with the listing to assist administrators.",
    ("19", 1): "For questions, the AI support assistant answers instantly,",
    ("19", 2): "with one-tap transfer to a human agent.",
    ("19b", 1): "From listing and choosing books to after-sales support, seven AI services assist throughout.",
    ("20", 1): "Sign in with Google, Apple, LINE,",
    ("20", 2): "SMS, passkeys, and more.",
    ("21", 1): "Completed trades earn points toward membership upgrades,",
    ("21", 2): "and the interface supports five languages and light and dark themes.",
    ("22", 1): "The admin console is built into the app,",
    ("22", 2): "handling listing reviews, orders, disputes, and announcements;",
    ("23", 1): "entering the eight-digit pairing code on a locker's screen connects a new locker.",
    ("24", 1): "The system is built with Flutter, Node.js,",
    ("24", 2): "MariaDB, and ESP32-S3,",
    ("24b", 1): "with 304 APIs,",
    ("24b", 2): "and more than 4,000 automated front-end and back-end tests, all passing.",
    ("25", 1): "SaveMyBook: letting idle books circulate again on campus.",
}


def events():
    """與 subs_new.main 相同的拆段與時間：[(t0, t1, 中文, id, 段號)]。"""
    cfg = json.load(open(P("narration.json"), encoding="utf-8"))
    durs = json.load(open(P("tts", "durations.json"), encoding="utf-8"))
    tl = json.load(open(P("out", "line_starts.json"), encoding="utf-8"))
    order = sorted(cfg["lines"], key=lambda l: tl[l["id"]])
    out = []
    for n, ln in enumerate(order):
        lid, sub = ln["id"], ln["sub"]
        t0, dur = tl[lid], durs[lid]
        t_end = t0 + dur + S.TAIL
        if n + 1 < len(order):
            t_end = min(t_end, tl[order[n + 1]["id"]] - S.MIN_GAP)
        parts = S.split_sub(sub)
        if len(parts) == 1:
            out.append((t0, t_end, sub, lid, 1))
            continue
        k = len(parts[0])
        while sub[k] == " ":
            k += 1
        t_split = S.snap_to_pause(P("tts", f"{lid}.wav"), dur * S.tts_ratio(ln["tts"], sub, k), dur)
        out.append((t0, t0 + t_split, parts[0], lid, 1))
        out.append((t0 + t_split, t_end, parts[1], lid, 2))
    return out


def style(name, size, color, mv):
    return (f"Style: {name},PingFangTC-Medium,{size},{color},{color},{GLOW},&H00000000,"
            f"0,0,0,0,100,100,0,0,1,3,0,2,120,120,{mv},1")


def header(styles):
    return ["[Script Info]", "ScriptType: v4.00+", "PlayResX: 1920", "PlayResY: 1080", "WrapStyle: 2",
            "ScaledBorderAndShadow: yes", "YCbCr Matrix: TV.709", "", "[V4+ Styles]",
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
            "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
            "Alignment, MarginL, MarginR, MarginV, Encoding", *styles, "", "[Events]",
            "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"]


FADE = 0.12   # 和畫面裡的 SubtitleBand 相同：前後沒有相接的字幕在開始前、結束後各淡化 0.12 秒；同一句拆成兩段時直接換字


def faded(spans):
    """spans：[(t0, t1)]（依時間排序、同一軌）。回傳 [(起, 迄, 淡入毫秒, 淡出毫秒)]：
    與前一則相接（迄＝起）時不淡入、與後一則相接時不淡出；淡化的時間加在字幕外側，旁白開口時字幕已完全出現，
    並以兩則之間空檔的一半為上限，相鄰兩則不會同時出現。"""
    out = []
    for i, (a, b) in enumerate(spans):
        gap_in = a - spans[i - 1][1] if i else 9
        gap_out = spans[i + 1][0] - b if i + 1 < len(spans) else 9
        fi = 0 if gap_in < 0.005 else min(FADE, gap_in / 2)
        fo = 0 if gap_out < 0.005 else min(FADE, gap_out / 2)
        out.append((a - fi, b + fo, round(fi * 1000), round(fo * 1000)))
    return out


def dialogue(layer, span, style, lid, text):
    # 蘋方的 ASCII 連字號是 0.6 字寬的減號造形（ESP32-S3、no-shows 會像 ESP32–S3、no–shows），燒入時字間的連字號改用 U+2010（0.33 字寬）；SRT 保留 ASCII
    text = re.sub(r"(?<=\w)-(?=\w)", chr(0x2010), text)
    a, b, fi, fo = span
    fad = f"\\fad({fi},{fo})" if fi or fo else ""
    return f"Dialogue: {layer},{S.ts_ass(a)},{S.ts_ass(b)},{style},{lid},0,0,0,,{{\\blur6{fad}}}{text}"


def main():
    hide = set(json.load(open(P("subs_hide.json"), encoding="utf-8"))["hide"])
    ev = events()
    missing = [(lid, k) for (_, _, _, lid, k) in ev if (lid, k) not in EN]
    if missing:
        raise SystemExit(f"缺少英文字幕：{missing}")
    zh = header([style("ZH", ZH_SIZE, INK, ZH_ONLY_MV)])
    zhen = header([style("ZH", ZH_SIZE, INK, ZH_MV), style("EN", EN_SIZE, SUB, EN_MV)])
    srt_zh, srt_zhen = [], []
    shown = [e for e in ev if not (e[3] in hide or f"{e[3]}.{e[4]}" in hide)]
    zh_span = dict(zip([id(e) for e in shown], faded([(e[0], e[1]) for e in shown])))
    en_span = faded([(e[0], e[1]) for e in ev])
    for i, e in enumerate(ev, 1):
        a, b, text, lid, k = e
        en = EN[(lid, k)]
        if id(e) in zh_span:
            zh.append(dialogue(0, zh_span[id(e)], "ZH", lid, text))
            zhen.append(dialogue(0, zh_span[id(e)], "ZH", lid, text))
        # 英文放在第 1 層：同一層的字幕框重疊時 libass 會把後來的往上推
        zhen.append(dialogue(1, en_span[i - 1], "EN", lid, en))
        srt_zh += [str(i), f"{S.ts_srt(a)} --> {S.ts_srt(b)}", text, ""]
        srt_zhen += [str(i), f"{S.ts_srt(a)} --> {S.ts_srt(b)}", text, en, ""]
        print(f"{lid:4s}.{k} {a:7.2f}-{b:7.2f} {'' if id(e) in zh_span else '（中文不燒入）'}{text} / {en}")
    for name, lines in (("subs_v3_zh.ass", zh), ("subs_v3_zhen.ass", zhen)):
        open(P("out", name), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    for name, lines in (("subs_v3_zh.srt", srt_zh), ("subs_v3_zhen.srt", srt_zhen)):
        open(P("out", name), "w", encoding="utf-8-sig").write("\n".join(lines))
    print(f"{len(ev)} 則")


if __name__ == "__main__":
    main()
