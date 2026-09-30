"""中英雙語字幕（ASS）：延續動畫的卡片語言——半透明白色圓角卡片、Noto Sans TC、品牌霧藍細線。
產生 out/字幕_中英.ass 與 out/字幕_中英.srt"""
import json
from fontTools.ttLib import TTFont
from PIL import ImageFont

import os
FONT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "../../../../savemybook_app/assets/fonts"))
meta = json.load(open("tts/meta.json", encoding="utf-8"))
os.makedirs("out", exist_ok=True)

# ── 版面參數（1920×1080 座標，4K 會自動等比放大）──
ZH_EM, EN_EM = 34, 20            # 中文／英文實際字身大小（px）
ZH_FSP, EN_FSP = 1.0, 0.2        # 字距
GAP = 6                          # 中英行距
PADX, PADY = 26, 13              # 卡片內距
RADIUS = 16
LEFT_X = 112                     # 對齊動畫左側文字欄
BOTTOM = 1056                    # 卡片下緣
ACCENT_W, ACCENT_GAP = 3, 14     # 左側品牌色細線
C_TEXT, C_MUTED, C_BRAND = "151E27", "5B6770", "627D8D"

def ass_size(file, em):
    f = TTFont(f"{FONT_DIR}\\{file}")
    os2 = f["OS/2"]; upem = f["head"].unitsPerEm
    return em * (os2.usWinAscent + os2.usWinDescent) / upem

# 字型：專案 App 同款 Noto Sans TC（改名副本，確保 libass 一定用到正確字重）
ZH_SIZE, EN_SIZE = ZH_EM / .684, EN_EM / .672     # libass 實測：字級 × 0.684 = 字身
fz = ImageFont.truetype("fonts/smb-sub-zh.ttf", ZH_EM)
fe = ImageFont.truetype("fonts/smb-sub-en.ttf", EN_EM)
width = lambda font, s, sp: font.getlength(s) + sp * max(0, len(s) - 1)
TIGHT = ZH_EM * .42
def zh_tagged(s):
    """「」緊排：在「之前、」本身套負字距，並回傳緊排後少掉的寬度"""
    out = []; saved = 0
    for k, ch in enumerate(s):
        nxt = s[k + 1] if k + 1 < len(s) else ""
        if nxt == "「" or ch == "」":
            out.append(f"{{\\fsp{ZH_FSP - TIGHT:.1f}}}{ch}{{\\fsp{ZH_FSP}}}"); saved += TIGHT
        else:
            out.append(ch)
    return "".join(out), saved

