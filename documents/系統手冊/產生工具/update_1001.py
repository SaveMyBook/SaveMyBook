"""套用使用者於複評版（reference/複評版_1001.docx）手動完成之排版：封面日期、前置頁羅馬數字頁碼、
文字相同段落之分頁／段落不跨頁設定／間距／縮排／對齊、表格跨頁設定，以及各圖之尺寸（第 1～7 章與前置頁）。
第 8 章以後複評版尚未排版，依同一方式接續：各節自新頁開始、圖與其說明及圖名同頁且一圖一頁。"""
import copy
import difflib
import os
from docx import Document
from docx.oxml import OxmlElement
from lxml import etree
from doctools import W, text_of
from review_lib import replace_in, keep_next, page_break_before
from update_layout import keep_lines
import layout_measure as lm

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, 'reference', '複評版_1001.docx')
COVER_DATE = '中華民國115年10月13日'
COPY_TAGS = ('keepNext', 'keepLines', 'pageBreakBefore', 'spacing', 'ind', 'jc')
PPR_ORDER = ['pStyle', 'keepNext', 'keepLines', 'pageBreakBefore', 'framePr', 'widowControl', 'numPr', 'suppressLineNumbers',
             'pBdr', 'shd', 'tabs', 'suppressAutoHyphens', 'kinsoku', 'wordWrap', 'overflowPunct', 'topLinePunct', 'autoSpaceDE',
             'autoSpaceDN', 'bidi', 'adjustRightInd', 'snapToGrid', 'spacing', 'ind', 'contextualSpacing', 'mirrorIndents',
             'suppressOverlap', 'jc', 'textDirection', 'textAlignment', 'textboxTightWrap', 'outlineLvl', 'divId', 'cnfStyle',
             'rPr', 'sectPr', 'pPrChange']


def _style(doc):
    names = {s.style_id: s.name for s in doc.styles}
    def style(p):
        st = p.find(W('pPr') + '/' + W('pStyle'))
        return names.get(st.get(W('val')), '') if st is not None else ''
    return style


def _scope(doc):
    """前置頁至第 7 章結束（第 8 章「資料庫設計」之前）。"""
    style = _style(doc)
    body = list(doc.element.body.iterchildren())
    end = next(i for i, e in enumerate(body) if e.tag == W('p') and style(e) == 'Heading 1' and text_of(e).strip() == '資料庫設計')
    return body[:end]


def _key(els, i):
    e = els[i]
    if e.tag == W('tbl'):
        return 'T|' + text_of(e)[:60]
    if e.find('.//' + W('drawing')) is not None:
        nxt = els[i + 1] if i + 1 < len(els) else None
        return 'I|' + (text_of(nxt).strip() if nxt is not None else '')
    return 'P|' + text_of(e).strip()


def _set_child(ppr, tag, src):
    for old in ppr.findall(W(tag)):
        ppr.remove(old)
    if src is None:
        return
    new = copy.deepcopy(src)
    rank = PPR_ORDER.index(tag)
    for i, child in enumerate(ppr):
        name = child.tag.split('}')[1]
        if name in PPR_ORDER and PPR_ORDER.index(name) > rank:
            ppr.insert(i, new)
            return
    ppr.append(new)


def _copy_format(dst, src, tags=COPY_TAGS):
    sppr = src.find(W('pPr'))
    dppr = dst.find(W('pPr'))
    if dppr is None:
        dppr = OxmlElement('w:pPr')
        dst.insert(0, dppr)
    changed = 0
    for tag in tags:
        theirs = sppr.find(W(tag)) if sppr is not None else None
        ours = dppr.find(W(tag))
        if (theirs is None) != (ours is None) or (theirs is not None and theirs.attrib != ours.attrib):
            _set_child(dppr, tag, theirs)
            changed += 1
    return changed


WP = '{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}'
A_NS = '{http://schemas.openxmlformats.org/drawingml/2006/main}'


def _copy_size(dst, src):
    a, b = dst.find('.//' + WP + 'extent'), src.find('.//' + WP + 'extent')
    if a is None or b is None:
        return 0
    # 圖之後若有修改，長寬比可能與複評版不同：以複評版尺寸為外框、維持本圖比例縮放，避免變形。
    ow, oh, bw, bh = int(a.get('cx')), int(a.get('cy')), int(b.get('cx')), int(b.get('cy'))
    scale = min(bw / ow, bh / oh)
    cx, cy = str(int(ow * scale)), str(int(oh * scale))
    if (a.get('cx'), a.get('cy')) == (cx, cy):
        return 0
    a.set('cx', cx)
    a.set('cy', cy)
    for ext in dst.iter(A_NS + 'ext'):
        if ext.get('cx') is not None:
            ext.set('cx', cx)
            ext.set('cy', cy)
    return 1


