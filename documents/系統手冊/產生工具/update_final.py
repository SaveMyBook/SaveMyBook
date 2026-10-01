"""最終版稽核：原稿文字中與最終系統不符之處（爭議用語、畫面名稱、使用手冊步驟），於 update_part4 之後、重建圖表目錄之前套用。"""
import re
from docx.oxml.ns import qn
from doctools import W, text_of, tcs, set_cell, set_para, row_by_key
from doclib import captioned_tables

META = re.compile(r'^表 8-2-\d+ (\S+) ')


def _replace_once(ts, old, new):
    full = ''.join(t.text or '' for t in ts)
    k = full.find(old)
    if k < 0: return False
    end, pos, first = k + len(old), 0, True
    for t in ts:
        txt = t.text or ''
        a, b = pos, pos + len(txt)
        pos = b
        if b <= k or a >= end: continue
        s0, s1 = max(k, a) - a, min(end, b) - a
        t.text = txt[:s0] + (new if first else '') + txt[s1:]
        t.set(qn('xml:space'), 'preserve')
        first = False
    return True


def _is_list_entry(p):
    st = p.find(W('pPr') + '/' + W('pStyle'))
    return st is not None and st.get(W('val')) == 'afd'


def replace_all(doc, old, new, expect=None):
    n = 0
    for p in doc.element.body.iter(W('p')):
        if _is_list_entry(p): continue
        ts = list(p.iter(W('t')))
        while _replace_once(ts, old, new): n += 1
    assert n and (expect is None or n == expect), (old, n)
    return n


def _manual_table(doc, heading):
    body = list(doc.element.body.iterchildren())
    for i, el in enumerate(body):
        if el.tag == W('p') and text_of(el).strip() == heading:
            return next(nxt for nxt in body[i + 1:] if nxt.tag == W('tbl'))
    raise KeyError(heading)


def _heading(doc, old, new):
    p = next(p for p in doc.paragraphs if p.text.strip() == old)
    set_para(p._p, new)


def _step(tbl, n, text):
    set_cell(tcs(row_by_key(tbl, str(n)))[1], text)