# ── 字幕內容：(旁白序號, [(中文, 英文), ...], 版位)；長句拆成兩段依序出現 ──
C, L, R, TR = "center", "left", "center_raised", "top_right"
EN_ONLY_IDX = {0, 3, 24, 25}     # 旁白與畫面中文完全相同 → 只放英文
EN_ONLY_CHUNK = {(19, 0)}         # 單張字幕卡與畫面標題相同（「付款前，再驗證一次」）
EN1_EM, EN1_FSP, C_EN1 = 23, .25, "3A4650"
fe1 = ImageFont.truetype("fonts/smb-sub-en.ttf", EN1_EM)
EN1_SIZE = EN1_EM / .672
FLOW = {5, 6, 7, 8}              # 存書流程：卡片稍微提高，完整蓋住書櫃銘牌
TR_RIGHT, TR_TOP = 1604, 136      # 爭議分析：貼在「AI 分析」面板正上方，右緣對齊面板
FIXED_W = {5: 830, 6: 830}
SUBS = [
    (0, [("二手書交易 難在哪裡？", "Why is trading used books so hard?")], C),
    (1, [("面交怕詐騙 寄送嫌麻煩", "Meeting up feels risky. Shipping is a hassle.")], R),
    (2, [("超過一半的人", "More than half of respondents"),
         ("想要 24 小時自助存取的實體書櫃", "want a physical locker with 24/7 self-service access.")], R),
    (3, [("救「舊」我的書 結合智慧書櫃的二手書交易平台", "SaveMyBook — a used-book marketplace built around smart lockers")], C),
    (4, [("書櫃只用一片 ESP32 就能控制四扇櫃門", "A single ESP32 controls all four locker doors"),
         ("並與伺服器即時同步", "and stays in sync with the server in real time.")], L),
    (5, [("存書只要四步", "Storing a book takes just four steps."),
         ("第一 用 App 掃描書櫃上的 QR Code", "First, scan the locker's QR code with the app.")], L),
    (6, [("第二 輸入螢幕上的數字", "Second, enter the number shown on the screen,"),
         ("並確認你就在書櫃旁", "confirming you're right at the locker.")], L),
    (7, [("第三 指定櫃門自動開啟", "Third, the assigned door unlocks automatically."),
         ("30 秒內放入書籍", "Place your book inside within 30 seconds.")], L),
    (8, [("最後 關上櫃門就完成存書", "Finally, close the door and you're done."),
         ("買家也會同步收到通知", "The buyer is notified instantly.")], L),
    (9, [("從上架到售後 七項 AI 功能全程協助", "Seven AI features help from listing to after-sales.")], L),
    (10, [("拍張照片 AI 就能判斷書況", "Snap a photo, and AI assesses the book's condition,"),
          ("並查詢書目、建議合理售價", "looks up its details, and suggests a fair price.")], L),
    (11, [("規則檢查加上 AI 影像審核", "Rule-based checks plus AI image review"),
          ("雙層把關上架品質", "keep every listing up to standard.")], L),
    (12, [("書籍資料不完整？系統會自動幫你補齊", "Missing book details? The system fills them in for you.")], L),
    (13, [("系統會根據收藏與瀏覽紀錄推薦好書", "Picks based on your favorites and browsing history —"),
          ("每一本都附上理由", "each with a reason why.")], L),
    (14, [("只要說出需求和預算", "Just describe what you need and your budget,"),
          ("AI 書籍顧問就幫你挑書", "and the AI book advisor picks for you.")], L),
    (15, [("有問題？AI 客服立即回覆", "Questions? The AI assistant answers instantly."),
          ("複雜狀況一鍵轉接真人", "Complex issues go to a person in one tap.")], L),
    (16, [("發生爭議時 AI 會比對照片與說明", "In a dispute, AI compares photos and descriptions,"),
          ("整理證據協助管理員裁決", "organizing evidence to help admins decide.")], TR),
    (17, [("AI 用量設有上限 使用前須經同意", "AI usage is capped and requires consent,"),
          ("對話紀錄 90 天後自動刪除", "and chat logs are deleted after 90 days.")], L),
    (18, [("款項先由平台暫管", "Payments are held by the platform"),
          ("取書 24 小時後才撥給賣家", "and released to the seller 24 hours after pickup.")], L),
    (19, [("付款前再驗證一次", "Every payment is verified once more,"),
          ("可以用交易密碼或生物辨識", "by transaction PIN or biometrics.")], L),
    (20, [("偵測到私下交易或詐騙話術時", "When off-platform deals or scam tactics are detected,"),
          ("系統會即時提醒雙方", "both sides are warned right away.")], L),
    (21, [("從 Flutter App、Node.js 後端", "From the Flutter app and Node.js backend"),
          ("到 ESP32 智慧書櫃 一套系統完整串起", "to the ESP32 smart locker — one connected system.")], L),
    (22, [("296 個 API、超過 4,000 項測試全數通過", "296 APIs and 4,000+ tests, all passing,"),
          ("支援五種介面語言", "in five interface languages.")], L),
    (23, [("服務費規劃只收一成", "A planned service fee of just 10% —"),
          ("遠低於委託寄賣的三成五 賣家拿得更多", "far below consignment's 35%, so sellers keep more.")], L),
    (24, [("讓閒置的書 重新流動", "Let idle books circulate again.")], C),
    (25, [("救「舊」我的書", "SaveMyBook")], C),
]

