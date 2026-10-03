"""依初評評審意見補強第一、二章，並使兩章與現行系統一致（2026-09-29）。
新增之 2-5～2-8 節接在 2-4 節之後，既有章節與圖表編號不變；格式比照原稿（二級標題換頁、「1.」小標、➢ 條列、表名在上、圖名在下）。"""
import copy
import os
from doctools import W, text_of, tcs, set_para
from review_lib import (Templates, Writer, chapter_range, para, table_after, replace_in, clone_para,
                        fill_cell, keep_next)
import review_sections

HERE = os.path.dirname(os.path.abspath(__file__))


def _set_text(els, prefix, text):
    set_para(para(els, prefix), text)


def _insert_bullet_after(els, prefix, text):
    ref = para(els, prefix)
    new = clone_para(ref, text)
    ref.addnext(new)
    return new


def edit_chapter1(doc, T):
    ch1 = chapter_range(doc, '前言', '營運計畫')

    # 表 1-2-1：於 SaveMyBook 之後新增 TAAZE 讀冊生活欄
    grid = table_after(para(ch1, '表 1-2-1 '))
    values = {'平台': 'TAAZE讀冊生活', 'ISBN掃描上架': '', '即時聊天': '', '實體智取櫃': '', '圖書精準分類': 'V',
              '代幣化交易': '', '即時付款': 'V', '會員等級': 'V', '個人化推薦': 'V'}
    widths = [19, 15, 13.2, 13.2, 13.2, 13.2, 13.2]
    g = grid.find(W('tblGrid'))
    cols = g.findall(W('gridCol'))
    new_col = copy.deepcopy(cols[2]); cols[1].addnext(new_col)
    for gc, w in zip(g.findall(W('gridCol')), widths):
        gc.set(W('w'), str(round(10194 * w / 100)))
    for tr in grid.findall(W('tr')):
        cells = tcs(tr)
        key = text_of(cells[0]).strip().split('\n')[0]
        key = '平台' if key.startswith('平台') else key
        new = copy.deepcopy(cells[2])
        cells[1].addnext(new)
        run = next(iter(cells[1].iter(W('r'))), None)
        rpr = copy.deepcopy(run.find(W('rPr'))) if run is not None else T.run_rpr
        fill_cell(new, values[key], rpr, 'center')
        for tc, w in zip(tcs(tr), widths):
            tc.find(W('tcPr') + '/' + W('tcW')).set(W('w'), str(round(w * 50)))
    replace_in(para(ch1, '透過表1-2-1對市面上常見二手書交易平台的分析'),
               '缺乏圖書精準分類、即時線上付款與個人化推薦等完整的輔助機制。',
               '缺乏圖書精準分類、即時線上付款與個人化推薦等完整的輔助機制；TAAZE讀冊生活則採二手書委託寄賣模式，'
               '賣家須將書籍寄送至平台倉庫，由平台統一鑑定書況、上架與出貨，雖具備精準分類、即時付款、會員等級與個人化推薦，'
               '但賣家無法與買家直接溝通，亦無就近自助存取之實體書櫃。')

    # 1-3 系統目的與目標
    _set_text(ch1, '本系統旨在提供更便捷的二手書籍交易體驗',
              '本系統旨在提供更便捷的二手書籍交易體驗，以使用者角度為出發點，致力於滿足其對交易流程簡化與個人化服務之需求。'
              '系統採分階段開發策略，現階段已完成核心交易、智慧書櫃掃碼存取與AI輔助功能，後續將串接第三方支付，'
              '並擴充合作夥伴管理與營運效益分析功能。具體核心目標如下：')
    _set_text(ch1, '簡化交易流程：',
              '簡化交易流程：透過ISBN條碼掃描與AI上架輔助，自動帶入書目資料並提供書況與售價建議，大幅減少賣家上架書籍所需的操作步驟。')
    _set_text(ch1, '打破時空限制：',
              '打破時空限制：結合自製智慧書櫃，依場域開放時間（最長24小時）提供自助存取與非同步取貨服務，消除面交的時間協調成本。')
    _set_text(ch1, '提升使用體驗：',
              '提升使用體驗：導入個人化書籍推薦、AI書籍顧問與AI客服，並以直覺化使用者介面設計降低新用戶的學習曲線，提高留存率。')
    _set_text(ch1, '強化交易安全：',
              '強化交易安全：以站內代幣錢包結帳，款項由平台暫管，至買家取書後24小時爭議期屆滿始撥付賣家；存取書籍須於書櫃旁'
              '掃描QR Code、輸入書櫃螢幕顯示之數字並通過定位檢查，保障買賣雙方權益。')

    # 1-4 預期成果
    _set_text(ch1, '本系統預期能透過ISBN條碼掃描技術',
              '本系統預期能透過ISBN條碼掃描技術與AI上架輔助，實現二手書籍的快速上架，大幅簡化賣方的操作流程。在硬體整合方面，'
              '本系統以合板製作櫃體、以壓克力雷射切割正面面板與櫃門，結合ESP32-S3微控制器、電磁鎖與顯示螢幕，自主開發每台四扇櫃門之實體智慧書櫃，'
              '藉此提供低成本的實物驗證機制與非同步取貨服務，有效突破傳統面交的時空限制。此外，透過會員等級制度的設計，'
              '不僅能賦予使用者專屬的尊榮感，更能有效提升平台黏著度。')
    _set_text(ch1, '在後續開發階段，本專案將進一步導入區塊鏈',
              '在金流方面，系統以站內代幣錢包完成結帳、款項暫管、撥款與退款；後續將串接持有電子支付機構執照之第三方支付業者'
              '辦理儲值與提領，依商業模式收取交易服務費，並建置合作夥伴管理與營運效益分析功能，作為系統商品化之基礎。')


