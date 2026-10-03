"""最後一次開 Word：手冊更新目錄與圖表目錄後存檔並轉 PDF，系統簡介轉 PDF；輸出於 _render（Word 已授權之資料夾）。
先去掉 updateFields 再以 AppleScript 更新目錄，開檔時不會跳出更新欄位視窗。
用法：word_final.py 手冊.docx 系統簡介.docx → _render/manual.docx、manual.pdf、intro.pdf"""
import os, re, shutil, subprocess, sys, time, zipfile
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_render")
src_manual, src_intro = sys.argv[1], sys.argv[2]
os.makedirs(R, exist_ok=True)
for f in os.listdir(R):
    os.remove(os.path.join(R, f))
manual, intro = os.path.join(R, 'manual.docx'), os.path.join(R, 'intro.docx')
# 去掉開檔時「更新欄位」詢問，改以 AppleScript 更新目錄
with zipfile.ZipFile(src_manual) as zi, zipfile.ZipFile(manual, 'w', zipfile.ZIP_DEFLATED) as zo:
    for item in zi.infolist():
        data = zi.read(item.filename)
        if item.filename == 'word/settings.xml':
            data = re.sub(rb'<w:updateFields[^>]*/>', b'', data)
        zo.writestr(item, data)
shutil.copy(src_intro, intro)

def osa(script, timeout=900):
    r = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, timeout=timeout)
    if r.returncode:
        raise SystemExit(r.stderr)
    return r.stdout.strip()

def open_doc(path, name):
    subprocess.run(['open', '-g', '-a', 'Microsoft Word', path], check=True)
    for _ in range(120):
        time.sleep(5)
        names = subprocess.run(['osascript', '-e', 'tell application "Microsoft Word" to get name of every document'],
                               capture_output=True, text=True, timeout=60).stdout
        if name in names:
            return
    raise SystemExit('Word did not open ' + name)

open_doc(manual, 'manual.docx')
print(osa(f'''with timeout of 1800 seconds
tell application "Microsoft Word"
  set d to document "manual.docx"
  set n to count of tables of contents of d
  repeat with i from 1 to n
    update (table of contents i of d)
  end repeat
  set m to count of tables of figures of d
  repeat with i from 1 to m
    update (table of figures i of d)
  end repeat
  save d
  save as d file name "{R}/manual.pdf" file format format PDF
  close d saving no
  return (n as text) & " TOC, " & (m as text) & " TOF"
end tell
end timeout''', 1900))
open_doc(intro, 'intro.docx')
osa(f'''with timeout of 600 seconds
tell application "Microsoft Word"
  set d to document "intro.docx"
  save as d file name "{R}/intro.pdf" file format format PDF
  close d saving no
end tell
end timeout''')
print(sorted(os.listdir(R)))
