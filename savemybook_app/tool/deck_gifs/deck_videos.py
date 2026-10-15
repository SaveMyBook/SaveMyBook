"""複評簡報 12–19 頁的手機示範影片：逐支以 60 fps 錄製（flutter test）→ 合成 MP4 與首格 PNG → 寫出簡報字卡用的 cues.json。
Mac 與 Windows 皆可執行（d2_run.sh 為 Mac 上的 zsh 版本，只處理 d2 四支）。

用法（在 savemybook_app/ 底下執行，Python 需有 Pillow）：
  python tool/deck_gifs/deck_videos.py [--out 輸出資料夾] [影片名稱 ...]
    預設 8 支全部錄製，輸出到 presentation/複評簡報/素材/video_20s/。
    cues.json：{"<影片名稱>": {"duration_ms": ffprobe 量到的總長, "steps": [各步驟開始的影片時間 ms, ...]}}，
    步驟時間取自錄製時 Rec.step()／GifRecorder.step() 記下的畫格；只重錄部分影片時保留其他影片原有的項目。

環境變數：
  DECK_GIF_ROOT  畫格暫存根目錄（底下為 d1/、d2/）；Windows 預設 %LOCALAPPDATA%/SaveMyBook/deck_work，Mac 沿用 d1_rec.dart／d2_rec.dart 內的預設路徑。
  MANUAL_DATA    真實照片資料夾（img/ 由 fetch_photos.py 下載）；Windows 預設 <DECK_GIF_ROOT>/manual_data，Mac 沿用 manual_host.dart 的預設。
  FFMPEG         ffmpeg 執行檔（未設定時依 gif_kit.find_ffmpeg 尋找；ffprobe 取同資料夾）。
ai_dispute 另需佐證照片 <DECK_GIF_ROOT>/d2/evidence_scratch.jpg。

d2 四支錄製前把測試的時區調成「當下即 11:21」（同 d2_run.sh），畫面上的相對時間與時刻才會和狀態列的 11:22 一致；
Windows 上的 Dart 以 C 執行環境的 _tzset 讀取 TZ，格式與 POSIX 相同（GIF-hh:mm 表示 UTC+hh:mm）。
Flutter 須與 pubspec.lock 相符（3.47.x；較舊的版本會把 test_api 等 SDK 套件降版）。
flutter test 會改寫 pubspec.lock 與各平台的 plugin 註冊檔，全部結束後以 git checkout 還原。
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import d2_build  # noqa: E402
import gif_kit as kit  # noqa: E402

FPS = 60
D1 = {'ai_listing_isbn': 'd1_listing_test.dart', 'ai_listing_condition': 'd1_listing_test.dart',
      'ai_review': 'd1_review_test.dart', 'chat_risk': 'd1_chat_test.dart'}
D2 = ['ai_recommend', 'ai_advisor', 'ai_support', 'ai_dispute']
ORDER = ['ai_listing_isbn', 'ai_listing_condition', 'ai_review', 'chat_risk', *D2]
DEFAULT_OUT = os.path.join(APP, '..', 'presentation', '複評簡報', '素材', 'video_20s')
RESTORE = ['pubspec.lock', 'linux/flutter', 'macos/Flutter/GeneratedPluginRegistrant.swift', 'windows/flutter']
MAC_ROOT ='/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/f52b6347-17b0-4b79-95e7-263531604b33/scratchpad/deck_gif'


def gif_tz(target_minutes=11 * 60 + 21):
    """讓測試中「當下」為 11:21 的 TZ 字串（算法同 d2_run.sh）。"""
    now = datetime.datetime.now(datetime.timezone.utc)
    diff = target_minutes - (now.hour * 60 + now.minute)
    if diff > 840:
        diff -= 1440
    if diff <= -720:
        diff += 1440
    sign = '-' if diff >= 0 else '+'
    diff = abs(diff)
    return f'GIF{sign}{diff // 60:02d}:{diff % 60:02d}'


def step_times(frames_dir, fps=FPS):
    """frames.json 的 steps（畫格序號）換算成影片時間（ms），時間軸與 build_video 相同。"""
    with open(os.path.join(frames_dir, 'frames.json'), encoding='utf-8') as f:
        spec = json.load(f)
    slot = 1000 / fps
    starts, t = [], 0.0
    for fr in spec['frames']:
        starts.append(t)
        t += max(1, round(fr['ms'] / slot)) * slot
    return [round(starts[i]) for i in spec.get('steps', [])]


def probe_ms(mp4):
    ffprobe = os.path.join(os.path.dirname(kit.find_ffmpeg()), 'ffprobe' + ('.exe' if os.name == 'nt' else ''))
    out = subprocess.run([ffprobe, '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', mp4],
                         capture_output=True, text=True, check=True)
    return round(float(out.stdout.strip()) * 1000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('names', nargs='*', default=ORDER)
    ap.add_argument('--out', default=DEFAULT_OUT)
    a = ap.parse_args()
    unknown = [n for n in a.names if n not in ORDER]
    if unknown:
        sys.exit(f'未知的影片：{unknown}（可用：{ORDER}）')

    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    if os.name == 'nt':
        env.setdefault('DECK_GIF_ROOT', os.path.join(os.environ['LOCALAPPDATA'], 'SaveMyBook', 'deck_work').replace('\\', '/'))
        env.setdefault('MANUAL_DATA', env['DECK_GIF_ROOT'] + '/manual_data')
    root = env.get('DECK_GIF_ROOT', MAC_ROOT)
    flutter = shutil.which('flutter') or sys.exit('找不到 flutter，請先把 Flutter 的 bin 加入 PATH')
    out_dir = os.path.normpath(a.out)
    os.makedirs(out_dir, exist_ok=True)
    cues_path = os.path.join(out_dir, 'cues.json')
    cues = {}
    if os.path.exists(cues_path):
        with open(cues_path, encoding='utf-8') as f:
            cues = json.load(f)

    try:
        for name in a.names:
            run_env = dict(env)
            if name in D1:
                run_env['D1_FPS'] = str(FPS)
                test, frames = D1[name], f'{root}/d1/{name}/frames{FPS}'
            else:
                run_env['D2_FPS'] = str(FPS)
                run_env['TZ'] = gif_tz()
                test, frames = 'd2_gifs_test.dart', f'{root}/d2/{name}/frames{FPS}'
            print(f'== {name}' + (f'（TZ={run_env["TZ"]}）' if 'TZ' in run_env else ''), flush=True)
            subprocess.run([flutter, 'test', f'tool/deck_gifs/{test}', '--plain-name', name, '-r', 'compact'],
                           cwd=APP, env=run_env, check=True)
            mp4 = os.path.join(out_dir, f'{name}.mp4')
            if name in D1:
                kit.build_video(frames, mp4, fps=FPS)
            else:
                d2_build.build_video(frames, mp4, fps=FPS)
            cues[name] = {'duration_ms': probe_ms(mp4), 'steps': step_times(frames)}
            print(f'   {name}：{cues[name]}', flush=True)
            ordered = {n: cues[n] for n in ORDER if n in cues}
            with open(cues_path, 'w', encoding='utf-8') as f:
                f.write(json.dumps(ordered, ensure_ascii=False, indent=2) + '\n')
    finally:
        # flutter test 的 pub get 會改寫 pubspec.lock 與各平台的 plugin 註冊檔（Windows 上至少換行字元會變），還原成 repo 內的版本
        subprocess.run(['git', 'checkout', '--', *RESTORE], cwd=APP, check=False)
    print(f'cues.json：{cues_path}')


if __name__ == '__main__':
    main()
