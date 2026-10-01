"""ER 圖移除系統未使用之資料表、欄位與關聯（清單見 schema_model）。"""
import os, re, shutil, sys
import schema_model as S
REPO = '/Users/xukaijun/Desktop/SaveMyBook/Diagrams/Relational Tables/v3'
HERE = os.path.dirname(os.path.abspath(__file__))
FILES = [f'{REPO}/er_account_consents.puml', f'{REPO}/er_account_settings.puml', f'{REPO}/er_orders.puml',
         f'{REPO}/er_wallet.puml', f'{HERE}/aidiag/er/er_books.puml', f'{HERE}/cabdiag/er/er_cabinets.puml']
DROP_LINKS = [re.compile(r'^\s*reservations\s+\S+\s+smart_cabinets\s*$')]
for path in FILES:
    shutil.copy2(path, os.path.join(HERE, 'erprune_backup', os.path.basename(path)))
    out, entity, skip = [], None, False
    for line in open(path, encoding='utf-8').read().split('\n'):
        m = re.match(r'\s*entity\s+"(\w+)"(?:\s+as\s+(\w+))?', line)
        if m:
            entity = m.group(2) or m.group(1)
            skip = m.group(1) in S.UNUSED_TABLES
        if skip:
            if line.strip() == '}':
                skip, entity = False, None
            continue
        if line.strip() == '}':
            entity = None
        f = re.match(r'\s*\{field\}\s*(?:<&key>\s*)?(\w+)\s*:', line)
        if entity and f and f.group(1) in S.UNUSED_COLUMNS.get(entity, []):
            continue
        if '--' in line and any(re.search(rf'\b{t}\b', line) for t in S.UNUSED_TABLES):
            continue
        if any(p.match(line) for p in DROP_LINKS):
            continue
        out.append(line)
    text = re.sub(r'\n{3,}', '\n\n', '\n'.join(out))
    open(path, 'w', encoding='utf-8').write(text)
    print(os.path.basename(path), 'ok')