def run(doc):
    stats = {}
    # --- 交易爭議用語（原稿文字）---
    for old, new, expect in [
        ('含退款、申訴、錢包交易明細', '含退款、爭議、錢包交易明細', 1),
        ('交易申訴仲裁', '交易爭議仲裁', 2),
        ('爭議申訴時限窗口', '爭議申請期限', 1),
        ('交易仲裁/申訴表', '交易爭議表', 2),
        ('記錄交易申訴案件之詳細資訊', '記錄交易爭議案件之詳細資訊', 1),
    ]:
        stats[old] = replace_all(doc, old, new, expect)

    T = captioned_tables(doc)
    td = next(v._tbl for k, v in T.items() if META.match(k) and META.match(k).group(1) == 'transaction_disputes')
    for col, text in [('dispute_id', '交易爭議編號'), ('applicant_id', '申請人'), ('reason', '爭議說明')]:
        set_cell(tcs(row_by_key(td, col))[1], text)

    routes = next(v._tbl for k, v in T.items() if k.endswith('API路由掛載對照表'))
    set_cell(tcs(row_by_key(routes, '/api/orders'))[2], '訂單查詢、結帳與直接購買、取消與狀態更新')
    set_cell(tcs(row_by_key(routes, '/api/disputes'))[2], '交易爭議申請（以訂單編號指定訂單）')
    stats['chat_sections'] = replace_all(doc, '連結預覽（8個子模組）', '連結預覽（7個子模組）', 1)
    limits = next(v._tbl for k, v in T.items() if k.endswith('AI功能每位使用者每日呼叫上限表'))
    set_cell(tcs(row_by_key(limits, 'AI書籍顧問'))[1], '20次／日')

    # --- 使用個案（原稿文字）：畫面名稱與流程 ---
    for old, new in [
        ('• 第三方登入時，若該Email已被其他登入方式註冊，系統要求使用者改用「連結既有帳號」流程。',
         '• 第三方登入時，若該Email已被其他登入方式註冊，系統提示此電子郵件已註冊，由使用者以密碼或通行密鑰「登入並綁定」。'),
        ('• 第三方登入時，若查無對應帳號，系統詢問是否建立新帳號，並導向補填暱稱/頭像頁面。',
         '• 第三方登入時，若查無對應帳號，系統詢問「登入既有帳號並綁定」或「建立新帳號」；建立新帳號時導向「完成帳號資料」頁，填寫電子郵件與暱稱並同意服務條款與隱私權政策。'),
        ('買家於聊天室內請求「保留此書」一段時間；', '買家於聊天室內點擊「預約書籍」，請求保留此書一段時間；'),
        ('系統建立工單（狀態「處理中」）', '系統建立工單（狀態「待處理」）'),
        ('工單狀態轉為「待使用者回覆」', '工單狀態轉為「客服已回覆」'),
        ('（選用）賣家點擊「AI輔助」', '（選用）賣家點擊「AI帶入」'),
        ('選擇欲下架之書籍，點擊「下架」', '選擇欲下架之書籍，點擊「取消上架」'),
        ('使用者於「帳號與隱私」頁點擊「刪除帳號」', '使用者於「帳號管理」頁點擊「刪除帳號」'),
    ]:
        stats[old[:12]] = replace_all(doc, old, new, 1)

    # --- 使用手冊 ---
    m = _manual_table(doc, '註冊與登入')
    _step(m, 1, '首次使用App時進入登入頁（LoginScreen），可使用電子郵件與密碼、通行密鑰登入，或依後台開放之登入方式以Google、Apple、LINE、Discord或手機號碼登入；已啟用生物辨識登入者，可直接以Face ID或指紋登入。')
    _step(m, 2, '尚未擁有帳號者，點擊登入頁下方「尚無帳號？立即註冊」，或以尚未註冊之電子郵件登入時於提示視窗點擊「前往註冊」，進入註冊頁填寫電子郵件、暱稱、密碼與確認密碼，勾選同意服務條款與隱私權政策後點擊「建立帳號」；註冊成功後返回登入頁並帶入電子郵件，以新帳號登入。')
    _step(m, 3, '以第三方帳號首次登入且尚未綁定帳號時，可選擇「登入既有帳號並綁定」或「建立新帳號」；建立新帳號時於「完成帳號資料」頁填寫電子郵件與暱稱，並同意服務條款與隱私權政策。')

    m = _manual_table(doc, '上架書籍（賣家）')
    _step(m, 3, '（選用）點擊「AI帶入」，上傳書況照片後由AI建議書況描述、分類與建議售價，可直接套用或自行修改。')
    m = _manual_table(doc, '編輯與下架商品')
    _step(m, 3, '點擊「取消上架」可暫時將商品自平台移除，取消上架後可立即點擊「復原」，日後亦可點擊「重新上架」（違規遭下架者除外，須聯絡客服）。')
    m = _manual_table(doc, '聊天協商、預約與轉帳')
    _step(m, 3, '議定價格後，可直接於聊天室點擊「轉帳」或「請款」完成收付款，系統會要求輸入交易密碼或生物辨識驗證。')
    _step(m, 4, '亦可使用「AI書籍顧問」，描述需求（分類、預算、書況等）取得系統推薦之書籍清單。')
    m = _manual_table(doc, '客服與常見問題')
    _step(m, 1, '於「幫助中心」可查詢常見問題(FAQ)；若未能解決問題，可使用「AI客服」立即對話，或於AI客服對話中點擊「轉接客服人員」、於幫助中心點擊「聯絡客服」，建立正式工單並等待回覆。')
    stats['安全中心'] = replace_all(doc, '「安全中心」', '「帳號安全」')
    _heading(doc, '安全中心與交易密碼', '帳號安全與交易密碼')
    stats['登入裝置管理'] = replace_all(doc, '「登入裝置管理」', '「登入裝置」', 2)
    m = _manual_table(doc, '通知偏好設定')
    _step(m, 3, '管理員可傳送測試通知，以確認裝置推播設定是否正常。')
    m = _manual_table(doc, '帳號資料匯出與刪除')
    stats['帳號與隱私'] = replace_all(doc, '於「帳號與隱私」頁可匯出個人資料', '於「帳號管理」頁點擊「匯出我的資料」可匯出個人資料', 1)
    stats['後台管理'] = replace_all(doc, '可見「後台管理」入口', '可見「管理後台」入口', 1)

    # 交易爭議之「申訴」一律改為「爭議」；其餘出現處須逐一檢視
    left = [text_of(p)[:60] for p in doc.element.body.iter(W('p')) if '申訴' in text_of(p) and not _is_list_entry(p)]
    assert not left, left
    return stats
