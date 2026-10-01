import random
from docx.oxml.ns import qn

W14 = '{http://schemas.microsoft.com/office/word/2010/wordml}'

def run(doc):
    body = doc.element.body
    seen = set(); fixed = 0
    for el in body.iter():
        for attr in (W14 + 'paraId',):
            v = el.get(attr)
            if v is None: continue
            key = (attr, v)
            if key in seen:
                while True:
                    nv = '%08X' % random.randint(1, 0x7FFFFFFF)
                    if (attr, nv) not in seen: break
                el.set(attr, nv); key = (attr, nv); fixed += 1
            seen.add(key)
    # 重複的書籤：保留第一組，後面複製出來的移除
    ids = set(); removed = 0
    for tag in ('w:bookmarkStart',):
        for el in list(body.iter(qn(tag))):
            bid = el.get(qn('w:id'))
            if bid in ids:
                el.getparent().remove(el); removed += 1
            else:
                ids.add(bid)
    ends = {}
    for el in list(body.iter(qn('w:bookmarkEnd'))):
        bid = el.get(qn('w:id'))
        if bid in ends: el.getparent().remove(el); removed += 1
        else: ends[bid] = el
    # 圖片 docPr id 必須唯一
    dp = set(); dpfix = 0
    mx = max(int(e.get('id')) for e in body.iter(qn('wp:docPr')))
    for e in body.iter(qn('wp:docPr')):
        i = e.get('id')
        if i in dp:
            mx += 1; e.set('id', str(mx)); dpfix += 1
        dp.add(e.get('id'))
    return fixed, removed, dpfix