def _set_items(tc, title, items):
    ps = tc.findall(W('p'))
    title_p, item_tpl = ps[0], ps[1]
    for p in ps[1:]:
        tc.remove(p)
    set_para(title_p, title)
    for it in items:
        p = copy.deepcopy(item_tpl)
        set_para(p, it)
        tc.append(p)


def edit_chapter2(doc, T):
    ch2 = chapter_range(doc, '營運計畫', '系統規格')

    # 2-1 可行性分析
    _set_text(ch2, '資料庫管理：',
              '資料庫管理：使用MariaDB（與MySQL相容）儲存結構化資料，並導入Prisma ORM進行資料庫建模與結構同步，提升程式碼的可維護性與開發效率。')
    _set_text(ch2, 'API開發與調試：',
              'API開發與調試：以OpenAPI規格撰寫API文件並透過Scalar提供線上文件，搭配Postman進行介面測試，確保後端邏輯的正確性與介接便利性。')
    _set_text(ch2, '物聯網與硬體整合：',
              '物聯網與硬體整合：書櫃主體以合板組裝，正面面板與櫃門以壓克力雷射切割，先以CAD建模確認尺寸與公差，具備高度客製化與低成本模組化優勢。'
              '每台書櫃以一片ESP32-S3微控制器控制四組電磁鎖與顯示螢幕，透過HTTPS與雲端後台同步狀態，實現掃碼開櫃、關門回報與故障告警等自動化功能'
              '（設備可行性與妥善率詳見2-7節）。')
    _insert_bullet_after(ch2, '物聯網與硬體整合：',
                         'AI服務整合：串接OpenAI、Google Gemini與DeepSeek等服務並可切換供應商，提供上架內容審核、書籍資料補齊、'
                         'AI客服、AI書籍顧問與個人化推薦，並設有每月預算上限與服務異常時之備援處理。')
    _set_text(ch2, '低成本開發模式：',
              '低成本開發模式：不同於傳統二手書店需負擔高昂店租與人力成本，本系統以合板與雷射切割之壓克力製作櫃體，搭配低價之ESP32-S3微控制器與電磁鎖，'
              '大幅降低實體書櫃的建置費用；建置與營運成本之量化評估詳見2-6節。')
    _set_text(ch2, '明確驗證機制：',
              '安全存取機制：使用者須於書櫃旁以App掃描書櫃螢幕上的QR Code、輸入螢幕顯示之兩位數字並通過定位檢查（200公尺內）後始開啟櫃門，'
              '關門後系統自動完成存書或取書登記，減少人為疏失與後續爭議。')
    _set_text(ch2, '個資保護與隱私機制：',
              '個資保護與隱私機制：依《個人資料保護法》第5條、第19條及第27條（安全維護義務），系統採取最小蒐集原則：密碼以雜湊演算法儲存、'
              '對外顯示之編號以加密編號取代資料庫流水號、書櫃定位僅保存距離與精度而不保存經緯度，並於帳號刪除時將個人資料匿名化；'
              '資料庫僅開放內部網路連線，符合《個資法》對資料最小化與安全維護之要求。')
    _set_text(ch2, '爭議調解機制：',
              '爭議調解機制：依《民法》第354條（物之瑕疵擔保責任），買賣雙方於訂單完成前（買家取書後24小時內）均得於App申請爭議並上傳佐證照片，'
              '訂單即轉為爭議處理中並暫停撥款，由管理員參考雙方說明、書況照片與書櫃作業紀錄進行仲裁，裁決結果包含退款、駁回或協調結案，保障交易雙方權益。')
    deposit = _insert_bullet_after(ch2, '爭議調解機制：',
                         '交易契約與存書收回：賣家先行存書係將書籍交由平台智慧書櫃保管，屬《民法》第589條之寄託關係。存書滿7日未售出即暫停販售並通知賣家取回，'
                         '其後每3日提醒；滿14日仍未取回者，平台得派員取出書籍並終止該書之刊登與寄託關係，派員取出之人力成本由平台負擔。'
                         '書籍取出後由平台代為保管30日，賣家得至平台指定地點免費領回，或申請寄回並自行負擔運費（貨到付款）；逾期未領回者，'
                         '視為賣家拋棄該書之所有權（《民法》第764條），平台得捐贈或回收。書籍暫停販售後即不再成立新訂單，已成立之訂單仍依訂單流程辦理；'
                         '上述規定明定於服務條款，並於暫停、提醒與取出等階段以推播及站內通知告知賣家。')

    deposit.addnext(clone_para(deposit,
                         '金流法規遵循：依《電子支付機構管理條例》第4條及第5條，收受儲值款項限由電子支付機構經營，違者依第46條處以刑責；'
                         '代理收付實質交易款項則於保管總餘額未逾新臺幣20億元且未兼營儲值及匯兌業務時，得免申請許可。系統現行之代幣錢包屬校園試營運之站內結算機制，'
                         '商品化階段將串接持有執照之電子支付機構或第三方支付業者辦理儲值、代理收付與提領，平台不自行保管使用者資金（詳見2-5節）。'))

    # 2-2 商業模式
    bm = table_after(para(ch2, '表 2-2-1 '))
    rows = bm.findall(W('tr'))
    c0, c1, c2 = tcs(rows[0]), tcs(rows[1]), tcs(rows[2])
    _set_items(c0[0], '關鍵合作夥伴', ['場域提供者', '木材與壓克力加工供應商', '圖書數據API供應商', 'AI服務供應商', '雲端與推播服務', '第三方支付機構（規劃）'])
    _set_items(c0[1], '關鍵活動', ['技術開發', '硬體整合', '場域驗證', '維修巡檢', '客服與爭議處理'])
    _set_items(c0[2], '價值主張', ['交易透明', '全自動無人化', '自助取件', '低抽成、快速撥款', '綠色校園永續'])
    _set_items(c0[3], '顧客關係', ['爭議處理機制', '會員等級制度', 'AI客服'])
    _set_items(c1[1], '關鍵資源', ['書籍數據庫', '技術團隊', '硬體設施', 'AI模型服務'])
    _set_items(c2[0], '成本結構', ['硬體建置與零件維修', '書櫃電費與網路', '雲端伺服器與網域', 'AI服務費用', '開發與維運人力', '行銷推廣費（初期）'])
    _set_items(c2[1], '收益流', ['交易服務費（成交金額10%）', '智慧書櫃廣告位', '場域合作方案（規劃）'])
    replace_in(para(ch2, '本系統透過IoT智慧書櫃結合App訂單管理機制'),
               '系統初期以驗證流程穩定性與使用者體驗為主要目標，奠定後續擴充之基礎。',
               '系統初期以校園場域驗證流程穩定性與使用者體驗，商品化階段則以成交金額10%之交易服務費與書櫃廣告為主要收益來源，'
               '成本與收益之量化評估詳見2-6節。')

    # 2-3 STP
    replace_in(para(ch2, '行為區隔：'), '透過會員等級審核機制', '透過會員等級、交易紀錄與爭議處理機制')

    # 2-4 SWOT／TOWS
    replace_in(para(ch2, '解決交易痛點：'), '透過自動化金流託管與實體書櫃', '透過站內錢包暫管款項（取書後撥款）與實體書櫃')
    _insert_bullet_after(ch2, '整合自動辨識機制：',
                         'AI輔助服務：提供AI上架輔助、書籍資料補齊、AI客服與AI書籍顧問，降低操作門檻並提升媒合效率。')
    _insert_bullet_after(ch2, '物流便利性受限：',
                         '金流功能待擴充：目前儲值須由客服協助辦理且尚無提領功能，需串接第三方支付後方能完整商品化。')
    tows = table_after(para(ch2, '表 2-4-1 '))
    replace_in(tows, '採取模組化分階段上線（先驗證金流，再串接實體櫃）',
               '採取模組化分階段上線（交易流程與實體書櫃已完成串接，第三方支付與合作夥伴功能再依序導入）')
    return tows


