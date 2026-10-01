"""補強初評意見用的共用函式：比照第一、二章既有段落、表格與圖說的格式複製產生新內容。"""
import copy
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm
from doctools import W, text_of, set_para, make_run, tcs, new_picture_para

TOTAL_DXA = 10194


def body_children(doc):
    return list(doc.element.body.iterchildren())


def heading1(doc, title):
    for el in body_children(doc):
        if el.tag == W('p') and _style(el) == '1' and text_of(el).strip() == title:
            return el
    raise KeyError(title)


def _style(p):
    st = p.find(W('pPr') + '/' + W('pStyle'))
    return st.get(W('val')) if st is not None else None


def chapter_range(doc, title, next_title):
    kids = body_children(doc)
    a = kids.index(heading1(doc, title))
    b = kids.index(heading1(doc, next_title))
    return kids[a:b]


def para(els, prefix):
    hits = [e for e in els if e.tag == W('p') and text_of(e).startswith(prefix)]
    if len(hits) != 1:
        raise KeyError(f'{prefix}: {len(hits)} matches')
    return hits[0]


def table_after(el):
    nxt = el.getnext()
    while nxt is not None and nxt.tag != W('tbl'):
        nxt = nxt.getnext()
    return nxt


def replace_in(el, old, new):
    ts = list(el.iter(W('t')))
    full = ''.join(t.text or '' for t in ts)
    k = full.find(old)
    if k < 0:
        raise KeyError(f'not found: {old}')
    end, pos, first = k + len(old), 0, True
    for t in ts:
        txt = t.text or ''
        a, b = pos, pos + len(txt)
        pos = b
        if b <= k or a >= end:
            continue
        s0, s1 = max(k, a) - a, min(end, b) - a
        t.text = txt[:s0] + (new if first else '') + txt[s1:]
        t.set(qn('xml:space'), 'preserve')
        first = False


def clone_para(template, text):
    p = copy.deepcopy(template)
    for b in list(p.iter(W('bookmarkStart'))) + list(p.iter(W('bookmarkEnd'))):
        b.getparent().remove(b)
    set_para(p, text)
    return p


def set_num(p, num_id):
    ppr = p.find(W('pPr'))
    num = ppr.find(W('numPr'))
    num.find(W('numId')).set(W('val'), str(num_id))


def new_num(doc, like_num_id):
    """與既有編號同格式、自 1 重新起算的編號（每個新小節的「1. 2. 3.」各自從 1 開始）。"""
    numbering = doc.part.numbering_part.element
    nums = numbering.findall(W('num'))
    src = [n for n in nums if n.get(W('numId')) == str(like_num_id)][0]
    abstract = src.find(W('abstractNumId')).get(W('val'))
    nid = max(int(n.get(W('numId'))) for n in nums) + 1
    num = OxmlElement('w:num')
    num.set(W('numId'), str(nid))
    a = OxmlElement('w:abstractNumId'); a.set(W('val'), abstract); num.append(a)
    lo = OxmlElement('w:lvlOverride'); lo.set(W('ilvl'), '0')
    so = OxmlElement('w:startOverride'); so.set(W('val'), '1'); lo.append(so)
    num.append(lo)
    numbering.append(num)
    return nid


def _ppr(p):
    ppr = p.find(W('pPr'))
    if ppr is None:
        ppr = OxmlElement('w:pPr'); p.insert(0, ppr)
    return ppr


def _insert_ordered(ppr, el, after_tags):
    """依 OOXML 的 pPr 子元素順序插入（pStyle、keepNext、keepLines、pageBreakBefore…）。"""
    anchor = None
    for tag in after_tags:
        x = ppr.find(W(tag))
        if x is not None:
            anchor = x
    if anchor is not None:
        anchor.addnext(el)
    else:
        ppr.insert(0, el)


def keep_next(p):
    ppr = _ppr(p)
    if ppr.find(W('keepNext')) is None:
        _insert_ordered(ppr, OxmlElement('w:keepNext'), ['pStyle'])


def page_break_before(p):
    ppr = _ppr(p)
    if ppr.find(W('pageBreakBefore')) is None:
        _insert_ordered(ppr, OxmlElement('w:pageBreakBefore'), ['pStyle', 'keepNext', 'keepLines'])


