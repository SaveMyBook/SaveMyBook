import docx
from docx.oxml.ns import qn
PATH='/Users/xukaijun/Desktop/SaveMyBook/documents/系統手冊/3 完善版/四技第115414組-救「舊」我的書-系統手冊.docx'
def load(p=PATH): return docx.Document(p)
def captioned_tables(d):
    """回傳 {caption_text: table}，caption 為表格前最近的「表 x-x-x」段落"""
    out={}; last=None
    for el in d.element.body.iterchildren():
        tag=el.tag.split('}')[1]
        if tag=='p':
            t=''.join(x.text or '' for x in el.iter(qn('w:t'))).strip()
            if t.startswith('表 '): last=t
        elif tag=='tbl' and last:
            out[last]=docx.table.Table(el,d); last=None
    return out
def dump(t, maxrows=100):
    for r in t.rows[:maxrows]:
        print(' | '.join(c.text.replace('\n','⏎')[:80] for c in r.cells))