def run(doc):
    T = Templates(doc)
    edit_chapter1(doc, T)
    tows = edit_chapter2(doc, T)
    w = Writer(doc, T, tows)
    n = review_sections.add(w, HERE)
    edit_chapters34(doc)
    return n, add_references(doc)


REF_COST_GROUP = '成本估算、硬體規格與法規'
REF_COST = [
    'DigitalOcean. (n.d.). Droplet pricing. https://www.digitalocean.com/pricing/droplets',
    'Espressif Systems. (2026). ESP32-S3 series datasheet (Version 2.2). https://documentation.espressif.com/esp32-s3_datasheet_en.pdf',
    'Handson Technology. (n.d.). SRD-05VDC-SL-C relay datasheet. https://www.handsontec.com/dataspecs/relay/SRD-05VDC-SL-C.pdf',
    'Kendrion. (n.d.). Locking solenoids [Product brochure]. https://www.kendrion.com/fileadmin/user_upload/Downloads/Brochures_and_Flyers/Electromagnets_Actuators/Locking-Solenoids-Kendrion-EN.pdf',
    'UCI電子（無日期）。（D-53）LY-03電磁鎖 小型電控鎖防水櫃門鎖。https://www.ucielectronics.com/products/%E3%80%90uci%E9%9B%BB%E5%AD%90%E3%80%91d-53-ly-03%E9%9B%BB%E7%A3%81%E9%8E%96-%E5%B0%8F%E5%9E%8B%E9%9B%BB%E6%8E%A7%E9%8E%96%E9%98%B2%E6%B0%B4%E6%AB%83%E9%96%80%E9%8E%96-%E9%9B%BB%E5%AD%90%E9%96%80%E7%A6%81%E9%8E%96-%E7%A3%81%E5%8A%9B%E9%8E%9612v%E9%9B%BB%E5%AD%90%E9%8E%96',
    '木百貨（無日期）。5mm 透明壓克力 60x90cm。https://woodmall.com.tw/shop/product/5mm-%E9%80%8F%E6%98%8E-%E5%A3%93%E5%85%8B%E5%8A%9B-60x90cm/',
    '米羅科技（無日期）。2.8寸觸控式螢幕。https://shop.mirotek.com.tw/shop/400300/',
    '全國法規資料庫（2023）。電子支付機構管理條例。https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0380237',
    '開店趣 Bboss（2026）。營業用電一度多少錢？營業用電試算。https://www.bboss.com.tw/article/%E9%9B%BB%E5%83%B9-%E7%87%9F%E6%A5%AD%E7%94%A8%E9%9B%BB-%E4%B8%80%E5%BA%A6%E9%9B%BB%E5%A4%9A%E5%B0%91%E9%8C%A2/',
    '勞動部（2025）。最低工資連十漲！審議會決定自115年1月1日起，每月最低工資調升至29,500元，每小時最低工資調升至196元。https://www.mol.gov.tw/1607/1632/1633/84947/post',
    '極客雷射（無日期）。關於極客。https://geeklaser1111.com/%E9%97%9C%E6%96%BC%E6%A5%B5%E5%AE%A2/',
    '綠界科技（無日期）。服務費率表。https://www.ecpay.com.tw/Business/payment_fees',
    '網建行興業（無日期）。木板3尺*6尺*厚9mm足。https://www.wj-design.com.tw/products/info.php?id=1276&title_id=154',
    '臺灣銀行（2026）。新臺幣匯率牌告。https://rate.bot.com.tw/xrt?Lang=zh-TW',
    '廣華電子（無日期）。12V 54x41x27mm迷你電鎖。https://shop.cpu.com.tw/product/52725/info/',
    '聯騰電子（無日期）。ESP32-S3-N16R8 WiFi藍牙開發板。https://www.ltc.com.tw/products/esp32-s3-n16r8-wifi%E8%97%8D%E7%89%99-%E9%96%8B%E7%99%BC%E6%9D%BF',
]


