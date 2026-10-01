"""依 audit/corrections.json 修正手冊中與 App／API 不符的名詞與描述（每筆皆附程式出處）。
定位方式：anchor 為段落原文片段；含「 ｜ 」者為同一表格列之相鄰儲存格；過短之 anchor 須整格相符，
並以 where 中之資料表英文名稱限定在該資料表內（表號會因刪除未使用資料表而變動，不可依表號）。附錄與致謝不處理。"""
import json
import os
import re
from doctools import W, text_of, tcs
from review_lib import replace_in

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'audit', 'corrections.json')
SEP = ' ｜ '


def _style_of(doc):
    styles = {s.style_id: s.name for s in doc.styles}
    def style(p):
        st = p.find(W('pPr') + '/' + W('pStyle'))
        return styles.get(st.get(W('val')), '') if st is not None else ''
    return style


def _scope(doc):
    style = _style_of(doc)
    paras = list(doc.element.body.iter(W('p')))
    start = next(i for i, p in enumerate(paras) if style(p) == 'Heading 1' and text_of(p).strip() == '前言')
    end = next(i for i, p in enumerate(paras) if style(p) == '附錄')
    toc = [p for p in paras[:start] if style(p) == 'table of figures']
    return paras[start:end] + toc


def _meta_table(doc, name):
    for p in doc.element.body.iterchildren(W('p')):
        if re.match(rf'^表 8-2-\d+ {re.escape(name)} ', text_of(p).strip()):
            nxt = p.getnext()
            if nxt is not None and nxt.tag == W('tbl'):
                return nxt
    return None


def _row_hits(doc, anchor, old):
    segs = anchor.split(SEP)
    k = next((j for j, s in enumerate(segs) if old in s), None)
    if k is None:
        return []
    hits = []
    for tr in doc.element.body.iter(W('tr')):
        cells = tcs(tr)
        texts = [text_of(c).strip() for c in cells]
        for s in range(len(texts) - len(segs) + 1):
            if all(seg.strip() in texts[s + j] for j, seg in enumerate(segs)):
                cell = cells[s + k]
                ps = [p for p in cell.iter(W('p')) if old in text_of(p)]
                if ps:
                    hits.append(ps[0])
                break
    return hits


def _locate(doc, paras, it, old=None, anchor=None):
    old = old or it['old']
    anchor = re.sub(r'^表 8-2-\d+ ', '', anchor or it.get('anchor') or it['old'])
    if SEP in anchor:
        return _row_hits(doc, anchor, old)
    if anchor == old or len(anchor) < 8:
        m = re.search(r'8-2-\d+\s*([a-z_]+)', it.get('where', ''))
        pool = paras
        if m:
            tbl = _meta_table(doc, m.group(1))
            pool = list(tbl.iter(W('p'))) if tbl is not None else []
        exact = [p for p in pool if text_of(p).strip() == anchor]
        return exact or [p for p in pool if anchor in text_of(p)][:1]
    return [p for p in paras if old in text_of(p) and anchor in text_of(p)]


def _sub_all(text, pairs):
    for o, n in pairs:
        if o in text:
            text = text.replace(o, n)
    return text


def _append_line(p, text):
    """於同一段落末尾以換行新增一行（使用個案表之條列以換行分隔，非獨立段落）。"""
    import copy
    from docx.oxml import OxmlElement
    runs = p.findall(W('r'))
    tpl = copy.deepcopy(runs[-1]) if runs else OxmlElement('w:r')
    for child in list(tpl):
        if child.tag != W('rPr'):
            tpl.remove(child)
    br = copy.deepcopy(tpl); br.append(OxmlElement('w:br'))
    t = OxmlElement('w:t'); t.text = text; t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    tr = copy.deepcopy(tpl); tr.append(t)
    p.append(br); p.append(tr)


def run(doc):
    if not os.path.exists(SRC):
        return {'applied': 0}
    items = [x for x in json.load(open(SRC, encoding='utf-8')) if not x.get('puml')]
    paras = _scope(doc)
    applied, already, missing = 0, 0, []
    pairs = []
    for it in items:
        old = it['old']
        if it.get('append'):
            hits = [p for p in paras if it['anchor'] in text_of(p)]
            if hits and it['new'] not in text_of(hits[0]):
                _append_line(hits[0], it['new'])
                applied += 1
            elif hits:
                already += 1
            else:
                missing.append(it)
            continue
        if it.get('global'):
            hits = [p for p in paras if old in text_of(p) and not (old in it['new'] and it['new'] in text_of(p))]
            for p in hits:
                for _ in range(text_of(p).count(old)):
                    replace_in(p, old, it['new'])
            applied += bool(hits)
            continue
        hits = _locate(doc, paras, it)
        if not hits:
            old = _sub_all(it['old'], pairs)
            hits = _locate(doc, paras, it, old, _sub_all(it.get('anchor') or it['old'], pairs))
        if not hits:
            done = it['new'] and any(it['new'] in text_of(p) for p in paras)
            if done:
                already += 1
            else:
                missing.append(it)
            continue
        for p in hits:
            replace_in(p, old, it['new'])
        pairs.append((it['old'], it['new']))
        applied += 1
    json.dump(missing, open(os.path.join(HERE, 'audit', 'missing.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    return {'applied': applied, 'already': already, 'missing': len(missing)}
