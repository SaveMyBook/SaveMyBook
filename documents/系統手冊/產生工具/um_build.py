"""產生第 12 章使用手冊（單章 docx）：每個操作一個表格，比照參考手冊第 12 章並在最下方加一列說明。

表格：第 1 列為操作路徑（合併儲存格，底色與手冊其他表格標題列相同）、第 2 列為截圖、第 3 列為各截圖小標、
第 4 列為說明（合併儲存格）。表名「表 12-節-表 標題」照手冊格式附 SEQ 與 TC 欄位，可列入表目錄。
章號與起始頁碼沿用原手冊，可直接併回主檔。

用法：.venv/bin/python um_build.py 手冊.docx 輸出.docx [圖高公分]
"""
import copy
import os
import re
import sys
import tempfile

import docx
from docx.oxml.ns import qn
from docx.shared import Cm
from lxml import etree
from PIL import Image

from um_plan import SECTIONS
from um_rename import path_of

TITLE = '使用手冊'
WIDTH = 10194            # 版心寬度（twips）
HEADER_FILL = 'DEE5E8'   # 與手冊其他表格標題列相同
TEXT_SIZE = 24           # 表格內文字 12 pt
IMG_PX = 720             # 放進 Word 的截圖寬度（像素），圖寬約 3.8 公分時約 480 dpi；存 JPEG 以控制檔案大小
DROP_TYPES = ('/image', '/hyperlink', '/header', '/footer', '/chart', '/oleObject', '/package')


def W(tag):
    return qn('w:' + tag)


def el(tag, attrs=None, *children):
    e = etree.Element(W(tag))
    for k, v in (attrs or {}).items():
        e.set(W(k), str(v))
    for c in children:
        e.append(c)
    return e


def text_of(e):
    return ''.join(t.text or '' for t in e.iter(W('t')))


def run(text, bold=False, size=None):
    rpr = el('rPr', None, el('rFonts', {'hint': 'eastAsia'}))
    if bold:
        rpr.append(el('b'))
    if size:
        rpr.append(el('sz', {'val': size}))
        rpr.append(el('szCs', {'val': size}))
    t = el('t')
    t.text = text
    t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    return el('r', None, rpr, t)


def cell_para(align, keep=True):
    ppr = el('pPr', None,
             el('pStyle', {'val': 'a0'}),
             el('numPr', None, el('ilvl', {'val': 0}), el('numId', {'val': 0})))
    if keep:
        ppr.append(el('keepNext'))
    ppr.append(el('spacing', {'line': 240, 'lineRule': 'auto'}))
    ppr.append(el('jc', {'val': align}))
    ppr.append(el('textAlignment', {'val': 'center'}))
    return el('p', None, ppr)


class Ids:
    def __init__(self, doc):
        used = [int(b.get(W('id'))) for b in doc.element.body.iter(W('bookmarkStart'))]
        self.bookmark = max(used + [0]) + 1000
        self.toc = 951000000

    def next(self):
        self.bookmark += 1
        self.toc += 1
        return self.bookmark, f'_Toc{self.toc}'


def caption(label, title, ids):
    """表名：與手冊既有表名相同的結構（SEQ 表 \\h ＋ TC "…" \\f T \\l 1）。"""
    p = el('p', None, el('pPr', None, el('pStyle', {'val': 'afb'}), el('keepNext')))
    for t in ('表', f' {label} ', title):
        p.append(run(t))

    def fld(kind):
        return el('r', None, el('fldChar', {'fldCharType': kind}))

    def instr(text):
        i = el('instrText')
        i.text = text
        i.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
        return el('r', None, i)

    p.extend([fld('begin'), instr(' SEQ '), instr('表'), instr(' \\h '), fld('end')])
    bid, name = ids.next()
    p.extend([fld('begin'), instr(' TC "'), el('bookmarkStart', {'id': bid, 'name': name}),
              instr('表'), instr(f' {label} '), instr(title), el('bookmarkEnd', {'id': bid}),
              instr('" \\f T \\l 1 '), fld('end')])
    return p


def picture(doc, path, height_cm, tmp):
    small = os.path.join(tmp, f'{abs(hash(path))}.jpg')
    if not os.path.exists(small):
        img = Image.open(path).convert('RGB')
        img.resize((IMG_PX, round(img.height * IMG_PX / img.width)), Image.LANCZOS).save(small, quality=92, subsampling=0)
    host = doc.add_paragraph()
    host.add_run().add_picture(small, height=Cm(height_cm))
    r = host._p.find(W('r'))
    host._p.getparent().remove(host._p)
    return r


