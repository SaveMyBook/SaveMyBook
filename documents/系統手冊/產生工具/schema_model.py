"""讀取 prisma/schema.prisma（唯一的資料表定義來源），整理成 {table: {'cols': [(name, type, pk, fk)], 'fks': [(col, table, col)]}}。"""
import re
import os
API = '/Users/xukaijun/Desktop/SaveMyBook/savemybook_api'
# 最終版資料表定義（合併智慧書櫃與 AI 改善後之 schema），資料字典以此為準
FINAL_API = '/Users/xukaijun/Desktop/SaveMyBook/savemybook_api'

def prisma_type(base, attrs, enums):
    m = re.search(r'@db\.(\w+)(?:\(([^)]*)\))?', attrs)
    db, arg = (m.group(1), m.group(2)) if m else (None, None)
    if base in enums: return 'enum'
    if base == 'String':
        if db == 'VarChar': return f'varchar({arg})'
        if db == 'Char': return f'char({arg})'
        if db in ('Text', 'MediumText', 'LongText'): return db.lower()
        return 'varchar'
    if base == 'Int':
        return {'TinyInt': 'tinyint', 'UnsignedTinyInt': 'tinyint', 'SmallInt': 'smallint', 'UnsignedSmallInt': 'smallint'}.get(db, 'int')
    if base == 'BigInt': return 'bigint'
    if base == 'Boolean': return 'tinyint(1)'
    if base == 'DateTime':
        return {'Date': 'date', 'Time': 'time', 'Timestamp': 'timestamp'}.get(db, 'datetime')
    if base == 'Decimal': return f'decimal({arg.replace(" ", "")})' if arg else 'decimal'
    if base == 'Json': return 'json'
    if db == 'TinyInt': return 'tinyint'
    return base.lower()

# 系統程式未使用之資料表與欄位（僅維運腳本引用或從未寫入），手冊不列出。
UNUSED_TABLES = {'achievements', 'bankbooks', 'content_reviews', 'referral_records', 'user_achievements'}
UNUSED_COLUMNS = {
    'cabinet_slots': ['current_book_id', 'current_order_id'],
    'member_levels': ['max_points'],
    'orders': ['pickup_code', 'pickup_qr_code'],
    'reservations': ['cabinet_id', 'qr_code'],
    'user_settings': ['theme', 'privacy_show_profile', 'privacy_show_phone'],
    'wallets': ['frozen_amount'],
}


def load(api=None, full=False):
    src = open(f'{api or API}/prisma/schema.prisma', encoding='utf-8').read()
    enums = set(re.findall(r'^enum (\w+)', src, re.M))
    models = {}
    for name, body in re.findall(r'^model (\w+) \{(.*?)^\}', src, re.M | re.S):
        cols, fks, pk = [], [], set()
        mid = re.search(r'@@id\(\[([^\]]+)\]', body)
        if mid: pk = {c.strip() for c in mid.group(1).split(',')}
        lines = [l.strip() for l in body.split('\n') if l.strip() and not l.strip().startswith('//') and not l.strip().startswith('@@')]
        rel_types = set()
        for l in lines:
            parts = l.split(None, 2)
            if len(parts) < 2: continue
            fname, ftype = parts[0], parts[1]
            attrs = parts[2] if len(parts) > 2 else ''
            base = ftype.rstrip('?[]')
            r = re.search(r'@relation\([^)]*fields:\s*\[([^\]]+)\][^)]*references:\s*\[([^\]]+)\]', attrs)
            if r:
                for a, b in zip(r.group(1).split(','), r.group(2).split(',')):
                    fks.append((a.strip(), base, b.strip()))
                continue
            if ftype.endswith('[]') or (base[0].isupper() and base not in ('String','Int','BigInt','Boolean','DateTime','Decimal','Json','Bytes','Float') and base not in enums):
                continue
            if '@id' in attrs: pk.add(fname)
            cols.append([fname, prisma_type(base, attrs, enums)])
        models[name] = {'cols': cols, 'pk': pk, 'fks': fks}
    for t in models.values():
        t['cols'] = [c for c in t['cols'] if c[1] not in models]
    if full:
        return models
    for name in UNUSED_TABLES:
        models.pop(name, None)
    for name, t in models.items():
        drop = set(UNUSED_COLUMNS.get(name, []))
        t['cols'] = [c for c in t['cols'] if c[0] not in drop]
        t['pk'] -= drop
        t['fks'] = [fk for fk in t['fks'] if fk[0] not in drop and fk[1] not in UNUSED_TABLES]
    return models

if __name__ == '__main__':
    m = load()
    print(len(m))
    for t in ['users', 'chat_message_risks', 'support_ticket_attachments', 'smart_cabinets', 'ai_embeddings']:
        print(t, m[t]['pk'], m[t]['cols'][:6], m[t]['fks'])
