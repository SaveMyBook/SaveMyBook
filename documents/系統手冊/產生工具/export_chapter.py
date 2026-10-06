"""從手冊取出單一章節成獨立的 docx（保留樣式、頁面設定、頁尾與註腳），供組員自行併回正式版。
可同時把 5-3 活動圖換成 activity/ 內最新的圖（--activity）。

用法：.venv/bin/python export_chapter.py 手冊.docx 輸出.docx 需求模型 [--activity]
"""
import re
import sys

import docx
from docx.oxml.ns import qn

from doctools import png_size

HEADING1 = '1'
DROP_TYPES = ('/image', '/hyperlink', '/header', '/footer', '/chart', '/oleObject', '/package')


def text_of(el):
    return ''.join(t.text or '' for t in el.iter(qn('w:t')))


def is_h1(el):
    st = el.find(qn('w:pPr') + '/' + qn('w:pStyle')) if el.tag == qn('w:p') else None
    return st is not None and st.get(qn('w:val')) == HEADING1


def chapter_range(kids, title):
    heads = [i for i, el in enumerate(kids) if is_h1(el)]
    start = next(i for i in heads if text_of(kids[i]).strip() == title)
    later = [i for i in heads if i > start]
    return start, (later[0] if later else len(kids) - 1), heads.index(start)


def replace_activity(doc, body):
    """5-3 各活動圖：換圖檔；像素尺寸改變時維持原本的圖高，寬度依比例調整。"""
    import os
    act = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'activity')
    done = 0
    for p in body.iter(qn('w:p')):
        m = re.match(r'^圖 5-3-(\d+) ', text_of(p))
        if not m:
            continue
        pic = p.getprevious()
        blip = pic.find('.//' + qn('a:blip')) if pic is not None else None
        if blip is None:
            continue
        png = os.path.join(act, f'uc{int(m.group(1)):02d}.png')
        part = doc.part.related_parts[blip.get(qn('r:embed'))]
        old = part.blob
        new = open(png, 'rb').read()
        if old == new:
            continue
        from io import BytesIO
        from PIL import Image
        ow, oh = Image.open(BytesIO(old)).size
        nw, nh = png_size(png)
        part._blob = new
        if (ow, oh) != (nw, nh):
            ext = pic.find('.//' + qn('wp:extent'))
            cy = int(ext.get('cy'))
            cx = int(cy * nw / nh)
            for e in list(pic.iter(qn('wp:extent'))) + list(pic.iter(qn('a:ext'))):
                if e.get('cx') is not None:
                    e.set('cx', str(cx))
                    e.set('cy', str(cy))
        done += 1
    return done


def main():
    src, dst, title = sys.argv[1:4]
    doc = docx.Document(src)
    body = doc.element.body
    kids = list(body.iterchildren())
    start, end, order = chapter_range(kids, title)

    # 章號由標題樣式的多層次清單自動編號：單獨成檔時第一章從原本的章號開始
    page = None
    for el in kids[:start]:
        m = re.match(rf'^第{order + 1}章{re.escape(title)}(\d+)$', text_of(el).strip())
        if m:
            page = int(m.group(1))
    sect = kids[-1]
    for i, el in enumerate(kids):
        if i < start or (end <= i < len(kids) - 1):
            body.remove(el)

    num_id = doc.styles.element.xpath('//w:style[@w:styleId="1"]//w:numId/@w:val')[0]
    numbering = doc.part.numbering_part.element
    num = next(n for n in numbering.findall(qn('w:num')) if n.get(qn('w:numId')) == num_id)
    override = num.makeelement(qn('w:lvlOverride'), {qn('w:ilvl'): '0'})
    override.append(override.makeelement(qn('w:startOverride'), {qn('w:val'): str(order + 1)}))
    num.append(override)
    if page:
        pg = sect.find(qn('w:pgNumType'))
        if pg is not None:
            pg.set(qn('w:start'), str(page))

    replaced = replace_activity(doc, body) if '--activity' in sys.argv else 0

    used = set()
    for el in body.iter():
        for k, v in el.attrib.items():
            if k.startswith('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'):
                used.add(v)
    for rid, rel in list(doc.part.rels.items()):
        if rid not in used and rel.reltype.endswith(DROP_TYPES):
            del doc.part.rels[rid]
    doc.save(dst)
    print(f'第{order + 1}章「{title}」：保留 {end - start} 個段落與表格，起始頁碼 {page}，換圖 {replaced} 張')


if __name__ == '__main__':
    main()
