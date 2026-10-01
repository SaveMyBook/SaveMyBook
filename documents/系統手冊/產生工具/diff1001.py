"""比對 AI 完善版與 1001 版：文字差異與格式差異（依樣式彙整）。"""
import difflib, collections, json, re, sys
from docx import Document
from docx.oxml.ns import qn
from lxml import etree
A=sys.argv[1] if len(sys.argv)>1 else '/Users/xukaijun/Desktop/SaveMyBook/documents/系統手冊/系統手冊_AI完善版.docx'
B='/Users/xukaijun/Desktop/SaveMyBook/documents/系統手冊/2 複評版(2026.10.13)/四技第115414組-救「舊」我的書-系統手冊_1001版.docx'
def ppr_sig(e):
    ppr=e.find(qn('w:pPr'))
    if ppr is None: return ''
    keep=[]
    for c in ppr:
        tag=c.tag.split('}')[1]
        if tag in ('rPr','sectPr'): continue
        keep.append(tag+str(sorted((k.split('}')[1],v) for k,v in c.attrib.items()))+''.join(g.tag.split('}')[1]+str(sorted((k.split('}')[1],v) for k,v in g.attrib.items())) for g in c))
    return '|'.join(sorted(keep))
def rpr_sig(e):
    sigs=collections.Counter()
    for r in e.iter(qn('w:r')):
        rpr=r.find(qn('w:rPr'))
        if rpr is None: sigs['']+=1; continue
        sigs['|'.join(sorted(c.tag.split('}')[1]+str(sorted((k.split('}')[1],v) for k,v in c.attrib.items())) for c in rpr))]+=1
    return sigs.most_common(1)[0][0] if sigs else ''
def load(p):
    d=Document(p); styles={s.style_id:s.name for s in d.styles}; rows=[]; ch=''
    for e in d.element.body.iterchildren():
        if e.tag==qn('w:p'):
            st=e.find(qn('w:pPr')+'/'+qn('w:pStyle')); s=styles.get(st.get(qn('w:val')),'') if st is not None else ''
            t=''.join(x.text or '' for x in e.iter(qn('w:t'))).strip()
            if s=='Heading 1': ch=t
            img=e.find('.//'+qn('w:drawing')) is not None
            ext=e.find('.//'+qn('wp:extent'))
            rows.append(dict(kind='P',style=s,text=t,img=img,ch=ch,ppr=ppr_sig(e),rpr=rpr_sig(e),ext=(ext.get('cx'),ext.get('cy')) if ext is not None else None))
        elif e.tag==qn('w:tbl'):
            tp=e.find(qn('w:tblPr'))
            rows.append(dict(kind='T',style='',text=''.join(x.text or '' for x in e.iter(qn('w:t')))[:200],img=False,ch=ch,ppr=etree.tostring(tp,encoding='unicode')[:0] if tp is not None else '',rpr='',ext=None))
        else:
            rows.append(dict(kind=e.tag.split('}')[1],style='',text='',img=False,ch=ch,ppr='',rpr='',ext=None))
    return d,rows
da,a=load(A); db,b=load(B)
key=lambda r:(r['kind'],r['text'] if not r['text'][-3:].isdigit() else r['text'])
sm=difflib.SequenceMatcher(None,[(r['kind'],r['text']) for r in a],[(r['kind'],r['text']) for r in b],autojunk=False)
fmt=collections.Counter(); ex={}
textdiff=[]
for op,i1,i2,j1,j2 in sm.get_opcodes():
    if op=='equal':
        for x,y in zip(a[i1:i2],b[j1:j2]):
            if x['ppr']!=y['ppr']:
                k=('ppr',x['style'],x['ppr'][:160],y['ppr'][:160]); fmt[k]+=1; ex.setdefault(k,(x['ch'],x['text'][:30]))
            if x['rpr']!=y['rpr']:
                k=('rpr',x['style'],x['rpr'][:160],y['rpr'][:160]); fmt[k]+=1; ex.setdefault(k,(x['ch'],x['text'][:30]))
            if x['ext']!=y['ext']:
                k=('img',x['ch']); fmt[k]+=1; ex.setdefault(k,(x['ext'],y['ext']))
    else:
        textdiff.append((op,[ (r['ch'][:6],r['kind'],r['style'][:8],r['text'][:70]) for r in a[i1:i2]],[ (r['ch'][:6],r['kind'],r['style'][:8],r['text'][:70]) for r in b[j1:j2]]))
json.dump(textdiff,open('/tmp/smb_textdiff.json','w'),ensure_ascii=False,indent=1)
print('FORMAT DIFFS (count, key, example)')
for k,v in fmt.most_common(40): print(v,k,ex[k])
print('text diff blocks',len(textdiff))
