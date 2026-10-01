"""8-2 各資料表之「外鍵」欄：沿用初評版，外鍵說明所列之欄位標示 V，其餘留空。

外鍵說明與 prisma/schema.prisma 之關聯核對，schema 有而說明缺少者補上說明列。
"""
import copy, re
from doctools import W, text_of, tcs
import schema_model

META = re.compile(r'^表 8-2-\d+ (\S+) ')
FK_TEXT = re.compile(r'^(\w+)\s*→\s*(\w+)\.(\w+)$')
FK_HEAD = '外鍵說明'
SEP = '　→　'


def meta_tables(doc):
    for p in doc.paragraphs:
        if p.style.name != 'Caption': continue
        m = META.match(p.text.strip())
        nxt = p._p.getnext()
        if m and nxt is not None and nxt.tag == W('tbl'):
            yield m.group(1), nxt


def parse(tbl):
    """回傳 (資料列 {欄位名稱: tr}, 外鍵說明標題列, [(外鍵說明列, (欄位, 參照表, 參照欄位))])。"""
    rows = tbl.findall(W('tr'))
    head = [text_of(tc).strip() for tc in tcs(rows[3])]
    assert head[0] == '欄位名稱' and head[-1] == '外鍵', head
    cols, fk_head, fks = {}, None, []
    for tr in rows[4:]:
        cells = tcs(tr)
        if len(cells) > 1:
            cols[text_of(cells[0]).strip()] = tr
            continue
        t = text_of(cells[0]).strip()
        if t == FK_HEAD:
            fk_head = tr
            continue
        m = FK_TEXT.match(t.replace('　', ' ').strip())
        assert m, t
        fks.append((tr, m.groups()))
    return cols, fk_head, fks


def _set_text(tc, text, rpr=None):
    tc_p = tc.find(W('p'))
    for p in tc.findall(W('p'))[1:]: tc.remove(p)
    for child in list(tc_p):
        if child.tag != W('pPr'): tc_p.remove(child)
    if text:
        r = tc_p.makeelement(W('r'), {})
        if rpr is not None: r.append(copy.deepcopy(rpr))
        t = r.makeelement(W('t'), {}); t.text = text
        r.append(t); tc_p.append(r)


def _v_rpr(cols):
    """同表「唯一性」「不為空值」欄中 V 的字型，讓外鍵欄的 V 與之一致。"""
    for tr in cols.values():
        for tc in tcs(tr)[-3:-1]:
            for r in tc.iter(W('r')):
                if text_of(r).strip() == 'V' and r.find(W('rPr')) is not None:
                    return r.find(W('rPr'))
    return None


def run(doc):
    schema = schema_model.load(schema_model.FINAL_API)
    tables = list(meta_tables(doc))
    tpl_head = tpl_row = None
    for _, tbl in tables:
        _, h, f = parse(tbl)
        if h is not None and f:
            tpl_head, tpl_row = h, f[0][0]
            break
    stats = {'tables': len(tables), 'fk_marked': 0, 'fk_rows_added': [], 'cleared': 0}
    for name, tbl in tables:
        cols, fk_head, fks = parse(tbl)
        listed = {fk for _, fk in fks}
        for fk in schema[name]['fks']:
            if fk in listed: continue
            if fk_head is None:
                fk_head = copy.deepcopy(tpl_head); tbl.append(fk_head)
            tr = copy.deepcopy(tpl_row)
            cell = tcs(tr)[0]
            _set_text(cell, f'{fk[0]}{SEP}{fk[1]}.{fk[2]}', next((r.find(W('rPr')) for r in cell.iter(W('r'))), None))
            tbl.append(tr)
            listed.add(fk); stats['fk_rows_added'].append(f'{name}.{fk[0]}')
        fk_cols = {c for c, _, _ in listed}
        missing = fk_cols - set(cols)
        assert not missing, (name, missing)
        rpr = _v_rpr(cols)
        for col, tr in cols.items():
            tc = tcs(tr)[-1]
            want = 'V' if col in fk_cols else ''
            if not want and text_of(tc).strip(): stats['cleared'] += 1
            _set_text(tc, want, rpr)
            stats['fk_marked'] += bool(want)
    return stats
