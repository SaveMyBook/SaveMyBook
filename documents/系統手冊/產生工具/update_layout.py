"""分頁比照初評版：段落不跨頁、能放在一頁的表格整張與表名同頁（超過一頁者只在列間斷開）、小標與表名不落在頁尾。
另修正第5章起共用同一組自動編號（numId 10）造成序號一路累加（「77. 本圖…」「10. UC-02」）的問題。
只處理正文（第1章至參考資料前），附錄維持原樣。"""
import copy
import re
from docx.oxml import OxmlElement
from doctools import W, text_of
from review_lib import new_num, keep_next, page_break_before, _ppr, _insert_ordered
import layout_measure as lm

SHARED_NUM = '10'
UC_HEAD = re.compile(r'^UC-\d{2}　')
# 表名＋表格之估計高度（pt，版心高約 757）：整張綁在一起超過一頁時，Word 會把表格整張推到下一頁、只留表名，
# 故只有確定放得下一頁者整張綁定；接近一頁者改由新頁開始，其餘只綁表名、表頭與第一列，任其跨頁（表頭重複）。
CAPTION_H = 30
SHORT_BLOCK, PAGE_BLOCK = 640, 780


def _style(p, styles):
    st = p.find(W('pPr') + '/' + W('pStyle'))
    return styles.get(st.get(W('val')), '') if st is not None else ''


def _num_id(p):
    n = p.find(W('pPr') + '/' + W('numPr') + '/' + W('numId'))
    return n.get(W('val')) if n is not None else None


def _bold(p):
    return any(r.find(W('rPr') + '/' + W('b')) is not None for r in p.iter(W('r')))


def keep_lines(p):
    ppr = _ppr(p)
    if ppr.find(W('keepLines')) is None:
        _insert_ordered(ppr, OxmlElement('w:keepLines'), ['pStyle', 'keepNext'])


def _drop(p, tag):
    ppr = p.find(W('pPr'))
    if ppr is not None:
        for x in ppr.findall(W(tag)):
            ppr.remove(x)


def _is_image(p):
    return p.find('.//' + W('drawing')) is not None


def _cant_split(tr):
    trpr = tr.find(W('trPr'))
    if trpr is None:
        trpr = OxmlElement('w:trPr')
        tcpr_anchor = tr.find(W('tblPrEx'))
        (tcpr_anchor.addnext if tcpr_anchor is not None else lambda e: tr.insert(0, e))(trpr)
    if trpr.find(W('cantSplit')) is None:
        trpr.insert(0, OxmlElement('w:cantSplit'))


def _looks_header(tr):
    tcs = tr.findall(W('tc'))
    if not tcs:
        return False
    def shaded(tc):
        shd = tc.find(W('tcPr') + '/' + W('shd'))
        return shd is not None and shd.get(W('fill'), 'auto').upper() not in ('AUTO', 'FFFFFF')
    return all(shaded(tc) or (_bold(tc) and text_of(tc).strip()) for tc in tcs)


def _repeat_header(tr):
    trpr = tr.find(W('trPr'))
    if trpr.find(W('tblHeader')) is None:
        trpr.append(OxmlElement('w:tblHeader'))


def _lead(scope, i, styles):
    """表格前與之連動的表名、小標或節標題中最前面一段；若為章標題（本身即換頁）則不需另加分頁。"""
    if i == 0 or scope[i - 1].tag != W('p'):
        return None
    j = i - 1
    while j > 0:
        prev = scope[j - 1]
        if prev.tag != W('p'):
            break
        st, t = _style(prev, styles), text_of(prev).strip()
        short_head = st == '內容' and t and len(t) <= 40 and not t.endswith('。')
        if st in ('Heading 1', 'Heading 2') or short_head:
            j -= 1
            continue
        break
    first = scope[j]
    return None if _style(first, styles) == 'Heading 1' else first


def run(doc):
    styles = {s.style_id: s.name for s in doc.styles}
    body = list(doc.element.body.iterchildren())
    h1 = [i for i, e in enumerate(body) if e.tag == W('p') and _style(e, styles) == 'Heading 1']
    start = next(i for i in h1 if text_of(body[i]).strip() == '前言')
    end = next(i for i in h1 if text_of(body[i]).strip() == '參考資料')
    scope = body[start:end]
    body_ppr = next(copy.deepcopy(e.find(W('pPr'))) for e in scope
                    if e.tag == W('p') and text_of(e).startswith('根據表2-2-1'))

    stats = dict(desc=0, uc=0, sub=0, breaks=0, tables=0, keep_lines=0, keep_next=0, long_tables=0, table_breaks=0)
    sizes = lm.style_sizes(doc)
    section_num = {}
    h2 = ''
    for e in scope:
        if e.tag != W('p'):
            continue
        st = _style(e, styles)
        if st == 'Heading 1':
            h2 = text_of(e) + '/'
        if st == 'Heading 2':
            h2 = text_of(e)
        if _num_id(e) != SHARED_NUM:
            continue
        t = text_of(e).strip()
        if UC_HEAD.match(t):
            e.find(W('pPr') + '/' + W('numPr') + '/' + W('numId')).set(W('val'), '0')
            stats['uc'] += 1
        elif len(t) > 60 and not _bold(e):
            e.replace(e.find(W('pPr')), copy.deepcopy(body_ppr))
            stats['desc'] += 1
        else:
            if h2 not in section_num:
                section_num[h2] = new_num(doc, SHARED_NUM)
            e.find(W('pPr') + '/' + W('numPr') + '/' + W('numId')).set(W('val'), str(section_num[h2]))
            stats['sub'] += 1

    for i, e in enumerate(scope):
        nxt = scope[i + 1] if i + 1 < len(scope) else None
        if e.tag == W('tbl'):
            rows = e.findall(W('tr'))
            for r in rows:
                _cant_split(r)
            if rows and _looks_header(rows[0]):
                _repeat_header(rows[0])
            block = lm.table_height(e, sizes) + CAPTION_H
            for r in (rows[:-1] if block <= SHORT_BLOCK else rows[:1]):
                for p in r.iter(W('p')):
                    keep_next(p)
            if block > SHORT_BLOCK:
                stats['long_tables'] += 1
                lead = _lead(scope, i, styles)
                if block <= PAGE_BLOCK and lead is not None:
                    page_break_before(lead)
                    stats['table_breaks'] += 1
            stats['tables'] += 1
            continue
        if e.tag != W('p'):
            continue
        st = _style(e, styles)
        if st not in ('Heading 1', 'Heading 2') and e.find(W('pPr') + '/' + W('pageBreakBefore')) is not None:
            _drop(e, 'pageBreakBefore')
            stats['breaks'] += 1
        t = text_of(e).strip()
        heading_like = (
            st == 'Caption' and nxt is not None and nxt.tag == W('tbl')
            or _is_image(e)
            or st == '內容' and t and len(t) <= 40 and (_num_id(e) not in (None, '0', '7') or _bold(e)) and not t.endswith('。')
        )
        if heading_like:
            keep_next(e)
            stats['keep_next'] += 1
        if t and not _is_image(e):
            keep_lines(e)
            stats['keep_lines'] += 1
    return stats
