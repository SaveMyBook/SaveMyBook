"""用法：a4check.py [--font 12] 圖.png [圖說]（--font 為 puml 的 defaultFontSize，預設 13；ER 圖用 12）
印出放進 Word（A4 直式，內容寬 18cm、圖最高 23cm）後的實際尺寸與字級，並輸出 A4 模擬頁 圖_a4.png。"""
import sys
from PIL import Image, ImageDraw, ImageFont
DPI_SRC = 220          # puml 內 skinparam dpi
FONT_PT = 13           # puml 內 defaultFontSize
if len(sys.argv) > 2 and sys.argv[1] == '--font':
    FONT_PT = float(sys.argv[2]); del sys.argv[1:3]
im = Image.open(sys.argv[1])
w_cm = im.width / DPI_SRC * 2.54; h_cm = im.height / DPI_SRC * 2.54
s = min(1.0, 18 / w_cm, 23 / h_cm)
print(f'{sys.argv[1]}: 原始 {w_cm:.1f}x{h_cm:.1f}cm → Word 中 {w_cm*s:.1f}x{h_cm*s:.1f}cm，字級約 {FONT_PT*s:.1f}pt' + ('  ⚠️ 字太小' if FONT_PT*s < 9 else ''))
if len(sys.argv) > 2:
    DPI=110; cm=lambda x:int(x/2.54*DPI)
    W,H=cm(21),cm(29.7); m=cm(1.5)
    pg=Image.new('RGB',(W,H),'white'); d=ImageDraw.Draw(pg)
    sc = cm(w_cm*s)/im.width
    im2=im.convert('RGB').resize((int(im.width*sc),int(im.height*sc)), Image.LANCZOS)
    x=(W-im2.width)//2; y=m+cm(1); pg.paste(im2,(x,y))
    f=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', int(12/72*DPI))
    tw=d.textlength(sys.argv[2],font=f); d.text(((W-tw)//2, y+im2.height+cm(0.3)), sys.argv[2], fill='black', font=f)
    d.rectangle([m,m,W-m,H-m], outline=(225,225,225))
    pg.save(sys.argv[1].replace('.png','_a4.png'))