def _cells(t):
    return [['\n'.join(text_of(p) for p in tc.findall(W('p'))) for tc in tr.findall(W('tc'))] for tr in t.findall(W('tr'))]


def _same_element(a, b, ka, kb):
    """同類元素且文字相近，或開頭12字以上相同（段落內容改寫較多時，圖表標號除外），或表頭與欄數相同之表格。"""
    if ka[:2] != kb[:2]:
        return False
    if difflib.SequenceMatcher(None, ka, kb).ratio() >= 0.75:
        return True
    if ka.startswith('P|') and not ka.startswith(('P|圖 ', 'P|表 ')) and len(os.path.commonprefix([ka, kb])) >= 2 + 12:
        return True
    return _same_table_shape(a, b)


def _same_table_shape(a, b):
    if a.tag != W('tbl') or b.tag != W('tbl'):
        return False
    ga, gb = a.find(W('tblGrid')), b.find(W('tblGrid'))
    return ga is not None and gb is not None and len(ga) == len(gb) and _cells(a)[:1] == _cells(b)[:1]


def _replace_child(parent, tag, src):
    old = parent.find(W(tag))
    if src is None:
        return
    new = copy.deepcopy(src)
    if old is not None:
        old.addprevious(new)
        parent.remove(old)
    else:
        parent.insert(0, new)


def _copy_cell(dst, src):
    _replace_child(dst, 'tcPr', src.find(W('tcPr')))
    sps = src.findall(W('p'))
    for k, p in enumerate(dst.findall(W('p'))):
        sp = sps[min(k, len(sps) - 1)]
        ppr = sp.find(W('pPr'))
        old = p.find(W('pPr'))
        if old is not None:
            p.remove(old)
        if ppr is not None:
            p.insert(0, copy.deepcopy(ppr))
        runs = sp.findall(W('r'))
        rpr = runs[0].find(W('rPr')) if runs else None
        for r in p.findall(W('r')):
            old = r.find(W('rPr'))
            if old is not None:
                r.remove(old)
            if rpr is not None:
                r.insert(0, copy.deepcopy(rpr))


def _copy_table(dst, src):
    """複評版重新調整過之表格（欄寬、儲存格段落與字型、表頭重複等）：內容相同者整張沿用，
    內容已更新者在欄數相同時逐列逐格套用其格式。回傳 2＝整張沿用、1＝套用格式、0＝未處理。"""
    if _cells(dst) == _cells(src):
        dst.addprevious(copy.deepcopy(src))
        dst.getparent().remove(dst)
        return 2
    grid_a, grid_b = dst.find(W('tblGrid')), src.find(W('tblGrid'))
    if grid_a is None or grid_b is None or len(grid_a) != len(grid_b):
        return 0
    _replace_child(dst, 'tblPr', src.find(W('tblPr')))
    _replace_child(dst, 'tblGrid', grid_b)
    rows_b = src.findall(W('tr'))
    for i, tr in enumerate(dst.findall(W('tr'))):
        tb = rows_b[min(i, len(rows_b) - 1)]
        trpr = tb.find(W('trPr'))
        old = tr.find(W('trPr'))
        if old is not None:
            tr.remove(old)
        if trpr is not None:
            anchor = tr.find(W('tblPrEx'))
            (anchor.addnext if anchor is not None else lambda e: tr.insert(0, e))(copy.deepcopy(trpr))
        ca, cb = tr.findall(W('tc')), tb.findall(W('tc'))
        if len(ca) == len(cb):
            for a, b in zip(ca, cb):
                _copy_cell(a, b)
    return 1


def _copy_table_keep(dst, src):
    """複評版表格不綁列、不禁列跨頁者，本表亦同（分頁改由其手動換頁決定）。"""
    changed = 0
    if not any(p.find(W('pPr') + '/' + W('keepNext')) is not None for p in src.iter(W('p'))):
        for k in list(dst.iter(W('keepNext'))):
            k.getparent().remove(k)
            changed = 1
    if not any(tr.find(W('trPr') + '/' + W('cantSplit')) is not None for tr in src.findall(W('tr'))):
        for k in list(dst.iter(W('cantSplit'))):
            k.getparent().remove(k)
            changed = 1
    return changed


