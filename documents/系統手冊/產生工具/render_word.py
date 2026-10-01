"""以本機 Word 將手冊轉為 PDF 以檢查實際分頁（僅供檢查，不影響手冊）。
須先安裝標楷體（KAIU.TTF）；未安裝時 Word 改用行高較大之字型，分頁會與 Windows 不同。
第一次轉檔時 Word 會要求授權存取 _render 資料夾。用法：render_word.py 手冊.docx → _render/manual.pdf"""
import os, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '_render')


def render(src):
    os.makedirs(OUT, exist_ok=True)
    docx, pdf = os.path.join(OUT, 'manual.docx'), os.path.join(OUT, 'manual.pdf')
    for f in (docx, pdf):
        if os.path.exists(f):
            os.remove(f)
    shutil.copy(src, docx)
    subprocess.run(['open', '-g', '-a', 'Microsoft Word', docx], check=True)
    for _ in range(60):
        time.sleep(5)
        names = subprocess.run(['osascript', '-e', 'tell application "Microsoft Word" to get name of every document'],
                               capture_output=True, text=True).stdout
        if 'manual.docx' in names:
            break
    script = f'''with timeout of 600 seconds
tell application "Microsoft Word"
  set d to document "manual.docx"
  save as d file name "{pdf}" file format format PDF
  close d saving no
end tell
end timeout'''
    subprocess.run(['osascript', '-e', script], check=True)
    return pdf


if __name__ == '__main__':
    print(render(sys.argv[1]))