def ts(t):
    h = int(t // 3600); m = int(t % 3600 // 60); s = t % 60
    return f"{h}:{m:02d}:{s:05.2f}"

def rrect(w, h, r):
    k = r * .4477   # 圓角貝茲控制點
    return (f"m {r} 0 l {w - r} 0 b {w - k} 0 {w} {k} {w} {r} l {w} {h - r} b {w} {h - k} {w - k} {h} {w - r} {h} "
            f"l {r} {h} b {k} {h} 0 {h - k} 0 {h - r} l 0 {r} b 0 {k} {k} 0 {r} 0")

def ass_color(hex6): return f"&H{hex6[4:6]}{hex6[2:4]}{hex6[0:2]}&"

events = []; srt = []
RISE = 6
def ev(layer, t0, t1, x, y, tags, text, an=7):
    mv = f"\\move({x:.1f},{y + RISE:.1f},{x:.1f},{y:.1f},0,240)"
    events.append(f"Dialogue: {layer},{ts(t0)},{ts(t1)},Default,,0,0,0,,{{\\an{an}{mv}\\fad(200,160){tags}}}{text}")

for idx, chunks, place in SUBS:
    EN_ONLY = idx in EN_ONLY_IDX
    m = meta[idx]
    t_start, t_end = m["start"], m["end"] + .35
    total = sum(len(z.replace(" ", "")) for z, _ in chunks)
    tcur = t_start
    for j, (zh, en) in enumerate(chunks):
        EN_ONLY = idx in EN_ONLY_IDX or (idx, j) in EN_ONLY_CHUNK
        share = len(zh.replace(" ", "")) / total
        t0 = tcur; t1 = t_end if j == len(chunks) - 1 else t_start + (t_end - t_start) * sum(len(c[0].replace(" ", "")) for c in chunks[:j + 1]) / total
        tcur = t1
        zh_txt, saved = zh_tagged(zh)
        wz, we = width(fz, zh, ZH_FSP) - saved, width(fe, en, EN_FSP)
        if EN_ONLY: wz, we = 0, width(fe1, en, EN1_FSP)
        accent = place in (L, TR)
        inner_x = PADX + (ACCENT_W + ACCENT_GAP if accent else 0)
        W = max(wz, we) + inner_x + PADX
        if idx in FIXED_W: W = max(W, FIXED_W[idx])      # 存書流程前兩步：固定寬度，完整蓋住書櫃銘牌
        H = PADY * 2 + ZH_EM * 1.18 + GAP + EN_EM * 1.25
        if EN_ONLY: H = 14 * 2 + EN1_EM * 1.3
        bottom = BOTTOM - (88 if place == R else 0) - (32 if (EN_ONLY and idx in FLOW) else 0)
        top = bottom - H if place != TR else TR_TOP
        left = (TR_RIGHT - W) if place == TR else (LEFT_X - PADX if accent else 960 - W / 2)
        # 陰影（柔和、偏移 6px）
        ev(0, t0, t1, left, top + 6, f"\\p1\\bord0\\shad0\\blur14\\1c{ass_color('0B1A26')}\\1a&HE8&", rrect(W, H, RADIUS))
        # 卡片
        ev(1, t0, t1, left, top, f"\\p1\\bord0\\shad0\\blur0.6\\1c&HFFFFFF&\\1a&H00&", rrect(W, H, RADIUS))
        # 左側品牌色細線
        if accent:
            ev(2, t0, t1, left + PADX, top + (14 if EN_ONLY else PADY) + 3, f"\\p1\\bord0\\shad0\\1c{ass_color(C_BRAND)}\\1a&H30&", rrect(ACCENT_W, H - (14 if EN_ONLY else PADY) * 2 - 6, 1.5))
        # 文字（以卡片左上角為基準）
        if accent:
            tx = left + inner_x; an = 7
        else:
            tx = 960; an = 8
        if EN_ONLY:
            ev(3, t0, t1, tx, top + 14 - EN1_EM * .1, f"\\fnSMB Sub EN\\fs{EN1_SIZE:.2f}\\fsp{EN1_FSP}\\1c{ass_color(C_EN1)}\\bord0\\shad0", en, an)
            srt.append((t0, t1, zh, en, True)); continue
        ev(3, t0, t1, tx, top + PADY - ZH_EM * .08, f"\\fnSMB Sub ZH\\fs{ZH_SIZE:.2f}\\fsp{ZH_FSP}\\1c{ass_color(C_TEXT)}\\bord0\\shad0", zh_txt, an)
        ev(3, t0, t1, tx, top + PADY + ZH_EM * 1.18 + GAP - EN_EM * .12, f"\\fnSMB Sub EN\\fs{EN_SIZE:.2f}\\fsp{EN_FSP}\\1c{ass_color(C_MUTED)}\\bord0\\shad0", en, an)
        srt.append((t0, t1, zh, en, False))

head = f"""[Script Info]
Title: 救「舊」我的書 中英字幕
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 2
ScaledBorderAndShadow: yes
YCbCr Matrix: TV.709

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,SMB Sub ZH,{ZH_SIZE:.2f},&H00151E27,&H00FFFFFF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
open("out/字幕_中英.ass", "w", encoding="utf-8-sig").write(head + "\n".join(events) + "\n")

def srt_ts(t):
    h = int(t // 3600); m = int(t % 3600 // 60); s = int(t % 60); ms = int(round((t % 1) * 1000))
    if ms == 1000: s += 1; ms = 0
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"
with open("out/字幕_中英.srt", "w", encoding="utf-8-sig") as f:
    for i, (a, b, zh, en, EN_ONLY) in enumerate(srt, 1):
        f.write(f"{i}\n{srt_ts(a)} --> {srt_ts(b)}\n" + (f"{en}\n\n" if EN_ONLY else f"{zh}\n{en}\n\n"))
print(len(srt), "subtitle cards; ZH size", round(ZH_SIZE, 2), "EN size", round(EN_SIZE, 2),
      "max width", round(max(max(width(fz, z, ZH_FSP), width(fe, e, EN_FSP)) for _, cs, _ in SUBS for z, e in cs)))