class Templates:
    """自原稿第一、二章擷取的格式樣板（在任何修改之前擷取）。"""

    def __init__(self, doc):
        ch2 = chapter_range(doc, '營運計畫', '系統規格')
        ch1 = chapter_range(doc, '前言', '營運計畫')
        self.h2 = copy.deepcopy(para(ch2, '商業模式－Business model'))
        self.sub = copy.deepcopy(para(ch2, '技術可行性'))
        self.bullet = copy.deepcopy(para(ch2, '前端開發：'))
        self.body = copy.deepcopy(para(ch2, '根據表2-2-1'))
        self.table_cap = copy.deepcopy(para(ch2, '表 2-2-1 '))
        self.fig_cap = copy.deepcopy(para(ch1, '圖 1-2-3 '))
        img = para(ch1, '圖 1-2-3 ').getprevious()
        assert img.find('.//' + W('drawing')) is not None
        self.image = copy.deepcopy(img)
        grid = table_after(para(ch1, '表 1-2-1 '))
        rows = grid.findall(W('tr'))
        self.hdr_tc = copy.deepcopy(tcs(rows[0])[1])
        self.body_tc = copy.deepcopy(tcs(rows[1])[0])
        self.mark_tc = copy.deepcopy(tcs(rows[1])[1])
        self.tbl_pr = copy.deepcopy(grid.find(W('tblPr')))
        self.hdr_trpr = copy.deepcopy(rows[0].find(W('trPr')))
        self.body_trpr = copy.deepcopy(rows[1].find(W('trPr')))
        self.run_rpr = copy.deepcopy(tcs(rows[1])[0].find('.//' + W('r')).find(W('rPr')))


def fill_cell(tc, lines, rpr, jc=None):
    """儲存格改為多行文字；段落格式沿用樣板第一段，字型固定用表格內文字型（標楷體 14 點）。"""
    if isinstance(lines, str):
        lines = lines.split('\n')
    ps = tc.findall(W('p'))
    ppr = copy.deepcopy(ps[0].find(W('pPr')))
    if jc is not None:
        j = ppr.find(W('jc'))
        if j is None:
            j = OxmlElement('w:jc'); ppr.append(j)
        j.set(W('val'), jc)
    for p in ps:
        tc.remove(p)
    for line in lines:
        p = OxmlElement('w:p')
        p.append(copy.deepcopy(ppr))
        p.append(make_run(rpr, line))
        tc.append(p)


def _cell(tpl, width_pct, lines, rpr, jc):
    tc = copy.deepcopy(tpl)
    tcpr = tc.find(W('tcPr'))
    for tag in ('noWrap', 'tcBorders', 'hideMark'):
        x = tcpr.find(W(tag))
        if x is not None:
            tcpr.remove(x)
    w = tcpr.find(W('tcW'))
    w.set(W('w'), str(round(width_pct * 50))); w.set(W('type'), 'pct')
    fill_cell(tc, lines, rpr, jc)
    return tc


def build_table(T, rows, widths, align=None, header_rows=1):
    """rows：每列為字串或字串串列（多行）；widths：各欄百分比；align：各欄內文對齊（both／center）。
    整張表不跨頁：表名與各列設「與下段同頁」，列不可跨頁分割。"""
    assert abs(sum(widths) - 100) < 0.5
    align = align or ['both'] * len(widths)
    tbl = OxmlElement('w:tbl')
    tbl.append(copy.deepcopy(T.tbl_pr))
    grid = OxmlElement('w:tblGrid')
    for w in widths:
        g = OxmlElement('w:gridCol'); g.set(W('w'), str(round(TOTAL_DXA * w / 100))); grid.append(g)
    tbl.append(grid)
    for i, row in enumerate(rows):
        tr = OxmlElement('w:tr')
        trpr = copy.deepcopy(T.hdr_trpr if i < header_rows else T.body_trpr)
        h = trpr.find(W('trHeight'))
        if h is not None:
            trpr.remove(h)
        cs = OxmlElement('w:cantSplit'); trpr.append(cs)
        if i < header_rows:
            th = OxmlElement('w:tblHeader'); trpr.append(th)
        tr.append(trpr)
        for j, val in enumerate(row):
            tpl = T.hdr_tc if i < header_rows else T.body_tc
            jc = 'center' if i < header_rows else align[j]
            tr.append(_cell(tpl, widths[j], val, T.run_rpr, jc))
        tbl.append(tr)
    trs = tbl.findall(W('tr'))
    if len(trs) <= 14:
        for tr in trs[:-1]:
            for p in tr.iter(W('p')):
                keep_next(p)
    return tbl


class Writer:
    """依序在錨點之後插入段落、表格與圖。"""

    def __init__(self, doc, T, anchor):
        self.doc, self.T, self.cur = doc, T, anchor
        self.sub_num = None

    def _put(self, el):
        self.cur.addnext(el)
        self.cur = el
        return el

    def h2(self, text):
        self.sub_num = new_num(self.doc, 5)
        return self._put(clone_para(self.T.h2, text))

    def sub(self, text):
        p = clone_para(self.T.sub, text)
        set_num(p, self.sub_num)
        keep_next(p)
        return self._put(p)

    def bullet(self, text):
        return self._put(clone_para(self.T.bullet, text))

    def body(self, text):
        return self._put(clone_para(self.T.body, text))

    def table(self, caption, rows, widths, align=None):
        cap = clone_para(self.T.table_cap, caption)
        keep_next(cap)
        self._put(cap)
        return self._put(build_table(self.T, rows, widths, align))

    def figure(self, png, caption, max_w=18.0, max_h=23.0):
        img = new_picture_para(self.doc, self.T.image, png, Cm(max_w), Cm(max_h))
        keep_next(img)
        self._put(img)
        return self._put(clone_para(self.T.fig_cap, caption))
