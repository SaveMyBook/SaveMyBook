"""以 Word 實際排版（1001 版與 AI 完善版 PDF）量得之尺寸估算段落行數與表格高度，供分頁判斷使用。單位：點（pt）。"""
import pymupdf
from doctools import W, text_of

TEXT_W = 510.2          # 18 cm 版心寬
PAGE_TOP, PAGE_BOTTOM = 42.5, 799.4
BODY_PT, BODY_LINE = 14, 20.0     # 內容樣式 14 pt，行距 1.1 倍實測每行 20 pt
CELL_PAD = 10.8                   # 儲存格左右邊界合計
# 表格列高（實測）：14 pt 字單行 20.4、每多一行 17.6；12 pt 字單行 16.2、每多一行 15.6
ROW_METRICS = {14: (20.4, 17.6), 12: (16.2, 15.6)}
_latin = pymupdf.Font('tiro')
_CLOSERS = set('，。、；：？！）」』】》,.;:?!)')


def text_width(s, size=BODY_PT):
    w = 0.0
    for ch in s:
        w += size if ord(ch) > 0x2E7F else _latin.text_length(ch, fontsize=size)
    return w


def wrap_lines(text, width, size=BODY_PT, indent=0.0):
    """模擬 Word 斷行：中文逐字、英數以字為單位，行首避頭標點。"""
    if not text:
        return 1
    tokens, buf = [], ''
    for ch in text:
        if ord(ch) <= 0x2E7F and not ch.isspace():
            buf += ch
            continue
        if buf:
            tokens.append(buf)
            buf = ''
        tokens.append(ch)
    if buf:
        tokens.append(buf)
    lines, used = 1, indent
    for tok in tokens:
        w = text_width(tok, size)
        if used + w > width + 0.5 and used > 0:
            if tok in _CLOSERS:
                used += w
                continue
            lines += 1
            used = 0.0 if tok.isspace() else w
            while used > width:
                lines += 1
                used -= width
        else:
            used += w
    return lines


def _grid(tbl):
    cols = [int(g.get(W('w'))) / 20 for g in tbl.find(W('tblGrid')).findall(W('gridCol'))]
    total = sum(cols) or 1
    return [c * TEXT_W / total for c in cols]


def _font_size(p, style_sizes):
    for r in p.findall(W('r')):
        sz = r.find(W('rPr') + '/' + W('sz'))
        if sz is not None:
            return int(sz.get(W('val'))) / 2
    st = p.find(W('pPr') + '/' + W('pStyle'))
    return style_sizes.get(st.get(W('val')) if st is not None else None, 12)


def style_sizes(doc):
    """各段落樣式之字級（沿 basedOn 往上找），未設定者為文件預設 12 pt。"""
    by_id = {s.style_id: s for s in doc.styles}
    def size(sid):
        s = by_id.get(sid)
        while s is not None:
            sz = s.element.find(W('rPr') + '/' + W('sz'))
            if sz is not None:
                return int(sz.get(W('val'))) / 2
            s = getattr(s, "base_style", None)
        return 12
    return {sid: size(sid) for sid in by_id}


def table_height(tbl, sizes):
    cols = _grid(tbl)
    h = 0.0
    for tr in tbl.findall(W('tr')):
        i, row = 0, 0.0
        for tc in tr.findall(W('tc')):
            span = tc.find(W('tcPr') + '/' + W('gridSpan'))
            n = int(span.get(W('val'))) if span is not None else 1
            width = sum(cols[i:i + n]) - CELL_PAD
            i += n
            cell = 0.0
            for k, p in enumerate(tc.findall(W('p'))):
                size = _font_size(p, sizes)
                first, nxt = ROW_METRICS.get(round(size), (size * 1.46, size * 1.26))
                lines = wrap_lines(text_of(p).strip(), width, size)
                cell += (first if k == 0 else nxt) + (lines - 1) * nxt
            row = max(row, cell)
        h += row
    return h


def para_lines(p, first_indent=28.0):
    return wrap_lines(text_of(p).strip(), TEXT_W, indent=first_indent)
