"""複評簡報用的手機操作 GIF 合成工具：把 Flutter 測試逐格輸出的 App 畫面加上狀態列、Home 指示條、點擊標記與 iPhone 外框，
以 25 fps 輸出 GIF（相同的連續畫格合併成一格並加長時間），另存首格 PNG。

用法（Python 需有 Pillow，可用 documents/系統手冊/產生工具/.venv/bin/python）：
  python gif_kit.py build <畫格資料夾> <輸出.gif> [--height 900] [--fps 25] [--loop-fade 0.4] [--no-statusbar] [--no-home]
  python gif_kit.py sheet <輸出.gif> <總覽.png> [--step 0.2] [--cols 10]
      逐格檢查用：每 step 秒取一格、半尺寸拼成總覽，格子下方標示秒數。
  python gif_kit.py video <畫格資料夾> <輸出.mp4> [--fps 60] [--loop-fade 0.4] [--no-statusbar] [--no-home]
      同一套合成輸出 888×1800 的 H.264 MP4（yuv420p、BT.709、crf 18、無音軌）與同尺寸首格 PNG；畫格建議以 60 fps 錄製。
      ffmpeg 依序取環境變數 FFMPEG、PATH、介紹動畫音訊 venv 的 imageio_ffmpeg。
  python gif_kit.py vsheet <輸出.mp4> <總覽.png> [--step 0.2] [--cols 10]   影片逐格總覽（半尺寸）
  python gif_kit.py vstrip <輸出.mp4> <輸出.png> <秒數> [--count 6]          某秒起連續數格原尺寸並排（檢查轉場）

畫格資料夾內容：
  frames.json
    {
      "frames": [{"file": "00000.png", "ms": 40}, ...],   依序的 App 畫面，ms 為該畫面停留的毫秒數（40 的倍數，25 fps 一格 40 ms）
      "taps": [{"frame": 12, "x": 196.5, "y": 410}, ...],  點擊標記：從第 frame 張畫面開始出現，x、y 為 393×852 pt 的 App 座標
      "statusbar": true,                                   選填，false 時不補狀態列（例如畫面本身是全螢幕相機）
      "home": true                                         選填，false 時不畫 Home 指示條
    }
  *.png：App 畫面，寬高為 393×852 pt 的整數倍（建議 2 倍：786×1704），不含狀態列與 Home 指示條。

輸出：GIF 高 900 px（含外框與背景，背景純色 #F8FAFB）、同名的 *_poster.png（首格，2 倍解析度）。
顏色：全片共用一組調色盤且不混色（避免閃爍），大面積平塗色以原色填入；照片占滿畫面的畫格（例如全螢幕看圖）改用該格自己的調色盤。
逐格錄製的 Dart 寫法可參考同資料夾的 d1_rec.dart（Rec.play／tap／hold、slideKeyboard、IosNumberPad）。
"""
import argparse
import json
import os
import sys
from collections import Counter

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

BG = (0xF8, 0xFA, 0xFB)
SLATE = (0x5B, 0x74, 0x86)
SCREEN_W, SCREEN_H = 393, 852

# iPhone 外框（單位 pt，比例比照 presentation/介紹動畫/v2/src/three/phone.ts 的 6.3 吋 iPhone Pro）
BEZEL_X = 16.0
BEZEL_Y = 18.75
OUTER_R = 66.6
SCREEN_R = 57.0
METAL = 4.0
MARGIN = 14.0
PHONE_W = SCREEN_W + 2 * BEZEL_X
PHONE_H = SCREEN_H + 2 * BEZEL_Y
CANVAS_W = PHONE_W + 2 * MARGIN
CANVAS_H = PHONE_H + 2 * MARGIN
ISLAND = (125.0, 36.5, 11.0)  # 寬、高、距螢幕頂端
# 側邊按鍵：(左 -1／右 1, 距機身頂端, 長度)
BUTTONS = [(-1, 180.0, 36.0), (-1, 247.0, 67.0), (-1, 324.0, 67.0), (1, 210.0, 103.0), (1, 466.0, 52.0)]

