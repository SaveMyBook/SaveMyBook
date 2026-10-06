"""附錄二 硬體接線圖：產生 wiring.svg，再以 rsvg-convert 轉成 wiring.png（座標以 220 dpi 像素計，寬 1560 約 18 公分）。
腳位與 savemybook_firmware/README.md、src/pins.h 一致（含門磁 GPIO39–42 與背光 GPIO13）。"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1560, 1800
FONT = 'PingFang TC'
PIN_FS, TITLE_FS, NOTE_FS, TAG_FS = 26, 30, 26, 24
BOX = '#8B1A1A'
DES = '#1F3FBF'
NET = {'+24V': '#880E4F', '+12V': '#C62828', '+5V': '#D35400', '+3V3': '#7B1FA2', 'GND': '#212121'}
SIG = {'relay': '#1565C0', 'spi': '#2E7D32', 'door': '#00838F'}
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


# ---------- 電源：24V 供應器 → 保險絲 → 7812（12V，電磁鎖）→ 7805（5V，控制電路） ----------
P, N = 140, 260


def regulator(x0, x1, title, label):
    """三端穩壓 IC：IN 在左、OUT 在右、GND 由下方接到地線。"""
    ends = box(x0, 100, x1, 215, title, left=[('IN', P)], right=[('OUT', P)])
    text((x0 + x1) / 2, 172, label, PIN_FS, 'middle')
    text((x0 + x1) / 2, 200, 'GND', 22, 'middle', '#555')
    gx = (x0 + x1) / 2
    line([(gx, 215), (gx, N)], NET['GND'])
    dot(gx, N, NET['GND'])
    return ends


psu = box(40, 100, 260, 300, '24V 3A 電源供應器', right=[('+V', P), ('−V', N)])
text(130, 200, 'AC 110V 輸入', PIN_FS, 'middle', '#555')
rect(285, P - 13, 345, P + 13, '#000', 3)
line([(295, P), (335, P)], '#000', 2)
text(318, P + 36, 'F1 2A', PIN_FS, 'middle', DES)
line([psu['+V'], (285, P)], NET['+24V'])
line([(345, P), (610, P)], NET['+24V'])
line([psu['−V'], (1460, N)], NET['GND'])
dot(410, P, NET['+24V']); dot(410, N, NET['GND'])
cap(410, P, N, ['C1', '1000µF 50V'], NET['+24V'])
dot(330, N, NET['GND']); tag(330, N, 'GND', 'down')
u4 = regulator(630, 800, 'U4 7812', '24V→12V')
line([u4['OUT'], (950, P)], NET['+12V'])
dot(880, P, NET['+12V']); tag(880, P, '+12V', 'up')
u6 = regulator(970, 1150, 'U6 7805', '12V→5V')
line([u6['OUT'], (1440, P)], NET['+5V'])
dot(1220, P, NET['+5V']); dot(1220, N, NET['GND'])
cap(1220, P, N, ['C2', '470µF 10V'], NET['+5V'])
dot(1440, P, NET['+5V']); tag(1440, P, '+5V', 'up')
dot(1440, N, NET['GND']); tag(1440, N, 'GND', 'down')

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
         ('GPIO10', 860), ('GPIO8', 905), ('GPIO9', 950), ('GPIO11', 995), ('GPIO12', 1040), ('GPIO13', 1085)]
# 門磁腳位依右側排針實際順序（G42 在上）排列，接線才不會交叉
ESP_DOOR = [('GPIO42', 880), ('GPIO41', 925), ('GPIO40', 970), ('GPIO39', 1015)]
esp = box(200, 600, 560, 1180, 'U1 ESP32-S3 開發板（N16R8）',
          left=[('5V', 660), ('GND', 720), ('3V3', 780)] + ESP_DOOR, right=ESP_R)
tag(*esp['5V'], '+5V', 'left')
tag(*esp['GND'], 'GND', 'left')
tag(*esp['3V3'], '+3V3', 'left')
text(380, 1150, 'BOOT鍵長按5秒重設Wi-Fi', 24, 'middle', '#555')
for i in range(4):
    line([esp[f'GPIO{4 + i}'], relay[f'IN{i + 1}']], SIG['relay'])

# ---------- TFT ----------
tft = box(760, 1030, 1060, 1340, 'U2 2.8吋TFT（ST7789，320×240）',
          left=[('CS', 1075), ('RESET', 1115), ('DC', 1155), ('SDI(MOSI)', 1195), ('SCK', 1235), ('LED', 1275)],
          right=[('VCC', 1075), ('GND', 1115), ('SDO(MISO)', 1235)])
text(910, 1315, '觸控T_*、SD卡腳位不接', 22, 'middle', '#555')
for (src, dst), lane in zip([('GPIO10', 'CS'), ('GPIO8', 'RESET'), ('GPIO9', 'DC'), ('GPIO11', 'SDI(MOSI)'), ('GPIO12', 'SCK'),
                             ('GPIO13', 'LED')],
                            [735, 705, 675, 645, 615, 590]):
    (x0, y0), (x1, y1) = esp[src], tft[dst]
    line([(x0, y0), (lane, y0), (lane, y1), (x1, y1)], SIG['spi'])
tag(*tft['VCC'], '+5V', 'right')
tag(*tft['GND'], 'GND', 'right')
x, y = tft['SDO(MISO)']
line([(x, y), (x + 14, y)], BOX)
line([(x + 4, y - 10), (x + 24, y + 10)], '#000', 3); line([(x + 4, y + 10), (x + 24, y - 10)], '#000', 3)

# ---------- 微動開關（門磁） ----------
DOOR_Y = [1300, 1345, 1390, 1435]
door = box(200, 1260, 560, 1520, 'U5 微動開關×4（門磁）',
           left=[(f'OUT A0{i + 1}', y) for i, y in enumerate(DOOR_Y)],
           right=[('VCC', 1330), ('GND', 1390)])
text(540, 1472, 'MATRIX MS-004V3', 22, 'end', '#555')
text(540, 1500, '門關上時壓下', 22, 'end', '#555')
tag(*door['VCC'], '+3V3', 'right')
tag(*door['GND'], 'GND', 'right')
for i, lane in enumerate([160, 140, 120, 100]):
    (x0, y0), (x1, y1) = esp[f'GPIO{39 + i}'], door[f'OUT A0{i + 1}']
    line([(x0, y0), (lane, y0), (lane, y1), (x1, y1)], SIG['door'])

# ---------- 說明 ----------
NOTES = [
    '1. 同名網路標籤（+12V、+5V、+3V3、GND）彼此相連，所有GND共地。',
    '2. D1–D4為1N4007，有白線之一端（陰極）接電磁鎖正極；電磁鎖規格12V 0.6A，通電開鎖。',
    '3. 繼電器使用NO接點，停電或故障時櫃門維持上鎖；JD-VCC跳帽保留。',
    '4. U4、U6須加散熱片；IN、OUT腳位旁各接0.33µF、0.1µF電容；C1耐壓須35V以上。',
    '5. 微動開關模組VCC接3V3（不可接5V），四個模組共用3V3與GND；反相OUT不接。',
    '6. 螢幕LED由GPIO13以PWM調整亮度，螢幕模組須有背光電晶體（Q1）。',
]
for i, s in enumerate(NOTES):
    text(40, 1570 + i * 36, s, NOTE_FS, color='#333')

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>' + ''.join(out) + '</svg>')
open(os.path.join(HERE, 'wiring.svg'), 'w').write(svg)
subprocess.run(['rsvg-convert', '-o', os.path.join(HERE, 'wiring.png'), os.path.join(HERE, 'wiring.svg')], check=True)
print('ok', W, H)
