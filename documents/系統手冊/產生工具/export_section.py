"""從手冊取出單一小節（含所屬章標題）成獨立的 docx，並把該節的圖換成新版圖檔，供組員自行併回正式版。

換圖：以原圖檔內容比對備份資料夾中的舊 PNG 找出對應的圖名，換成新版資料夾中同名 PNG；
維持原本的圖高（不影響分頁），寬度依新圖比例調整，超過版心寬度時改以版心寬度為準。

用法：.venv/bin/python export_section.py 手冊.docx 輸出.docx 章標題 節標題 舊圖資料夾[,…] 新圖資料夾[,…]
例：export_section.py 複評版.docx 第6-1節.docx 設計模型 循序圖 old/ v3/,cabdiag/seq/
"""
import os
import re
import sys
from io import BytesIO

import docx
from docx.oxml.ns import qn
from PIL import Image

DROP_TYPES = ('/image', '/hyperlink', '/header', '/footer', '/chart', '/oleObject', '/package')
EMU_PER_CM = 360000


def text_of(el):
    return ''.join(t.text or '' for t in el.iter(qn('w:t')))


def style_of(el):
    st = el.find(qn('w:pPr') + '/' + qn('w:pStyle')) if el.tag == qn('w:p') else None
    return st.get(qn('w:val')) if st is not None else None


def main():
    src, dst, chapter, section, old_dir, new_dirs = sys.argv[1:7]
    new_dirs = new_dirs.split(',')
    doc = docx.Document(src)
    body = doc.element.body
    kids = list(body.iterchildren())
    h1 = [i for i, el in enumerate(kids) if style_of(el) == '1']
    ch = next(i for i in h1 if text_of(kids[i]).strip() == chapter)
    order = h1.index(ch)
    h2 = [i for i, el in enumerate(kids) if style_of(el) == '2' and i > ch]
    sec = next(i for i in h2 if text_of(kids[i]).strip() == section)
    nxt = [i for i in h1 + h2 if i > sec]
    end = min(nxt) if nxt else len(kids) - 1

    page = None
    for el in kids[:ch]:
        m = re.match(rf'^第{order + 1}章{re.escape(chapter)}(\d+)$', text_of(el).strip())
        if m:
            page = int(m.group(1))
    sect = kids[-1]
    keep = {ch} | set(range(sec, end))
    for i, el in enumerate(kids):
        if i not in keep and el is not sect:
            body.remove(el)

    # 章號由標題樣式的多層次清單自動編號：單獨成檔時從原本的章號開始
    num_id = doc.styles.element.xpath('//w:style[@w:styleId="1"]//w:numId/@w:val')[0]
    num = next(n for n in doc.part.numbering_part.element.findall(qn('w:num')) if n.get(qn('w:numId')) == num_id)
    override = num.makeelement(qn('w:lvlOverride'), {qn('w:ilvl'): '0'})
    override.append(override.makeelement(qn('w:startOverride'), {qn('w:val'): str(order + 1)}))
    num.append(override)
    if page:
        pg = sect.find(qn('w:pgNumType'))
        if pg is not None:
            pg.set(qn('w:start'), str(page))

    sec_pr = doc.sections[0]
    max_cx = int(sec_pr.page_width - sec_pr.left_margin - sec_pr.right_margin)
    old = {open(os.path.join(d, f), 'rb').read(): f for d in old_dir.split(',') for f in os.listdir(d) if f.endswith('.png')}
    replaced, missing = [], []
    for drawing in body.iter(qn('w:drawing')):
        blip = drawing.find('.//' + qn('a:blip'))
        if blip is None:
            continue
        part = doc.part.related_parts[blip.get(qn('r:embed'))]
        name = old.get(part.blob)
        if name is None:
            missing.append(part.partname)
            continue
        new_path = next((os.path.join(d, name) for d in new_dirs if os.path.exists(os.path.join(d, name))), None)
        new = open(new_path, 'rb').read()
        ow, oh = Image.open(BytesIO(part.blob)).size
        nw, nh = Image.open(BytesIO(new)).size
        part._blob = new
        ext = drawing.find('.//' + qn('wp:extent'))
        cy = int(ext.get('cy'))
        cx = int(cy * nw / nh)
        if cx > max_cx:
            cx, cy = max_cx, int(max_cx * nh / nw)
        for e in list(drawing.iter(qn('wp:extent'))) + list(drawing.iter(qn('a:ext'))):
            if e.get('cx') is not None:
                e.set('cx', str(cx))
                e.set('cy', str(cy))
        replaced.append((name, round(cx / EMU_PER_CM, 2), round(cy / EMU_PER_CM, 2)))

    used = set()
    for el in body.iter():
        for k, v in el.attrib.items():
            if k.startswith('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'):
                used.add(v)
    for rid, rel in list(doc.part.rels.items()):
        if rid not in used and rel.reltype.endswith(DROP_TYPES):
            del doc.part.rels[rid]
    doc.save(dst)
    print(f'第{order + 1}章「{chapter}」之「{section}」：{end - sec} 個段落與表格，起始頁碼 {page}，換圖 {len(replaced)} 張')
    for r in replaced:
        print('  ', *r)
    if missing:
        print('找不到對應舊圖：', missing)


if __name__ == '__main__':
    main()
