"""子任務 D2 的 GIF 合成：外框、狀態列、Home 指示條、點擊標記與調色盤沿用 gif_kit.py，
另外畫出捲動時的手指位置（frames.json 的 drags），並以透明像素輸出差異畫格以縮小檔案。

用法：documents/系統手冊/產生工具/.venv/bin/python d2_build.py <畫格資料夾> <輸出.gif> [--fps 25] [--height 900]
      影片：d2_build.py <frames60 資料夾> <輸出.mp4> --video（888×1800、60 fps、H.264，與 gif_kit.build_video 相同編碼）
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gif_kit as kit  # noqa: E402

FINGER_R = 17  # 手指標記半徑（pt）
FADE_IN_S = 0.08
FADE_OUT_S = 0.2
SCENE_CHANGE = 0.5  # 與場景首格的色彩分布差異超過此值（0～2）即視為新場景，改建一套調色盤


def color_distance(a, b):
    """兩格的色彩分布差異：縮小並每色版取 3 位元後比較各色比例，0 為相同、2 為完全不同。"""
    def hist(im):
        small = im.resize((74, 150), Image.BILINEAR).point(lambda v: v & 0xE0)
        total = small.width * small.height
        return {c: n / total for n, c in small.getcolors(maxcolors=total)}
    ha, hb = hist(a), hist(b)
    return sum(abs(ha.get(c, 0) - hb.get(c, 0)) for c in set(ha) | set(hb))


def draw_finger(im, x, y, a):
    """捲動中的手指：與點擊標記同色的半透明圓點加白色外圈，a 為 0～1 的不透明度。"""
    w, _ = im.size
    k = w / kit.SCREEN_W
    ss = 4
    r = FINGER_R * k
    R = int(r + 3 * k) + 2
    size = 2 * R
    patch = Image.new('RGBA', (size * ss, size * ss), (0, 0, 0, 0))
    c, rr = R * ss, r * ss
    ImageDraw.Draw(patch).ellipse((c - rr, c - rr, c + rr, c + rr), fill=kit.SLATE + (round(255 * 0.42 * a),))
    ring = Image.new('RGBA', patch.size, (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((c - rr, c - rr, c + rr, c + rr), outline=(255, 255, 255, round(255 * 0.85 * a)), width=max(1, round(1.6 * k * ss)))
    patch = Image.alpha_composite(patch, ring).resize((size, size), Image.LANCZOS)
    base = im.convert('RGBA')
    layer = Image.new('RGBA', base.size, (0, 0, 0, 0))
    layer.paste(patch, (round(x * k) - R, round(y * k) - R))
    return Image.alpha_composite(base, layer).convert('RGB')


def finger_marks(drags, fps=25):
    """frame -> (x, y, 不透明度)：按下後約 0.08 秒淡入，放開後在原處約 0.2 秒淡出。"""
    fade_in = max(1, round(FADE_IN_S * fps))
    fade_out = max(1, round(FADE_OUT_S * fps))
    marks = {}
    run = []
    for d in drags:
        run.append(d)
        if d.get('phase') == 'up':
            for j, e in enumerate(run):
                marks[e['frame']] = (e['x'], e['y'], min(1.0, (j + 1) / fade_in))
            last = run[-1]
            for j in range(1, fade_out + 1):
                marks.setdefault(last['frame'] + j, (last['x'], last['y'], 1 - j / (fade_out + 1)))
            run = []
    return marks


def build(frames_dir, out_gif, height=900, fps=25, loop_fade=0.4, poster_scale=2):
    with open(os.path.join(frames_dir, 'frames.json'), encoding='utf-8') as f:
        spec = json.load(f)
    statusbar = spec.get('statusbar', True)
    home = spec.get('home', True)
    slot = 1000 / fps
    phone = kit.Phone()
    W, H = phone.size
    out_size = (round(W * height / H), height)

    timeline, starts = [], []
    t = 0.0
    for i, fr in enumerate(spec['frames']):
        starts.append(t)
        n = max(1, round(fr['ms'] / slot))
        timeline.extend([i] * n)
        t += n * slot
    taps = [(starts[tap['frame']], tap['x'], tap['y']) for tap in spec.get('taps', [])]
    fingers = finger_marks(spec.get('drags', []), spec.get('fps', 25))

    cache = {}

    def screen_of(i):
        if i not in cache:
            im = Image.open(os.path.join(frames_dir, spec['frames'][i]['file'])).convert('RGB')
            if im.size != phone.screen_size:
                im = im.resize(phone.screen_size, Image.LANCZOS)
            cache.clear()
            cache[i] = kit.add_system_bars(im, statusbar, home)
        return cache[i]

    finals, keys = [], []
    poster = None
    for k, i in enumerate(timeline):
        now = k * slot
        marks = tuple((x, y, round((now - t0) / kit.TAP_MS, 3)) for t0, x, y in taps if t0 <= now < t0 + kit.TAP_MS)
        finger = fingers.get(i)
        key = (i, marks, finger)
        if keys and keys[-1] == key:
            finals.append(finals[-1])
            continue
        keys.append(key)
        scr = screen_of(i)
        if finger:
            scr = draw_finger(scr, *finger)
        for x, y, p in marks:
            scr = kit.draw_tap(scr, x, y, p)
        big = phone.compose(scr)
        if poster is None:
            poster = big.resize((out_size[0] * poster_scale, out_size[1] * poster_scale), Image.LANCZOS)
        finals.append(big.resize(out_size, Image.LANCZOS))

    merged, durations = [], []
    for f in finals:
        if merged and (f is merged[-1] or ImageChops.difference(f, merged[-1]).getbbox() is None):
            durations[-1] += slot
        else:
            merged.append(f)
            durations.append(slot)

    # 淡回首格：全畫面交叉淡化每格都是整張新圖，以兩倍格長（12.5 fps）輸出，檔案小一半而觀感相同
    if loop_fade and loop_fade > 0:
        n = max(1, round(loop_fade * 1000 / (2 * slot)))
        first, last = merged[0], merged[-1]
        for j in range(1, n + 1):
            merged.append(Image.blend(last, first, j / (n + 1)))
            durations.append(2 * slot)

    # 保留一個調色盤位置給透明色，差異畫格中沒有變動的像素以透明輸出
    # 調色盤與量化沿用 gif_kit：全片共用調色盤、平塗色精確對齊，照片為主的畫格改用照片適用的調色盤。
    # gif_kit 每格各自建調色盤，但連續畫格（例如首頁點擊標記的動畫）若各用一套，靜止的照片會隨格閃爍，
    # 差異畫格也無法以透明像素輸出；這裡改為同一場景的連續照片畫格共用一套。
    palette, protected = kit.build_palette(merged, total=255)
    photo_colors = getattr(kit, 'PHOTO_COLORS', None)
    photo = [bool(photo_colors) and len(f.getcolors(maxcolors=f.width * f.height)) > photo_colors for f in merged]
    scenes, start = [], None
    for i, f in enumerate(merged):
        if not photo[i]:
            start = None
            continue
        if start is None or color_distance(merged[start], f) > SCENE_CHANGE:
            scenes.append([])
            start = i
        scenes[-1].append(i)
    local = {}
    for scene in scenes:
        shared = kit.build_palette([merged[i] for i in scene], exact=32, total=255)
        for i in scene:
            local[i] = shared
    quantized = [kit.quantize_exact(f, *local.get(i, (palette, protected))) for i, f in enumerate(merged)]
    local = len(local)
    scenes_info = scenes
    os.makedirs(os.path.dirname(os.path.abspath(out_gif)), exist_ok=True)
    quantized[0].save(
        out_gif,
        save_all=True,
        append_images=quantized[1:],
        duration=[round(d) for d in durations],
        loop=0,
        optimize=True,
        disposal=1,
    )
    poster.save(os.path.splitext(out_gif)[0] + '_poster.png', optimize=True)
    total = sum(durations) / 1000
    size = os.path.getsize(out_gif)
    print(f'{out_gif}：{total:.2f} 秒、{fps} fps、{out_size[0]}×{out_size[1]}、{len(merged)} 個畫格（{local} 格照片畫格分 {len(scenes)} 個場景各用一套調色盤：{[len(x) for x in scenes]}）、{size / 1024 / 1024:.2f} MB')
    return total, out_size, size


def build_video(frames_dir, out_mp4, fps=60, size=kit.VIDEO_SIZE, loop_fade=0.4, crf=18):
    """與 build() 相同的合成（含捲動手指），輸出 60 fps H.264 MP4 與同尺寸首格 PNG；編碼參數同 gif_kit.build_video，
    另以 setparams 標記色彩原色與轉換特性（只用 -color_primaries／-color_trc 時，ffmpeg 7 輸出仍是 unknown）。"""
    import subprocess
    with open(os.path.join(frames_dir, 'frames.json'), encoding='utf-8') as f:
        spec = json.load(f)
    statusbar = spec.get('statusbar', True)
    home = spec.get('home', True)
    slot = 1000 / fps
    phone = kit.Phone()
    timeline, starts = [], []
    t = 0.0
    for i, fr in enumerate(spec['frames']):
        starts.append(t)
        n = max(1, round(fr['ms'] / slot))
        timeline.extend([i] * n)
        t += n * slot
    taps = [(starts[tap['frame']], tap['x'], tap['y']) for tap in spec.get('taps', [])]
    fingers = finger_marks(spec.get('drags', []), spec.get('fps', fps))

    cache = {}

    def screen_of(i):
        if i not in cache:
            im = Image.open(os.path.join(frames_dir, spec['frames'][i]['file'])).convert('RGB')
            if im.size != phone.screen_size:
                im = im.resize(phone.screen_size, Image.LANCZOS)
            cache.clear()
            cache[i] = kit.add_system_bars(im, statusbar, home)
        return cache[i]

    os.makedirs(os.path.dirname(os.path.abspath(out_mp4)), exist_ok=True)
    w, h = size
    cmd = [
        kit.find_ffmpeg(), '-y', '-loglevel', 'error',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{w}x{h}', '-r', str(fps), '-i', '-',
        '-an', '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,'
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
            marks = tuple((x, y, round((now - t0) / kit.TAP_MS, 4)) for t0, x, y in taps if t0 <= now < t0 + kit.TAP_MS)
            finger = fingers.get(i)
            key = (i, marks, finger)
            if key != last_key:
                scr = screen_of(i)
                if finger:
                    scr = draw_finger(scr, *finger)
                for x, y, p in marks:
                    scr = kit.draw_tap(scr, x, y, p)
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
    bg = kit.video_frame_color(out_mp4, 0.0, (4, 4))
    print(f'{out_mp4}：{count / fps:.2f} 秒、{fps} fps、{w}×{h}、{count} 格、{size_b / 1e6:.2f} MB、背景實測 {bg}（目標 {kit.BG}）')
    return count / fps, size, size_b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('frames_dir')
    ap.add_argument('out_gif')
    ap.add_argument('--fps', type=int, default=25)
    ap.add_argument('--height', type=int, default=900)
    ap.add_argument('--loop-fade', type=float, default=0.4)
    ap.add_argument('--video', action='store_true', help='輸出 60 fps MP4（out_gif 改填 .mp4 路徑）')
    a = ap.parse_args()
    if a.video:
        build_video(a.frames_dir, a.out_gif, fps=a.fps if a.fps != 25 else 60, loop_fade=a.loop_fade)
    else:
        build(a.frames_dir, a.out_gif, a.height, a.fps, a.loop_fade)


if __name__ == '__main__':
    sys.exit(main())