STATUS_SRC = '/Users/xukaijun/Desktop/SaveMyBook/documents/使用手冊截圖/6. 加入購物車與結帳/表12-6-1 購物車.PNG'
STATUS_BAND = 60      # 狀態列高度（pt）
STATUS_MOON = (85, 107)  # 勿擾模式月亮圖示的橫向範圍（pt），移除
STATUS_BG_LUMA = 50

TAP_MS = 400
PHOTO_COLORS = 36000  # 畫格顏色數超過此值視為照片為主
SCALE = 2  # 合成解析度（每 pt 幾 px）


def rounded_mask(size, box, radius, ss=4):
    """抗鋸齒圓角矩形遮罩：先以 ss 倍畫再縮小。box 與 radius 單位為 px。"""
    w, h = size
    big = Image.new('L', (w * ss, h * ss), 0)
    x0, y0, x1, y1 = box
    ImageDraw.Draw(big).rounded_rectangle((x0 * ss, y0 * ss, x1 * ss - 1, y1 * ss - 1), radius=radius * ss, fill=255)
    return big.resize(size, Image.LANCZOS)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def metal_fill(size):
    """鈦金屬灰：左上亮、右下暗，中段一道反光。"""
    w, h = size
    stops = [(0.0, (206, 212, 217)), (0.28, (164, 173, 180)), (0.5, (196, 203, 209)), (0.72, (143, 152, 160)), (1.0, (178, 186, 193))]
    grad = Image.new('RGB', (256, 1))
    for i in range(256):
        t = i / 255
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                grad.putpixel((i, 0), lerp(c0, c1, (t - t0) / (t1 - t0)))
                break
    # 對角漸層：先做水平漸層再旋轉
    diag = int((w * w + h * h) ** 0.5) + 2
    band = grad.resize((diag, diag), Image.BILINEAR).rotate(-62, resample=Image.BILINEAR)
    left = (diag - w) // 2
    top = (diag - h) // 2
    return band.crop((left, top, left + w, top + h))


class Phone:
    def __init__(self, scale=SCALE):
        self.s = s = scale
        self.size = (round(CANVAS_W * s), round(CANVAS_H * s))
        W, H = self.size
        px = lambda v: v * s  # noqa: E731
        ox, oy = px(MARGIN), px(MARGIN)
        pw, ph = px(PHONE_W), px(PHONE_H)

        base = Image.new('RGB', self.size, BG)
        # 柔和陰影
        shadow = Image.new('L', self.size, 0)
        # 陰影須在畫布邊緣前完全淡掉，GIF 邊緣才會與投影片背景同色
        ImageDraw.Draw(shadow).rounded_rectangle((ox + px(8), oy + px(14), ox + pw - px(8), oy + ph - px(2)), radius=px(OUTER_R), fill=64)
        shadow = shadow.filter(ImageFilter.GaussianBlur(px(4.5)))
        base.paste((40, 52, 62), (0, 0), shadow)

        metal = metal_fill(self.size)
        darker = Image.new('RGB', self.size, (112, 122, 131))
        # 側邊按鍵（略凸出機身）
        for side, top, length in BUTTONS:
            x0 = ox - px(2.6) if side < 0 else ox + pw - px(1.0)
            box = (x0, oy + px(top), x0 + px(3.6), oy + px(top + length))
            m = rounded_mask(self.size, box, px(1.8))
            base.paste(darker, (0, 0), m)
            inner = rounded_mask(self.size, (box[0] + px(0.6), box[1] + px(0.6), box[2] - px(0.6), box[3] - px(0.6)), px(1.4))
            base.paste(metal, (0, 0), inner)
        # 機身外緣與金屬框
        outer = rounded_mask(self.size, (ox, oy, ox + pw, oy + ph), px(OUTER_R))
        base.paste(darker, (0, 0), outer)
        rim = rounded_mask(self.size, (ox + px(0.8), oy + px(0.8), ox + pw - px(0.8), oy + ph - px(0.8)), px(OUTER_R - 0.8))
        base.paste(metal, (0, 0), rim)
        glass = rounded_mask(self.size, (ox + px(METAL), oy + px(METAL), ox + pw - px(METAL), oy + ph - px(METAL)), px(OUTER_R - METAL))
        base.paste((10, 12, 15), (0, 0), glass)
        self.base = base

        sx, sy = ox + px(BEZEL_X), oy + px(BEZEL_Y)
        self.screen_box = (round(sx), round(sy), round(sx + px(SCREEN_W)), round(sy + px(SCREEN_H)))
        sw, sh = self.screen_box[2] - self.screen_box[0], self.screen_box[3] - self.screen_box[1]
        self.screen_size = (sw, sh)
        self.screen_mask = rounded_mask((sw, sh), (0, 0, sw, sh), px(SCREEN_R))
        iw, ih, itop = ISLAND
        self.island_mask = rounded_mask((sw, sh), ((sw - px(iw)) / 2, px(itop), (sw + px(iw)) / 2, px(itop + ih)), px(ih / 2))

    def compose(self, screen):
        """screen 為 screen_size 大小的 RGB 畫面。"""
        out = self.base.copy()
        sw, sh = self.screen_size
        scr = screen.copy()
        scr.paste((2, 3, 4), (0, 0), self.island_mask)
        out.paste(scr, self.screen_box[:2], self.screen_mask)
        return out


