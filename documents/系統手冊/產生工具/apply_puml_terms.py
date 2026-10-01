"""把 corrections.json 中針對圖（puml）的修正與全書統一用語寫回原始碼，並重新產圖。"""
import json, os, re, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import overlap_check as O
JAR = os.path.join(HERE, 'plantuml.jar')
BK = os.path.join(HERE, 'puml_terms_backup')
os.makedirs(BK, exist_ok=True)
items = json.load(open(os.path.join(HERE, 'audit', 'corrections.json'), encoding='utf-8'))
globals_ = [(x['old'], x['new']) for x in items if x.get('global')]
texts, missing = {}, []
def load(p):
    if p not in texts:
        bk = os.path.join(BK, p.replace('/', '__'))
        if not os.path.exists(bk):
            shutil.copy2(p, bk)
        texts[p] = open(p, encoding='utf-8').read()
    return texts[p]
for it in items:
    p = it.get('puml')
    if not p:
        continue
    s = load(p)
    if it.get('lines'):
        lines = s.split('\n')
        done = False
        for n in it['lines']:
            if it['old'] in lines[n - 1]:
                lines[n - 1] = lines[n - 1].replace(it['old'], it['new']); done = True
        if done:
            texts[p] = '\n'.join(lines); continue
    if it['old'] in s:
        texts[p] = s.replace(it['old'], it['new'])
    elif it['new'] not in s:
        missing.append(it)
for p in O.figure_sources():
    s = load(p)
    for o, n in globals_:
        s = s.replace(o, n)
    texts[p] = s
changed = []
for p, s in texts.items():
    if s != open(p, encoding='utf-8').read():
        open(p, 'w', encoding='utf-8').write(s); changed.append(p)
for p in changed:
    src = open(p, encoding='utf-8').read()
    if 'render_class.py' in src:
        subprocess.run([sys.executable, os.path.join(HERE, 'render_class.py'), p], check=True, capture_output=True)
    elif os.path.basename(p).startswith('seq_'):
        subprocess.run([sys.executable, os.path.join(HERE, 'render_seq.py'), p], check=True, capture_output=True)
    else:
        subprocess.run(['java', '-jar', JAR, '-tpng', p], check=True, capture_output=True)
json.dump(changed, open(os.path.join(HERE, 'audit', 'puml_changed.json'), 'w'), ensure_ascii=False, indent=1)
print('changed', len(changed), 'missing', len(missing))
for m in missing: print('MISSING', m['_id'], os.path.basename(m['puml']), '|', m['old'][:50])
