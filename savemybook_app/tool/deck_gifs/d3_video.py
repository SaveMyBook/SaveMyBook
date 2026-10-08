"""D3 書櫃手機操作影片：把 60 fps 逐格輸出的 App 畫面以 gif_kit.py 的同一套合成（狀態列、Home 指示條、點擊標記、iPhone 外框、
背景 #F8FAFB）組成 888×1800、60 fps 的 H.264 MP4（無音軌），結尾淡回第一格，另存首格 poster。

用法（需 Pillow；ffmpeg 取自 imageio_ffmpeg）：
  python d3_video.py <畫格資料夾（含 frames.json，fps 60）> <輸出.mp4> [--loop-fade 0.4]
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gif_kit  # noqa: E402

OUT_SIZE = (888, 1800)


def ffmpeg_exe():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return subprocess.check_output([
            '/Users/xukaijun/Desktop/SaveMyBook/presentation/介紹動畫/v2/audio/.venv/bin/python', '-c',
            'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())']).decode().strip()


def build(frames_dir, out_mp4, loop_fade=0.4):
    with open(os.path.join(frames_dir, 'frames.json'), encoding='utf-8') as f:
        spec = json.load(f)
    fps = spec.get('fps', 60)
    statusbar = spec.get('statusbar', True)
    home = spec.get('home', True)
    phone = gif_kit.Phone()
    taps = [(t['ms'], t['x'], t['y']) for t in spec.get('taps', [])]

    cmd = [
        ffmpeg_exe(), '-y', '-loglevel', 'error',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{OUT_SIZE[0]}x{OUT_SIZE[1]}', '-r', str(fps), '-i', '-',
        '-vf', 'scale=out_color_matrix=bt709:out_range=tv',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-r', str(fps), '-crf', '18', '-preset', 'slow',
        # 只給 -color_primaries／-color_trc 時這版 ffmpeg 不會寫進 H.264 VUI，改由 x264 參數標記
        '-x264-params', 'colorprim=bt709:transfer=bt709:colormatrix=bt709',
        '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
        '-movflags', '+faststart', '-an', out_mp4,
    ]
    os.makedirs(os.path.dirname(os.path.abspath(out_mp4)), exist_ok=True)
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)

    cache = {}
    first = last = None
    count = 0
    for i, fr in enumerate(spec['frames']):
        now = i * 1000 / fps
        path = os.path.join(frames_dir, fr['file'])
        with open(path, 'rb') as fh:
            digest = hashlib.md5(fh.read()).hexdigest()
        marks = tuple((x, y, round((now - t0) / gif_kit.TAP_MS, 4)) for t0, x, y in taps if t0 <= now + 0.5 < t0 + gif_kit.TAP_MS)
        key = (digest, marks)
        if key not in cache:
            if len(cache) > 8:
                cache.clear()
            scr = Image.open(path).convert('RGB')
            if scr.size != phone.screen_size:
                scr = scr.resize(phone.screen_size, Image.LANCZOS)
            scr = gif_kit.add_system_bars(scr, statusbar, home)
            for x, y, p in marks:
                scr = gif_kit.draw_tap(scr, x, y, p)
            cache[key] = phone.compose(scr).resize(OUT_SIZE, Image.LANCZOS)
        frame = cache[key]
        if first is None:
            first = frame
            frame.save(os.path.splitext(out_mp4)[0] + '_poster.png', optimize=True)
        last = frame
        proc.stdin.write(frame.tobytes())
        count += 1

    n = round(loop_fade * fps) if loop_fade else 0
    for j in range(1, n + 1):
        proc.stdin.write(Image.blend(last, first, j / (n + 1)).tobytes())
        count += 1
    proc.stdin.close()
    if proc.wait() != 0:
        raise SystemExit('ffmpeg 編碼失敗')
    size = os.path.getsize(out_mp4)
    print(f'{out_mp4}：{count / fps:.3f} 秒（{count} 格）、{fps} fps、{OUT_SIZE[0]}×{OUT_SIZE[1]}、{size / 1024 / 1024:.2f} MB')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('frames_dir')
    ap.add_argument('out_mp4')
    ap.add_argument('--loop-fade', type=float, default=0.4)
    a = ap.parse_args()
    build(a.frames_dir, a.out_mp4, a.loop_fade)


if __name__ == '__main__':
    main()