_status_mask_cache = {}


def status_mask(width):
    if width not in _status_mask_cache:
        src = Image.open(STATUS_SRC).convert('L')
        k = src.width / SCREEN_W
        band = src.crop((0, 0, src.width, round(STATUS_BAND * k)))
        mask = band.point(lambda v: max(0, min(255, round((v - STATUS_BG_LUMA) * 255 / (255 - STATUS_BG_LUMA)))))
        ImageDraw.Draw(mask).rectangle((round(STATUS_MOON[0] * k), 0, round(STATUS_MOON[1] * k), mask.height), fill=0)
        scale = width / SCREEN_W
        _status_mask_cache[width] = mask.resize((width, round(STATUS_BAND * scale)), Image.LANCZOS)
    return _status_mask_cache[width]


def luma(im, box):
    small = im.crop(box).convert('L').resize((40, 8))
    data = list(small.get_flattened_data()) if hasattr(small, "get_flattened_data") else list(small.getdata())
    return sum(data) / len(data)


def add_system_bars(im, statusbar=True, home=True):
    w, h = im.size
    k = w / SCREEN_W
    if statusbar:
        mask = status_mask(w)
        top = luma(im, (0, 0, w, mask.height))
        im.paste((255, 255, 255) if top < 150 else (0, 0, 0), (0, 0), mask)
    if home:
        bottom = luma(im, (round(100 * k), h - round(20 * k), w - round(100 * k), h - round(2 * k)))
        pill = (255, 255, 255) if bottom < 110 else (0, 0, 0)
        ss = 4
        pw, ph = round(134 * k), round(5 * k)
        patch = Image.new('L', (pw * ss, ph * ss), 0)
        ImageDraw.Draw(patch).rounded_rectangle((0, 0, pw * ss - 1, ph * ss - 1), radius=ph * ss / 2, fill=255)
        patch = patch.resize((pw, ph), Image.LANCZOS)
        im.paste(pill, ((w - pw) // 2, h - round(13 * k)), patch)
    return im


def draw_tap(im, x, y, p):
    """點擊標記：石板藍半透明圓點放大後淡出，外圈白線讓深色按鈕上也看得到。p 為 0～1 的進度。"""
    w, h = im.size
    k = w / SCREEN_W
    ease = 1 - (1 - p) ** 3
    r = (15 + 13 * ease) * k
    fill_a = 0.5 * (1 - p) ** 1.4
    ring_a = 0.9 * (1 - p) ** 1.2
    ss = 4
    R = int(r + 3 * k) + 2
    size = 2 * R
    patch = Image.new('RGBA', (size * ss, size * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(patch)
    c = R * ss
    rr = r * ss
    d.ellipse((c - rr, c - rr, c + rr, c + rr), fill=SLATE + (round(255 * fill_a),))
    ring = Image.new('RGBA', patch.size, (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((c - rr, c - rr, c + rr, c + rr), outline=(255, 255, 255, round(255 * ring_a)), width=max(1, round(1.6 * k * ss)))
    patch = Image.alpha_composite(patch, ring).resize((size, size), Image.LANCZOS)
    px, py = round(x * k) - R, round(y * k) - R
    base = im.convert('RGBA')
    layer = Image.new('RGBA', base.size, (0, 0, 0, 0))
    layer.paste(patch, (px, py))
    return Image.alpha_composite(base, layer).convert('RGB')


def build_palette(frames, exact=96, total=256):
    """全片共用調色盤：大面積的平塗色直接採用（不偏色），其餘以 median cut 補足。"""
    sample = frames if len(frames) <= 48 else [frames[round(i * (len(frames) - 1) / 47)] for i in range(48)]
    counts = Counter()
    for f in sample:
        colors = f.getcolors(maxcolors=f.width * f.height)
        for n, c in colors:
            counts[c] += n
    flat = [c for c, n in counts.most_common(exact) if n > 400]
    cols = 8
    rows = (len(sample) + cols - 1) // cols
    fw, fh = sample[0].size
    montage = Image.new('RGB', (fw * cols, fh * rows), BG)
    for i, f in enumerate(sample):
        montage.paste(f, ((i % cols) * fw, (i // cols) * fh))
    rest = montage.quantize(colors=total - len(flat), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = rest.getpalette()[: 3 * (total - len(flat))]
    mc = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]
    palette = list(dict.fromkeys(flat + mc))[:total]
    img = Image.new('P', (1, 1))
    flat_list = [v for c in palette for v in c]
    img.putpalette(flat_list + [0] * (768 - len(flat_list)))
    protected = list(dict.fromkeys([c for c, _ in counts.most_common(24)] + [BG]))
    return img, [(c, palette.index(c)) for c in protected if c in palette]


def quantize_exact(frame, palette, protected):
    """Pillow 以 4 階一格的快取找最近色，平塗色可能被換成相近的另一色（背景會差 1～3 階而與投影片接不齊）；
    大面積平塗色改以遮罩直接填入原色。"""
    q = frame.quantize(palette=palette, dither=Image.Dither.NONE)
    r, g, b = frame.split()
    for color, index in protected:
        tables = [[255 if v == c else 0 for v in range(256)] for c in color]
        mask = ImageChops.multiply(ImageChops.multiply(r.point(tables[0]), g.point(tables[1])), b.point(tables[2]))
        if mask.getbbox():
            q.paste(index, (0, 0), mask)
    return q


def build(frames_dir, out_gif, height=900, fps=25, loop_fade=0.4, statusbar=None, home=None, poster_scale=2):
    with open(os.path.join(frames_dir, 'frames.json'), encoding='utf-8') as f:
        spec = json.load(f)
    statusbar = spec.get('statusbar', True) if statusbar is None else statusbar
    home = spec.get('home', True) if home is None else home
    slot = 1000 / fps
    phone = Phone()
    W, H = phone.size
    out_size = (round(W * height / H), height)

    # 時間軸：每格 slot 毫秒
    timeline = []
    starts = []
    t = 0.0
    for i, fr in enumerate(spec['frames']):
        starts.append(t)
        n = max(1, round(fr['ms'] / slot))
        timeline.extend([i] * n)
        t += n * slot
    taps = []
    for tap in spec.get('taps', []):
        t0 = starts[tap['frame']] if 'frame' in tap else tap['ms']
        taps.append((t0, tap['x'], tap['y']))

    cache = {}

    def screen_of(i):
        if i not in cache:
            im = Image.open(os.path.join(frames_dir, spec['frames'][i]['file'])).convert('RGB')
            if im.size != phone.screen_size:
                im = im.resize(phone.screen_size, Image.LANCZOS)
            cache.clear()
            cache[i] = add_system_bars(im, statusbar, home)
        return cache[i]

    finals = []
    poster = None
    keys = []
    for k, i in enumerate(timeline):
        now = k * slot
        marks = tuple((x, y, round((now - t0) / TAP_MS, 3)) for t0, x, y in taps if t0 <= now < t0 + TAP_MS)
        key = (i, marks)
        if keys and keys[-1] == key:
            finals.append(finals[-1])
            continue
        keys.append(key)
        scr = screen_of(i)
        for x, y, p in marks:
            scr = draw_tap(scr, x, y, p)
        big = phone.compose(scr)
        if poster is None:
            poster = big.resize((out_size[0] * poster_scale, out_size[1] * poster_scale), Image.LANCZOS)
        finals.append(big.resize(out_size, Image.LANCZOS))

    if loop_fade and loop_fade > 0:
        n = max(1, round(loop_fade * 1000 / slot))
        first, last = finals[0], finals[-1]
        for j in range(1, n + 1):
            finals.append(Image.blend(last, first, j / (n + 1)))

    # 合併相同的連續畫格
    merged, durations = [], []
    for f in finals:
        if merged and (f is merged[-1] or ImageChops.difference(f, merged[-1]).getbbox() is None):
            durations[-1] += slot
        else:
            merged.append(f)
            durations.append(slot)

    palette, protected = build_palette(merged)
    quantized = []
    local = 0
    for f in merged:
        # 照片占滿畫面的畫格（例如全螢幕看圖）改用該格自己的調色盤，避免照片色階斷層
        if len(f.getcolors(maxcolors=f.width * f.height)) > PHOTO_COLORS:
            quantized.append(quantize_exact(f, *build_palette([f], exact=32)))
            local += 1
        else:
            quantized.append(quantize_exact(f, palette, protected))
    os.makedirs(os.path.dirname(os.path.abspath(out_gif)), exist_ok=True)
    quantized[0].save(
        out_gif,
        save_all=True,
        append_images=quantized[1:],
        duration=[round(d) for d in durations],
        loop=0,
        optimize=False,
        disposal=1,
    )
    poster_path = os.path.splitext(out_gif)[0] + '_poster.png'
    poster.save(poster_path, optimize=True)
    total = sum(durations) / 1000
    size = os.path.getsize(out_gif)
    print(f'{out_gif}：{total:.2f} 秒、{fps} fps、{out_size[0]}×{out_size[1]}、{len(merged)} 個畫格（{local} 格用自己的調色盤）、{size / 1024 / 1024:.2f} MB')
    return total, out_size, size


def sheet(gif, out_png, step=0.2, cols=10):
    im = Image.open(gif)
    frames, times = [], []
    t = 0
    try:
        while True:
            frames.append(im.convert('RGB'))
            times.append(t)
            t += im.info.get('duration', 40)
            im.seek(im.tell() + 1)
    except EOFError:
        pass
    total = t
    picks = []
    s = 0.0
    while s * 1000 < total:
        idx = max(i for i, tt in enumerate(times) if tt <= s * 1000)
        picks.append((s, frames[idx]))
        s = round(s + step, 3)
    fw, fh = frames[0].width // 2, frames[0].height // 2
    rows = (len(picks) + cols - 1) // cols
    label_h = 22
    out = Image.new('RGB', (cols * (fw + 6), rows * (fh + label_h + 6)), 'white')
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 16)
    except OSError:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(out)
    for n, (s, f) in enumerate(picks):
        x, y = (n % cols) * (fw + 6), (n // cols) * (fh + label_h + 6)
        out.paste(f.resize((fw, fh), Image.LANCZOS), (x, y))
        d.text((x + 4, y + fh + 2), f'{s:.1f}s', fill=(200, 0, 0), font=font)
    out.save(out_png)
    print(f'{out_png}：{len(picks)} 格，總長 {total / 1000:.2f} 秒')


# ───────────── 影片（60 fps MP4）─────────────

VIDEO_SIZE = (888, 1800)
FFMPEG_VENV_PY = '/Users/xukaijun/Desktop/SaveMyBook/presentation/介紹動畫/v2/audio/.venv/bin/python'


def find_ffmpeg():
    """ffmpeg 執行檔：環境變數 FFMPEG、PATH，或介紹動畫音訊 venv 內 imageio_ffmpeg 附的版本。"""
    import shutil
    import subprocess
    if os.environ.get('FFMPEG'):
        return os.environ['FFMPEG']
    found = shutil.which('ffmpeg')
    if found:
        return found
    out = subprocess.run([FFMPEG_VENV_PY, '-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())'],
                         capture_output=True, text=True, check=True)
    return out.stdout.strip()


def build_video(frames_dir, out_mp4, fps=60, size=VIDEO_SIZE, loop_fade=0.4, statusbar=None, home=None, crf=18):
    """與 build() 相同的合成（外框、狀態列、Home 指示條、點擊標記、結尾淡回首格），輸出 H.264 MP4（yuv420p、BT.709、無音軌）
    與同尺寸的首格 PNG。frames.json 的 ms 可為小數（60 fps 一格約 16.667 ms）；停留畫面直接重複，交給編碼壓縮。"""
    import subprocess
    with open(os.path.join(frames_dir, 'frames.json'), encoding='utf-8') as f:
        spec = json.load(f)
    statusbar = spec.get('statusbar', True) if statusbar is None else statusbar
    home = spec.get('home', True) if home is None else home
    slot = 1000 / fps
    phone = Phone()

    timeline, starts = [], []
    t = 0.0
    for i, fr in enumerate(spec['frames']):
        starts.append(t)
        n = max(1, round(fr['ms'] / slot))
        timeline.extend([i] * n)
        t += n * slot
    taps = [(starts[tap['frame']] if 'frame' in tap else tap['ms'], tap['x'], tap['y']) for tap in spec.get('taps', [])]

    cache = {}

    def screen_of(i):
        if i not in cache:
            im = Image.open(os.path.join(frames_dir, spec['frames'][i]['file'])).convert('RGB')
            if im.size != phone.screen_size:
                im = im.resize(phone.screen_size, Image.LANCZOS)
            cache.clear()
            cache[i] = add_system_bars(im, statusbar, home)
        return cache[i]

    os.makedirs(os.path.dirname(os.path.abspath(out_mp4)), exist_ok=True)
    w, h = size
    cmd = [
        find_ffmpeg(), '-y', '-loglevel', 'error',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{w}x{h}', '-r', str(fps), '-i', '-',
        # 只給 -color_primaries 等輸出參數時，濾鏡輸出的畫格屬性會蓋掉標記（原色與轉換曲線變成 unknown），須以 setparams 標在畫格上
        '-an', '-vf', 'scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,format=yuv420p,'
                      'setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv',
        '-c:v', 'libx264', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', str(crf),
        '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
        '-r', str(fps), '-movflags', '+faststart', out_mp4,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    first = last = None
    last_key = None
    count = 0
    try:
        for k, i in enumerate(timeline):
            now = k * slot
            marks = tuple((x, y, round((now - t0) / TAP_MS, 4)) for t0, x, y in taps if t0 <= now < t0 + TAP_MS)
            key = (i, marks)
            if key != last_key:
                scr = screen_of(i)
                for x, y, p in marks:
                    scr = draw_tap(scr, x, y, p)
                last = phone.compose(scr).resize(size, Image.LANCZOS)
                last_key = key
                if first is None:
                    first = last
            proc.stdin.write(last.tobytes())
            count += 1
        if loop_fade and loop_fade > 0:
            n = max(1, round(loop_fade * 1000 / slot))
            for j in range(1, n + 1):
                proc.stdin.write(Image.blend(last, first, j / (n + 1)).tobytes())
                count += 1
    finally:
        proc.stdin.close()
        proc.wait()
    if proc.returncode != 0:
        raise RuntimeError(f'ffmpeg 失敗（{proc.returncode}）')
    first.save(os.path.splitext(out_mp4)[0] + '_poster.png', optimize=True)
    size_b = os.path.getsize(out_mp4)
    bg = video_frame_color(out_mp4, 0.0, (4, 4))
    print(f'{out_mp4}：{count / fps:.2f} 秒、{fps} fps、{w}×{h}、{count} 格、{size_b / 1e6:.2f} MB（10^6 bytes）、'
          f'背景實測 {bg}（目標 {BG}）')
    return count / fps, size, size_b


def video_frames(mp4, t, count=1, scale=1.0):
    """從影片 t 秒起取 count 個連續畫格（以 BT.709 解碼為 RGB）。"""
    import subprocess
    import tempfile
    # 不加 accurate_rnd 時 swscale 的快速路徑會偏暗 2～3 階，量背景色會誤判
    vf = 'scale=in_color_matrix=bt709:in_range=tv:flags=accurate_rnd+full_chroma_int'
    if scale != 1.0:
        vf = f'scale=iw*{scale}:ih*{scale}:in_color_matrix=bt709:in_range=tv:flags=lanczos+accurate_rnd+full_chroma_int'
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([find_ffmpeg(), '-loglevel', 'error', '-ss', f'{t:.4f}', '-i', mp4, '-frames:v', str(count),
                        '-vf', vf, '-pix_fmt', 'rgb24', os.path.join(tmp, 'f%04d.png')], check=True)
        return [Image.open(os.path.join(tmp, n)).convert('RGB') for n in sorted(os.listdir(tmp))]


def video_frame_color(mp4, t, xy):
    return video_frames(mp4, t)[0].getpixel(xy)


def video_sheet(mp4, out_png, step=0.2, cols=10):
    """逐格檢查用：每 step 秒取一格、半尺寸拼成總覽。"""
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([find_ffmpeg(), '-loglevel', 'error', '-i', mp4,
                        '-vf', f'fps={1 / step},scale=iw/2:ih/2:in_color_matrix=bt709:in_range=tv:flags=lanczos+accurate_rnd+full_chroma_int', '-pix_fmt', 'rgb24',
                        os.path.join(tmp, 'f%04d.png')], check=True)
        picks = [Image.open(os.path.join(tmp, n)).convert('RGB') for n in sorted(os.listdir(tmp))]
    fw, fh = picks[0].size
    rows = (len(picks) + cols - 1) // cols
    label_h = 22
    out = Image.new('RGB', (cols * (fw + 6), rows * (fh + label_h + 6)), 'white')
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 16)
    except OSError:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(out)
    for n, f in enumerate(picks):
        x, y = (n % cols) * (fw + 6), (n // cols) * (fh + label_h + 6)
        out.paste(f, (x, y))
        d.text((x + 4, y + fh + 2), f'{n * step:.1f}s', fill=(200, 0, 0), font=font)
    out.save(out_png)
    print(f'{out_png}：{len(picks)} 格')


def video_strip(mp4, out_png, t, count=6):
    """轉場檢查用：t 秒起連續 count 格原尺寸並排。"""
    frames = video_frames(mp4, t, count)
    w, h = frames[0].size
    out = Image.new('RGB', (len(frames) * (w + 8) - 8, h), 'white')
    for n, f in enumerate(frames):
        out.paste(f, (n * (w + 8), 0))
    out.save(out_png)
    print(f'{out_png}：{t:.3f} 秒起 {len(frames)} 格')


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)
    v = sub.add_parser('video')
    v.add_argument('frames_dir')
    v.add_argument('out_mp4')
    v.add_argument('--fps', type=int, default=60)
    v.add_argument('--loop-fade', type=float, default=0.4)
    v.add_argument('--no-statusbar', action='store_true')
    v.add_argument('--no-home', action='store_true')
    vs = sub.add_parser('vsheet')
    vs.add_argument('mp4')
    vs.add_argument('out_png')
    vs.add_argument('--step', type=float, default=0.2)
    vs.add_argument('--cols', type=int, default=10)
    vt = sub.add_parser('vstrip')
    vt.add_argument('mp4')
    vt.add_argument('out_png')
    vt.add_argument('t', type=float)
    vt.add_argument('--count', type=int, default=6)
    b = sub.add_parser('build')
    b.add_argument('frames_dir')
    b.add_argument('out_gif')
    b.add_argument('--height', type=int, default=900)
    b.add_argument('--fps', type=int, default=25)
    b.add_argument('--loop-fade', type=float, default=0.4)
    b.add_argument('--no-statusbar', action='store_true')
    b.add_argument('--no-home', action='store_true')
    s = sub.add_parser('sheet')
    s.add_argument('gif')
    s.add_argument('out_png')
    s.add_argument('--step', type=float, default=0.2)
    s.add_argument('--cols', type=int, default=10)
    a = ap.parse_args()
    if a.cmd == 'build':
        build(a.frames_dir, a.out_gif, a.height, a.fps, a.loop_fade,
              statusbar=False if a.no_statusbar else None, home=False if a.no_home else None)
    elif a.cmd == 'video':
        build_video(a.frames_dir, a.out_mp4, a.fps, loop_fade=a.loop_fade,
                    statusbar=False if a.no_statusbar else None, home=False if a.no_home else None)
    elif a.cmd == 'vsheet':
        video_sheet(a.mp4, a.out_png, a.step, a.cols)
    elif a.cmd == 'vstrip':
        video_strip(a.mp4, a.out_png, a.t, a.count)
    else:
        sheet(a.gif, a.out_png, a.step, a.cols)


if __name__ == '__main__':
    sys.exit(main())
