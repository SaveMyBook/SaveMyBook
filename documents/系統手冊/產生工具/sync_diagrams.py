"""把本資料夾內手冊用圖同步到專案 Diagrams 資料夾（依檔名對應，只覆蓋內容不同者）。"""
import filecmp, glob, os, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = '/Users/xukaijun/Desktop/SaveMyBook/Diagrams'
src = {}
for pat in ['cabdiag/*/*.p*', 'aidiag/*/*.p*', 'activity/*.p*', 'review/*.p*']:
    for p in glob.glob(os.path.join(HERE, pat)):
        if p.endswith(('.png', '.puml')) and '/_' not in os.path.relpath(p, HERE):
            src.setdefault(os.path.basename(p), []).append(p)
dry = '--dry' in sys.argv
changed = []
for dst in glob.glob(os.path.join(REPO, '*', 'v3', '*')):
    name = os.path.basename(dst)
    cands = src.get(name)
    if not cands:
        continue
    if len(cands) > 1:
        print('AMBIGUOUS', name, cands); continue
    if not filecmp.cmp(cands[0], dst, shallow=False):
        changed.append((cands[0], dst))
        if not dry:
            shutil.copy2(cands[0], dst)
for s, d in changed:
    print(os.path.relpath(s, HERE), '->', os.path.relpath(d, REPO))
print('changed:', len(changed), '(dry)' if dry else '')
