"""附錄二 硬體接線圖：產生 wiring.svg，再以 rsvg-convert 轉成 wiring.png（座標以 220 dpi 像素計，寬 1560 約 18 公分）。
腳位與 savemybook_firmware/README.md、src/pins.h 一致。"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1560, 1500
FONT = 'PingFang TC'
PIN_FS, TITLE_FS, NOTE_FS, TAG_FS = 26, 30, 26, 24
BOX = '#8B1A1A'
DES = '#1F3FBF'
NET = {'+12V': '#C62828', '+5V': '#D35400', '+3V3': '#7B1FA2', 'GND': '#212121'}
SIG = {'relay': '#1565C0', 'spi': '#2E7D32'}
PIN = 20

out = []


def text(x, y, s, size=PIN_FS, anchor='start', color='#000', weight='normal'):
    s = s.replace('&', '&amp;').replace('<', '&lt;')
    out.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" text-anchor="{anchor}" '
               f'dominant-baseline="central" fill="{color}" font-weight="{weight}">{s}</text>')


def line(pts, color='#000', width=3):
    d = ' '.join(f'{x},{y}' for x, y in pts)
    out.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"/>')


def dot(x, y, color):
    out.append(f'<circle cx="{x}" cy="{y}" r="7" fill="{color}"/>')


def rect(x0, y0, x1, y1, color=BOX, width=3, fill='#FFFFFF'):
    out.append(f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" fill="{fill}" stroke="{color}" stroke-width="{width}"/>')


def box(x0, y0, x1, y1, title, left=(), right=()):
    """元件方框：left/right 為 (腳位名稱, y)，腳位線畫在框外 PIN 像素，回傳各腳位端點。"""
    rect(x0, y0, x1, y1)
    text(x0, y0 - 24, title, TITLE_FS, color=DES)
    ends = {}
    for name, y in left:
        line([(x0 - PIN, y), (x0, y)], BOX)
        text(x0 + 12, y, name)
        ends[name] = (x0 - PIN, y)
    for name, y in right:
        line([(x1, y), (x1 + PIN, y)], BOX)
        text(x1 - 12, y, name, anchor='end')
        ends[name] = (x1 + PIN, y)
    return ends


def tag(x, y, net, side):
    """網路標籤：side 為標籤相對於接點之方向（left/right/up/down）。"""
    c = NET[net]
    w, h = len(net) * 15 + 34, 34
    if side in ('left', 'right'):
        s = -1 if side == 'left' else 1
        line([(x, y), (x + s * 20, y)], c)
        tip = x + s * 20
        far = tip + s * w
        body = tip + s * 16
        pts = [(tip, y), (body, y - h / 2), (far, y - h / 2), (far, y + h / 2), (body, y + h / 2)]
        cx = (body + far) / 2
        cy = y
    else:
        s = -1 if side == 'up' else 1
        line([(x, y), (x, y + s * 30)], c)
        tip = y + s * 30
        far = tip + s * (h + 10)
        body = tip + s * 10
        pts = [(x, tip), (x - w / 2, body), (x - w / 2, far), (x + w / 2, far), (x + w / 2, body)]
        cx = x
        cy = (body + far) / 2
    d = ' '.join(f'{px},{py}' for px, py in pts)
    out.append(f'<polygon points="{d}" fill="#FFFFFF" stroke="{c}" stroke-width="3"/>')
    text(cx, cy, net, TAG_FS, 'middle', c, 'bold')


def cap(x, y0, y1, label, color):
    """直立電解電容，正極在上。"""
    m = (y0 + y1) / 2
    line([(x, y0), (x, m - 9)], color)
    line([(x, m + 9), (x, y1)], NET['GND'])
    line([(x - 26, m - 9), (x + 26, m - 9)], '#000', 4)
    out.append(f'<path d="M {x - 26} {m + 15} Q {x} {m + 4} {x + 26} {m + 15}" fill="none" stroke="#000" stroke-width="4"/>')
    text(x - 34, m - 24, '+', PIN_FS, 'middle')
    for i, s in enumerate(label):
        text(x + 38, m - 16 + i * 32, s, PIN_FS, color=DES if i == 0 else '#000')


def diode(cx, y, label):
    """水平二極體，陰極朝左。"""
    out.append(f'<polygon points="{cx + 16},{y - 16} {cx + 16},{y + 16} {cx - 16},{y}" fill="#FFFFFF" stroke="#000" stroke-width="3"/>')
    line([(cx - 16, y - 16), (cx - 16, y + 16)], '#000', 4)
    text(cx, y + 36, label, PIN_FS, 'middle', DES)


# ---------- 電源：12V 供應器 → 保險絲 → 降壓模組 ----------
P, N = 140, 260
psu = box(40, 100, 300, 300, '12V 5A 電源供應器', right=[('+V', P), ('−V', N)])
text(150, 200, 'AC 110V 輸入', PIN_FS, 'middle', '#555')
rect(360, P - 13, 440, P + 13, '#000', 3)
line([(372, P), (428, P)], '#000', 2)
text(400, P - 38, 'F1 2A', PIN_FS, 'middle', DES)
line([psu['+V'], (360, P)], NET['+12V'])
line([(440, P), (760, P)], NET['+12V'])
line([psu['−V'], (760, N)], NET['GND'])
dot(500, P, NET['+12V']); tag(500, P, '+12V', 'up')
dot(500, N, NET['GND']); tag(500, N, 'GND', 'down')
dot(580, P, NET['+12V']); dot(580, N, NET['GND'])
cap(580, P, N, ['C1', '1000µF 25V'], NET['+12V'])
buck = box(780, 100, 1020, 300, 'U4 降壓模組', left=[('IN+', P), ('IN−', N)], right=[('OUT+', P), ('OUT−', N)])
text(900, 192, '12V→5V', PIN_FS, 'middle')
text(900, 228, '輸出調至5.0V', 24, 'middle', '#555')
line([buck['OUT+'], (1300, P)], NET['+5V'])
line([buck['OUT−'], (1300, N)], NET['GND'])
dot(1140, P, NET['+5V']); dot(1140, N, NET['GND'])
cap(1140, P, N, ['C2', '470µF 10V'], NET['+5V'])
dot(1300, P, NET['+5V']); tag(1300, P, '+5V', 'up')
dot(1300, N, NET['GND']); tag(1300, N, 'GND', 'down')

# ---------- 繼電器與電磁鎖 ----------
IN_Y = [640, 690, 740, 790]
CH = [(460 + i * 140, 500 + i * 140) for i in range(4)]
relay = box(760, 420, 1060, 950, 'U3 4路繼電器模組（低電平觸發）',
            left=[('VCC', 470), ('GND', 520)] + [(f'IN{i + 1}', y) for i, y in enumerate(IN_Y)],
            right=sum([[(f'COM{i + 1}', c), (f'NO{i + 1}', n)] for i, (c, n) in enumerate(CH)], []))
tag(*relay['VCC'], '+5V', 'left')
tag(*relay['GND'], 'GND', 'left')
text(775, 850, 'NC1–NC4不接', 24, 'start', '#555')
for i, (c, n) in enumerate(CH):
    tag(*relay[f'COM{i + 1}'], '+12V', 'right')
    a, b = 1170, 1445
    line([relay[f'NO{i + 1}'], (a, n)], NET['+12V'])
    rect(1225, n - 25, 1405, n + 25, BOX, 3)
    text(1315, n, f'電磁鎖 A0{i + 1}', PIN_FS, 'middle')
    line([(a, n), (1225, n)], NET['+12V'])
    line([(1405, n), (b, n)], NET['GND'])
    line([(a, n), (a, n + 52), (b, n + 52), (b, n)], '#000')
    diode(1315, n + 52, f'D{i + 1}')
    dot(a, n, NET['+12V']); dot(b, n, NET['GND'])
    tag(b, n, 'GND', 'right')

# ---------- ESP32-S3 ----------
ESP_R = [('GPIO4', IN_Y[0]), ('GPIO5', IN_Y[1]), ('GPIO6', IN_Y[2]), ('GPIO7', IN_Y[3]),
         ('GPIO10', 860), ('GPIO8', 905), ('GPIO9', 950), ('GPIO11', 995), ('GPIO12', 1040)]
esp = box(200, 600, 560, 1110, 'U1 ESP32-S3 開發板（N16R8）',
          left=[('5V', 660), ('GND', 720), ('3V3', 780)], right=ESP_R)
tag(*esp['5V'], '+5V', 'left')
tag(*esp['GND'], 'GND', 'left')
tag(*esp['3V3'], '+3V3', 'left')
text(380, 1084, 'BOOT鍵長按5秒重設Wi-Fi', 24, 'middle', '#555')
for i in range(4):
    line([esp[f'GPIO{4 + i}'], relay[f'IN{i + 1}']], SIG['relay'])

# ---------- TFT ----------
tft = box(760, 1030, 1060, 1320, 'U2 2.8吋TFT（ILI9341，320×240）',
          left=[('CS', 1080), ('RESET', 1125), ('DC', 1170), ('SDI(MOSI)', 1215), ('SCK', 1260)],
          right=[('VCC', 1080), ('GND', 1125), ('LED', 1170), ('SDO(MISO)', 1260)])
text(910, 1300, '觸控T_*、SD卡腳位不接', 22, 'middle', '#555')
for (src, dst), lane in zip([('GPIO10', 'CS'), ('GPIO8', 'RESET'), ('GPIO9', 'DC'), ('GPIO11', 'SDI(MOSI)'), ('GPIO12', 'SCK')],
                            [720, 690, 660, 630, 600]):
    (x0, y0), (x1, y1) = esp[src], tft[dst]
    line([(x0, y0), (lane, y0), (lane, y1), (x1, y1)], SIG['spi'])
tag(*tft['VCC'], '+5V', 'right')
tag(*tft['GND'], 'GND', 'right')
tag(*tft['LED'], '+3V3', 'right')
x, y = tft['SDO(MISO)']
line([(x, y), (x + 14, y)], BOX)
line([(x + 4, y - 10), (x + 24, y + 10)], '#000', 3); line([(x + 4, y + 10), (x + 24, y - 10)], '#000', 3)

# ---------- 說明 ----------
NOTES = [
    '1. 同名網路標籤（+12V、+5V、+3V3、GND）彼此相連，所有GND共地。',
    '2. D1–D4為1N4007，有白線之一端（陰極）接電磁鎖正極；電磁鎖規格12V 0.6A，通電開鎖。',
    '3. 繼電器使用NO接點，停電或故障時櫃門維持上鎖；JD-VCC跳帽保留。',
    '4. 降壓模組輸出先以電錶調至5.0V，再連接開發板。',
]
for i, s in enumerate(NOTES):
    text(40, 1370 + i * 36, s, NOTE_FS, color='#333')

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>' + ''.join(out) + '</svg>')
open(os.path.join(HERE, 'wiring.svg'), 'w').write(svg)
subprocess.run(['rsvg-convert', '-o', os.path.join(HERE, 'wiring.png'), os.path.join(HERE, 'wiring.svg')], check=True)
print('ok', W, H)