# 第 8 章以後之圖頁（依 Word 實測）：章首頁正文起點、節標題換頁後正文起點，以及圖段落上下間距、圖名與安全餘量。
# 說明文字之行數估算偶爾少一行，故另多留一行。
CHAPTER_TOP, SECTION_TOP, FIG_OVERHEAD = 120.5, 78.0, 40.0
EMU_PER_PT = 12700


def _fit_height(p, avail):
    ext = p.find('.//' + WP + 'extent')
    cy = int(ext.get('cy'))
    limit = int(avail * EMU_PER_PT)
    if cy <= limit:
        return 0
    scale = limit / cy
    cx, cy = str(int(int(ext.get('cx')) * scale)), str(limit)
    ext.set('cx', cx)
    ext.set('cy', cy)
    for x in p.iter(A_NS + 'ext'):
        if x.get('cx') is not None:
            x.set('cx', cx)
            x.set('cy', cy)
    return 1


def _continue(doc):
    style = _style(doc)
    body = list(doc.element.body.iterchildren())
    h1 = [i for i, e in enumerate(body) if e.tag == W('p') and style(e) == 'Heading 1']
    start = next(i for i in h1 if text_of(body[i]).strip() == '資料庫設計')
    end = next(i for i in h1 if text_of(body[i]).strip() == '參考資料')
    scope = body[start:end]
    stats = {'sections': 0, 'figures': 0, 'resized': 0}
    first_section = True
    for i, e in enumerate(scope):
        if e.tag != W('p'):
            continue
        st = style(e)
        if st == 'Heading 1':
            first_section = True
            continue
        if st == 'Heading 2':
            if not first_section:
                page_break_before(e)
                stats['sections'] += 1
            first_section = False
            continue
        if e.find('.//' + W('drawing')) is None or i < 2 or i + 1 >= len(scope):
            continue
        desc, cap, head = scope[i - 1], scope[i + 1], scope[i - 2]
        if desc.tag != W('p') or style(desc) != '內容' or len(text_of(desc).strip()) < 40 or style(cap) != 'Caption':
            continue
        if head.tag == W('p') and style(head) == 'Heading 2':
            top = CHAPTER_TOP if style(scope[i - 3]) == 'Heading 1' else SECTION_TOP
        else:
            page_break_before(desc)
            top = lm.PAGE_TOP
        keep_next(desc)
        keep_lines(desc)
        avail = lm.PAGE_BOTTOM - top - lm.BODY_LINE * (lm.para_lines(desc) + 1) - FIG_OVERHEAD
        stats['figures'] += 1
        stats['resized'] += _fit_height(e, avail)
    return stats


def _footnotes(doc):
    part = next(r.target_part for r in doc.part.rels.values() if r.reltype.endswith('/footnotes'))
    return part, etree.fromstring(part.blob)


def _copy_footnote(dst, src, ours, theirs):
    """複評版於段落加註之腳註（AI 使用說明），本段尚無腳註時照原位置補上。"""
    if dst.find('.//' + W('footnoteReference')) is not None:
        return 0
    added = 0
    for run in src.findall(W('r')):
        ref = run.find(W('footnoteReference'))
        if ref is None:
            continue
        note = theirs.find(W('footnote') + f'[@{W("id")}="{ref.get(W("id"))}"]')
        if note is None:
            continue
        new_id = str(max(int(f.get(W('id'))) for f in ours.findall(W('footnote'))) + 1)
        note = copy.deepcopy(note)
        note.set(W('id'), new_id)
        ours.append(note)
        new_run = copy.deepcopy(run)
        new_run.find(W('footnoteReference')).set(W('id'), new_id)
        before = ''.join(text_of(r) for r in run.itersiblings(preceding=True) if r.tag == W('r'))
        anchor, seen = None, ''
        for r in dst.findall(W('r')):
            if seen == before:
                break
            seen += text_of(r)
            anchor = r
        if anchor is not None and seen == before:
            anchor.addnext(new_run)
        else:
            dst.append(new_run)
        added += 1
    return added