def build_table(doc, path_text, images, desc, height_cm, tmp):
    n = len(images)
    col = WIDTH // n
    tbl = el('tbl', None, el('tblPr', None,
                             el('tblStyle', {'val': 'afa'}),
                             el('tblW', {'w': WIDTH, 'type': 'dxa'}),
                             el('jc', {'val': 'center'}),
                             el('tblLayout', {'type': 'fixed'}),
                             el('tblLook', {'val': '04A0', 'firstRow': 1, 'lastRow': 0, 'firstColumn': 1,
                                            'lastColumn': 0, 'noHBand': 0, 'noVBand': 1})))
    tbl.append(el('tblGrid', None, *[el('gridCol', {'w': col}) for _ in range(n)]))

    def row(height=None):
        trpr = el('trPr', None, el('cantSplit'))
        if height:
            trpr.append(el('trHeight', {'val': height}))
        tr = el('tr', None, trpr)
        tbl.append(tr)
        return tr

    def cell(tr, span, paras, fill=None):
        tcpr = el('tcPr', None, el('tcW', {'w': col * span, 'type': 'dxa'}))
        if span > 1:
            tcpr.append(el('gridSpan', {'val': span}))
        if fill:
            tcpr.append(el('shd', {'val': 'clear', 'color': 'auto', 'fill': fill}))
        tcpr.append(el('vAlign', {'val': 'center'}))
        tr.append(el('tc', None, tcpr, *paras))

    p = cell_para('center')
    p.append(run(path_text, bold=True, size=TEXT_SIZE))
    cell(row(397), n, [p], HEADER_FILL)

    tr = row()
    for src, _ in images:
        p = cell_para('center')
        p.append(picture(doc, src, height_cm, tmp))
        cell(tr, 1, [p])

    tr = row(397)
    for _, cap in images:
        p = cell_para('center')
        p.append(run(cap, size=TEXT_SIZE))
        cell(tr, 1, [p])

    p = cell_para('both', keep=False)
    p.append(run(desc, size=TEXT_SIZE))
    cell(row(397), n, [p])
    return tbl


def heading2(text, page_break):
    ppr = el('pPr', None, el('pStyle', {'val': '2'}))
    if page_break:
        ppr.append(el('pageBreakBefore'))
    p = el('p', None, ppr)
    p.append(run(text))
    return p


def main():
    src, dst = sys.argv[1:3]
    height_cm = float(sys.argv[3]) if len(sys.argv) > 3 else 8.3
    doc = docx.Document(src)
    body = doc.element.body
    kids = list(body.iterchildren())

    heads = [i for i, e in enumerate(kids) if e.tag == W('p') and e.find(W('pPr') + '/' + W('pStyle')) is not None
             and e.find(W('pPr') + '/' + W('pStyle')).get(W('val')) == '1']
    start = next(i for i in heads if text_of(kids[i]).strip() == TITLE)
    order = heads.index(start)
    page = None
    for e in kids[:start]:
        m = re.match(rf'^第{order + 1}章{TITLE}(\d+)$', text_of(e).strip())
        if m:
            page = int(m.group(1))
    sect = kids[-1]
    for i, e in enumerate(kids):
        if i != start and e is not sect:
            body.remove(e)

    num_id = doc.styles.element.xpath('//w:style[@w:styleId="1"]//w:numId/@w:val')[0]
    num = next(x for x in doc.part.numbering_part.element.findall(W('num')) if x.get(W('numId')) == num_id)
    override = el('lvlOverride', {'ilvl': 0}, el('startOverride', {'val': order + 1}))
    num.append(override)
    if page:
        sect.find(W('pgNumType')).set(W('start'), str(page))

    ids = Ids(doc)
    count = 0
    with tempfile.TemporaryDirectory() as tmp:
        for si, (title, tables) in enumerate(SECTIONS, 1):
            sect.addprevious(heading2(title, page_break=si > 1))
            for ti, (name, path_text, images, desc) in enumerate(tables, 1):
                files = [(path_of(si, ti, cap), cap) for _, cap in images]
                sect.addprevious(caption(f'{order + 1}-{si}-{ti}', name, ids))
                sect.addprevious(build_table(doc, path_text, files, desc, height_cm, tmp))
                count += 1
            # 表格後的空段落：Word 規定表格之後須接段落，也避免相鄰兩表黏在一起
            sect.addprevious(el('p', None, el('pPr', None, el('spacing', {'before': 0, 'after': 0, 'line': 120, 'lineRule': 'exact'}))))

        used = set()
        for e in body.iter():
            for k, v in e.attrib.items():
                if k.startswith('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'):
                    used.add(v)
        for rid, rel in list(doc.part.rels.items()):
            if rid not in used and rel.reltype.endswith(DROP_TYPES):
                del doc.part.rels[rid]
        doc.save(dst)
    print(f'第{order + 1}章「{TITLE}」：{len(SECTIONS)} 節、{count} 個表，圖高 {height_cm} 公分，起始頁碼 {page}')


if __name__ == '__main__':
    main()
