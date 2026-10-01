"""智慧書櫃模組 ER 圖：依最終 schema（cabrev/savemybook_api/prisma/schema.prisma）產生 .puml。
用法：docenv/bin/python cabdiag/gen_cab_er.py（於 scratchpad 執行）"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.path.dirname(HERE)
sys.path.insert(0, SP)
import schema_model
schema_model.API = os.path.join(SP, 'cabrev/savemybook_api')
M = schema_model.load()
OUT = os.path.join(HERE, 'er')
os.makedirs(OUT, exist_ok=True)

HEAD = '''@startuml
skinparam monochrome true
skinparam shadowing false
skinparam dpi 220
skinparam defaultFontName "PingFang TC"
skinparam defaultFontSize 12
skinparam linetype ortho
skinparam nodesep 30
skinparam ranksep 40
hide circle
hide empty methods
'''


def entity(t, stub=False):
    m = M[t]
    pk = [c for c in m['cols'] if c[0] in m['pk']]
    rest = [] if stub else [c for c in m['cols'] if c[0] not in m['pk']]
    lines = [f'entity "{t}" as {t} {{']
    for n, ty in pk: lines.append(f'  {{field}} <&key> {n} : {ty}')
    lines.append('  --')
    for n, ty in rest: lines.append(f'  {{field}} {n} : {ty}')
    if stub: lines.append('  ...')
    lines.append('}')
    return '\n'.join(lines)


def build(name, tables, stubs=(), lr=False, extra=(), order=None, below=()):
    """order：entity 宣告順序（影響同層左右位置）；below：畫在子表下方的參照表（'參照表' 或 ('參照表', '子表')），
    關聯改寫成「子表 }o--|| 參照表」，讓 Graphviz 把參照表排到下一層，避免連線在基數符號旁交叉。"""
    out = [HEAD + ('left to right direction\n' if lr else '')]
    tables = list(stubs) + [t for t in tables if t not in stubs]
    for t in (order or tables): out.append(entity(t, stub=t in stubs))
    seen = set()
    for t in tables:
        if t in stubs: continue
        for col, ref, _ in M[t]['fks']:
            if ref not in tables or (ref, t) in seen: continue
            seen.add((ref, t))
            one = col in M[t]['pk'] and len(M[t]['pk']) == 1
            if ref in below or (ref, t) in below:
                out.append(f'{t} {"|o" if one else "}o"}--|| {ref}')
            else:
                out.append(f'{ref} ||--{"o|" if one else "o{"} {t}')
    out.extend(extra)
    out.append('@enduml\n')
    open(os.path.join(OUT, name + '.puml'), 'w', encoding='utf-8').write('\n'.join(out))


MODULES = {
    'er_cabinets': dict(tables=['smart_cabinets', 'cabinet_slots', 'cabinet_slot_items', 'book_deposits', 'reservations'],
                        stubs=['books', 'cabinet_sessions'], lr=True,
                        below=[('smart_cabinets', 'reservations'), ('smart_cabinets', 'book_deposits')]),
    'er_cabinet_devices': dict(tables=['cabinet_devices', 'cabinet_pair_requests', 'cabinet_challenges'],
                               stubs=['smart_cabinets']),
    'er_cabinet_sessions': dict(tables=['cabinet_sessions', 'cabinet_session_items', 'cabinet_session_doors'],
                                stubs=['smart_cabinets', 'cabinet_devices', 'users', 'orders', 'books', 'cabinet_slots'],
                                below=['cabinet_slots']),
    'er_cabinet_reports': dict(tables=['cabinet_manual_reports', 'cabinet_events'],
                               stubs=['smart_cabinets', 'users', 'orders', 'books']),
}

if __name__ == '__main__':
    cab = sorted(t for t in M if t.startswith('cabinet_') or t in ('smart_cabinets', 'book_deposits', 'reservations'))
    shown = {t for v in MODULES.values() for t in v['tables']}
    print('cabinet tables', cab, 'not shown', sorted(set(cab) - shown))
    for n, kw in MODULES.items(): build(n, **kw)