def add_references(doc):
    body = list(doc.element.body.iterchildren())
    start = body.index(heading1_el(doc, '參考資料'))
    refs = [e for e in body[start:] if e.tag == W('p')]
    groups = [e for e in refs if text_of(e).strip() in ('商業模式與策略分析', '系統分析與UML建模')]
    assert len(groups) == 2
    head = clone_para(groups[0], REF_COST_GROUP)
    entry_tpl = groups[0].getnext()
    groups[1].addprevious(head)
    cur = head
    for text in REF_COST:
        p = clone_para(entry_tpl, text)
        cur.addnext(p)
        cur = p
    return len(REF_COST)


def heading1_el(doc, title):
    from review_lib import heading1
    return heading1(doc, title)


def edit_chapters34(doc):
    """櫃體改為合板加壓克力雷射切割（不再使用 3D 列印），控制板改為 ESP32-S3。"""
    ch3 = chapter_range(doc, '系統規格', '專案時程與組織分工')
    ch4 = chapter_range(doc, '專案時程與組織分工', '需求模型')
    tools = table_after(para(ch3, '表 3-3-1 '))
    replace_in(tools, '圖形與3D設計', '圖形與機構設計')
    replace_in(tools, '3D建模與切片', '機構建模與雷切圖檔')
    replace_in(tools, 'SolidWorks 2025、Tinkercad、Bambu Studio', 'SolidWorks 2025（繪製櫃體並輸出雷射切割用DXF圖檔）')
    replace_in(tools, 'Arduino', 'PlatformIO、ESP-IDF')
    duty = table_after(para(ch4, '表 4-2-1 '))
    for old, new in (('ESP32韌體', 'ESP32-S3韌體'), ('3D建模', '機構建模'), ('3D切片', '雷切圖檔製作'), ('列印後處理', '櫃體組裝'),
                     ('3D列印', '壓克力雷射切割')):
        replace_in(duty, old, new)
    # 木作裁切另列一項，負責人待團隊填寫
    laser = next(tr for tr in duty.findall(W('tr')) if '壓克力雷射切割' in text_of(tr))
    wood = copy.deepcopy(laser)
    cells = tcs(wood)
    for t in cells[1].iter(W('t')):
        t.text = ''
    next(cells[1].iter(W('t'))).text = '木作裁切'
    for tc in cells[2:]:
        for t in tc.iter(W('t')):
            t.text = ''
    laser.addprevious(wood)
    work = table_after(para(ch4, '表 4-2-2 '))
    replace_in(work, 'ESP32韌體', 'ESP32-S3韌體')
    replace_in(work, '電磁鎖控制與3D列印全流程', '電磁鎖控制與櫃體設計、壓克力雷射切割及組裝全流程')