def _front_matter_section(doc):
    """誌謝至表目錄獨立一節，以小寫羅馬數字編頁；正文自第 1 章起由 1 開始。"""
    style = _style(doc)
    body = list(doc.element.body.iterchildren())
    first = next(i for i, e in enumerate(body) if e.tag == W('p') and style(e) == 'Heading 1' and text_of(e).strip() == '前言')
    if any(e.find(W('pPr') + '/' + W('sectPr')) is not None for e in body[first - 3:first] if e.tag == W('p')):
        return 0
    final = doc.element.body.find(W('sectPr'))
    sect = copy.deepcopy(final)
    pg = sect.find(W('pgNumType'))
    if pg is None:
        pg = OxmlElement('w:pgNumType')
        sect.append(pg)
    pg.set(W('fmt'), 'lowerRoman')
    pg.set(W('start'), '1')
    holder = body[first - 1]
    if holder.tag != W('p') or text_of(holder).strip() or holder.find('.//' + W('drawing')) is not None:
        holder = OxmlElement('w:p')
        body[first].addprevious(holder)
    ppr = holder.find(W('pPr'))
    if ppr is None:
        ppr = OxmlElement('w:pPr')
        holder.insert(0, ppr)
    ppr.append(sect)
    return 1


def run(doc):
    stats = {'cover': 0, 'section': 0, 'paragraphs': 0, 'images': 0, 'tables': 0, 'shrunk': 0, 'footnotes': 0}
    for p in list(doc.element.body.iterchildren(W('p')))[:20]:
        if text_of(p).strip().startswith('中華民國') and text_of(p).strip() != COVER_DATE:
            replace_in(p, text_of(p).strip(), COVER_DATE)
            stats['cover'] = 1
            break
    stats['section'] = _front_matter_section(doc)
    stats['tail'] = _continue(doc)
    if not os.path.exists(REF):
        return stats
    ref = Document(REF)
    ours = _scope(doc)
    theirs = _scope(ref)
    fpart, fours = _footnotes(doc)
    _, ftheirs = _footnotes(ref)
    ka = [_key(ours, i) for i in range(len(ours))]
    kb = [_key(theirs, i) for i in range(len(theirs))]
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, ka, kb, autojunk=False).get_opcodes():
        pairs = list(zip(ours[i1:i2], theirs[j1:j2], ka[i1:i2], kb[j1:j2]))
        if op == 'replace' and i2 - i1 == j2 - j1:
            # 文字僅小幅修改之段落（如更名、改數字）仍沿用複評版之格式；表格只比對前60字，內容改動較多時以表頭與欄數相同為準。
            pairs = [x for x in pairs if _same_element(*x)]
        elif op == 'replace':
            # 前後段落有增減時，依序找出對應之段落
            pairs, j = [], j1
            for i in range(i1, i2):
                hit = next((jj for jj in range(j, j2) if _same_element(ours[i], theirs[jj], ka[i], kb[jj])), None)
                if hit is not None:
                    pairs.append((ours[i], theirs[hit], ka[i], kb[hit]))
                    j = hit + 1
        elif op != 'equal':
            continue
        for a, b, key, _ in pairs:
            if a.tag == W('tbl'):
                if b.tag == W('tbl'):
                    done = _copy_table(a, b)
                    stats['tables'] += bool(done)
                    if not done:
                        _copy_table_keep(a, b)
                continue
            if a.tag != W('p'):
                continue
            if key.startswith('I|'):
                stats['images'] += _copy_size(a, b)
                _copy_format(a, b, ('pStyle', 'numPr'))
                stats['shrunk'] += _shrink_for_longer_text(a, b)
            stats['paragraphs'] += bool(_copy_format(a, b))
            stats['footnotes'] += _copy_footnote(a, b, fours, ftheirs)
    # 複評版此小標未與下段綁定，本版前頁內容較短時會單獨落在頁尾
    for e in ours:
        if e.tag == W('p') and text_of(e).strip() == '金流規劃補強':
            keep_next(e)
    fpart._blob = etree.tostring(fours, xml_declaration=True, encoding='UTF-8', standalone=True)
    return stats


def _shrink_for_longer_text(img, ref_img):
    """圖頁之說明文字因內容更新而比複評版多出幾行時，圖依多出之行高等比縮小，維持說明、圖與圖名同頁。"""
    desc, ref = img.getprevious(), ref_img.getprevious()
    if desc is None or ref is None or desc.tag != W('p') or ref.tag != W('p'):
        return 0
    extra = lm.para_lines(desc) - lm.para_lines(ref)
    if text_of(desc).strip() == text_of(ref).strip() or extra <= 0:
        return 0
    ext = img.find('.//' + WP + 'extent')
    return _fit_height(img, int(ext.get('cy')) / EMU_PER_PT - extra * lm.BODY_LINE)
