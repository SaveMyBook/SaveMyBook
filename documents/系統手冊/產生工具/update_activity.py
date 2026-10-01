"""5-3 使用個案描述：只保留各使用個案之活動圖（圖 5-3-N），原使用個案標題、描述表與表名移除（2026-10-01 比照複評版排版）。
活動圖原始碼與圖檔置於 scratchpad/activity，並同步複製至 Diagrams/Activity diagram/v3。"""
import copy
import os
import re
from docx.shared import Cm
from docx.oxml.ns import qn
from doctools import W, text_of, set_para, new_picture_para
from review_lib import keep_next, replace_in

HERE = os.path.dirname(os.path.abspath(__file__))
ACT = os.path.join(HERE, 'activity')
CAP_RE = re.compile(r'^表 5-3-(\d+) (.+)使用個案描述表$')


def _is_caption(p, prefix):
    st = p.find(W('pPr') + '/' + W('pStyle'))
    return st is not None and st.get(W('val')) == 'afb' and text_of(p).startswith(prefix)


def run(doc):
    body = list(doc.element.body.iterchildren())
    fig_cap = next(p for p in body if p.tag == W('p') and _is_caption(p, '圖 5-2-1 '))
    img_tpl = fig_cap.getprevious()
    assert img_tpl.find('.//' + W('drawing')) is not None
    added = 0
    uc03 = next(p for p in body if p.tag == W('p') and _is_caption(p, '表 5-3-3 ')).getnext()
    for _ in range(2):
        replace_in(uc03, '「復原」', '「還原」')
    uc21 = next(p for p in body if p.tag == W('p') and _is_caption(p, '表 5-3-21 ')).getnext()
    replace_in(uc21, '「操作紀錄」頁', '「管理操作紀錄」頁')
    replace_in(uc21, '點擊「復原」', '點擊「還原此操作」')
    uc25 = next(p for p in body if p.tag == W('p') and _is_caption(p, '表 5-3-25 ')).getnext()
    replace_in(uc25, 'App收到429時依等待秒數延後重試', 'App收到429時顯示「操作過於頻繁」並告知重試等待秒數')
    uc12 = next(p for p in body if p.tag == W('p') and _is_caption(p, '表 5-3-12 ')).getnext()
    replace_in(uc12, '「幫助中心」', '「客服中心」')
    uc14 = next(p for p in body if p.tag == W('p') and _is_caption(p, '表 5-3-14 ')).getnext()
    replace_in(uc14, '於安全中心點擊', '於「帳號安全」點擊')
    uc28 = next(p for p in body if p.tag == W('p') and _is_caption(p, '表 5-3-28 ')).getnext()
    replace_in(uc28, 'App於換發新權杖後重試', 'App約30秒後以最新權杖重新連線')
    removed = []
    for el in body:
        if el.tag != W('p'):
            continue
        m = CAP_RE.match(text_of(el).strip())
        if not m or not _is_caption(el, '表 5-3-'):
            continue
        tbl = el.getnext()
        if tbl is None or tbl.tag != W('tbl'):
            continue
        num, title = int(m.group(1)), m.group(2)
        png = os.path.join(ACT, f'uc{num:02d}.png')
        if not os.path.exists(png):
            raise FileNotFoundError(png)
        img = new_picture_para(doc, img_tpl, png, Cm(18), Cm(23))
        keep_next(img)
        cap = copy.deepcopy(fig_cap)
        set_para(cap, f'圖 5-3-{num} {title}之活動圖')
        tbl.addnext(img)
        img.addnext(cap)
        head = el.getprevious()
        if head is not None and re.match(r'^UC-\d{2}\u3000', text_of(head).strip()):
            removed.append(head)
        removed.extend([el, tbl])
        added += 1
    for e in removed:
        e.getparent().remove(e)
    return added

