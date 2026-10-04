"""書櫃交通資訊（「前往書櫃」頁，資料取自臺北市資料大平臺）與新增書櫃取得目前座標之手冊內容（2026-10-02）。

分三段套用：
- add_use_cases()：於 update_activity 之前新增 UC-35、UC-36 之使用個案描述表，由 update_activity 換成活動圖（activity/uc35、uc36）。
- run()：於用詞修正（update_terms）與去重之後、排版之前，修改內文與各表；放在用詞修正之後，避免以整段改寫覆蓋修正後之用詞。
- finalize()：於套用 1001 版排版之後，新增之圖頁比照前一張圖之段落格式（分頁、不跨頁、間距）。
循序圖 6-1-32 由 update_part1.SEQ_FIGS 產生，說明在 seqdesc.SEQ。
"""
import copy
from doctools import W, text_of, set_para, set_cell, tcs, row_by_key, clone_row_after
from doclib import captioned_tables
from review_lib import clone_para

UC_NEW = [
    (35, '查看前往書櫃交通資訊'),
    (36, '新增與編輯書櫃據點'),
]


def _caption_el(doc, prefix):
    for p in doc.paragraphs:
        if p.style.name != 'table of figures' and p.text.strip().startswith(prefix):
            return p._p
    raise KeyError(prefix)


def add_use_cases(doc):
    cap = _caption_el(doc, '表 5-3-34 ')
    tbl = cap.getnext()
    head = cap.getprevious()
    assert tbl.tag == W('tbl') and text_of(head).strip().startswith('UC-34')
    anchor = tbl
    for num, title in UC_NEW:
        h, c, t = copy.deepcopy(head), copy.deepcopy(cap), copy.deepcopy(tbl)
        set_para(h, f'UC-{num}　{title}')
        set_para(c, f'表 5-3-{num} {title}使用個案描述表')
        anchor.addnext(h); h.addnext(c); c.addnext(t)
        anchor = t
    return len(UC_NEW)


def _table(doc, prefix):
    T = captioned_tables(doc)
    return next(v._tbl for k, v in T.items() if k.startswith(prefix + ' '))


def _row(tbl, prefix, col=0):
    for tr in tbl.findall(W('tr')):
        c = tcs(tr)
        if len(c) > col and text_of(c[col]).strip().startswith(prefix):
            return tr
    raise KeyError(prefix)


def _set(tr, values):
    for tc, v in zip(tcs(tr), values):
        if v is not None:
            set_cell(tc, v)


def _after(tr, values):
    new = clone_row_after(tr)
    _set(new, values)
    return new


def _cell_text(tr, col):
    return '\n'.join(text_of(p) for p in tcs(tr)[col].findall(W('p')))


def _append_cell(tr, col, addition, before='。'):
    """在儲存格文字末尾（句號之前）補上一段。"""
    text = _cell_text(tr, col)
    assert addition not in text
    text = text[:-1] + addition + before if before and text.endswith(before) else text + addition
    set_cell(tcs(tr)[col], text)


def _para(doc, prefix):
    for p in doc.paragraphs:
        if p.style.name != 'table of figures' and p.text.strip().startswith(prefix):
            return p
    raise KeyError(prefix)


def _manual_block(doc, heading):
    body = list(doc.element.body.iterchildren())
    for i, el in enumerate(body):
        if el.tag == W('p') and text_of(el).strip() == heading:
            tbl = next(n for n in body[i + 1:] if n.tag == W('tbl'))
            return el, tbl
    raise KeyError(heading)


def _manual_section(doc, after_heading, heading, steps):
    """複製使用手冊之小節（標題與步驟表），接在 after_heading 小節之後。"""
    head, tbl = _manual_block(doc, after_heading)
    new_head, new_tbl = copy.deepcopy(head), copy.deepcopy(tbl)
    set_para(new_head, heading)
    rows = new_tbl.findall(W('tr'))
    tpl = rows[1]
    for r in rows[1:]:
        new_tbl.remove(r)
    for i, text in enumerate(steps, start=1):
        tr = copy.deepcopy(tpl)
        _set(tr, [str(i), text])
        new_tbl.append(tr)
    tbl.addnext(new_head)
    new_head.addnext(new_tbl)


DATASETS = [
    ('臺北大眾捷運股份有限公司', 2026, '臺北捷運系統票價', '4acb4911-0360-4063-808d-fcee629508b3'),
    ('臺北大眾捷運股份有限公司', 2026, '臺北捷運車站出入口座標', 'cfa4778c-62c1-497b-b704-756231de348b'),
    ('臺北大眾捷運股份有限公司', 2026, '臺北捷運車站出入口無障礙電梯、無障礙坡道GPS座標', '0a3bb422-9eb5-459b-a9d4-138456516183'),
    ('臺北市政府交通局', 2025, '計程車招呼站', 'a0cf5e08-2b46-46be-aaa6-ac894b439156'),
    ('臺北市政府交通局', 2025, '臺北市公車結構性票價資訊', '651f6f05-074c-4f7a-a9cf-a367c32aa60b'),
    ('臺北市政府交通局', 2025, '臺北市預估到站時間(公車)', 'f11a5af0-7b37-48ef-98cc-f6f102ed43c6'),
    ('臺北市政府交通局', 2025, '臺北市道路速率', 'b5aaf33a-a6dc-4836-bce6-09986241fe11'),
    ('臺北市政府交通局', 2026, 'YouBike2.0臺北市公共自行車即時資訊', 'c6bc8aed-557d-41d5-bfb1-8da24f78f2fb'),
    ('臺北市政府交通局', 2026, '臺北市停車場資訊', 'd5c0656b-5250-4179-a491-c94daa56ef2c'),
    ('臺北市政府交通局', 2026, '臺北市站牌', '62bc76da-6e6b-46ee-8976-c1945092d504'),
    ('臺北市政府交通局', 2026, '臺北市路邊停車格位', '5a911ea5-1694-4301-808e-e1780d971611'),
    ('臺北市政府交通局', 2026, '臺北市路邊停車格位使用情形', '434638ca-8770-42c1-940d-0386a74f6eb9'),
]
REF_GROUP = '政府開放資料'


def _references(doc):
    body = list(doc.element.body.iterchildren())
    group = next(e for e in body if e.tag == W('p') and text_of(e).strip() == '國家法律與政府規範')
    last = group.getnext()
    while last.getnext() is not None and last.getnext().tag == W('p') and text_of(last.getnext()).strip().startswith(('全國法規', '金融監督', '個人資料保護委員會')):
        last = last.getnext()
    head = clone_para(group, REF_GROUP)
    last.addnext(head)
    cur = head
    for org, year, title, pid in DATASETS:
        p = clone_para(last, f'{org}（{year}）。{title} [資料集]。臺北市資料大平臺。https://data.taipei/dataset/detail?id={pid}')
        cur.addnext(p)
        cur = p
    return len(DATASETS)


def run(doc):
    t = lambda prefix: _table(doc, prefix)

    # 3-1 系統架構
    p = _para(doc, 'RESTful API服務：')
    text = p.text.strip()
    anchor = '另以獨立之裝置API'
    assert anchor in text
    set_para(p._p, text.replace(anchor, '並依書櫃位置向臺北市資料大平臺取得捷運、公車、YouBike、停車與道路路況等交通開放資料，經快取後提供書櫃周邊交通資訊。' + anchor))

    # 3-2 不加列：表 3-2-4、3-2-5 已接近整頁，多一列會使 Word 把合併儲存格之列群拆到兩頁並留下大片空白。

    # 5-1 使用者需求
    x = t('表 5-1-1')
    _after(_row(x, '書櫃存取驗證與故障備援'), ['書櫃交通資訊',
        '使用者可於書籍詳情、訂單詳情或選定書櫃後點擊「交通資訊」進入「前往書櫃」頁，查看書櫃附近之捷運站與出口（含無障礙電梯或坡道）、'
        '自出發車站至該站之票價、公車站之即時到站、YouBike可借與可還數量、停車場剩餘車位、路邊停車格位與即時空位、周邊道路路況及計程車招呼站，'
        '並可開啟地圖導航。資料取自臺北市資料大平臺；出發車站依手機定位於手機上計算，不傳送使用者位置。'])
    x = t('表 5-1-2')
    _append_cell(_row(x, '智慧書櫃據點管理'), 1,
                 '；新增或編輯書櫃時，可於現場以「使用目前位置」填入書櫃座標並顯示定位精確度，再以「附近交通預覽」確認座標與地址相符')

    # 9-1-1 元件清單
    x = t('表 9-1-1')
    _set(_row(x, 'services/api/*_api.dart'), ['services/api/*_api.dart（28個檔案）', None, None])
    _append_cell(_row(x, 'jobs/scheduler.js'), 2, '、交通開放資料預載與路邊停車格位索引檢查(24h，索引逾30天重新下載建立)')
    last = x.findall(W('tr'))[-1]
    for values in [
        ('services/transit/（index, opendata, source, mrt, bus, youbike, parking, roadside, road）', '後端',
         '書櫃交通資訊：自臺北市資料大平臺下載捷運出入口與票價、無障礙電梯與坡道、公車站牌、預估到站與路線名稱、YouBike、停車場與剩餘車位、'
         '路邊停車格位與使用情形、道路速率及計程車招呼站資料；各來源獨立快取，過期才重新下載、同時之請求合併，下載失敗時沿用上次資料，'
         '並依書櫃位置以直線距離篩選周邊項目。路邊停車格位圖層（SHP）每月下載並建立格位索引，以路段編號對應即時空位。'),
        ('lib/geo.js, lib/twd97.js', '後端', '直線距離計算與經緯度方格索引；TWD97二度分帶座標轉換為WGS84經緯度。'),
        ('features/cabinet/cabinet_guide_screen.dart（Flutter）', '前端',
         '「前往書櫃」頁：書櫃資訊與導航、捷運出口與票價（出發車站依定位於手機上計算）、公車到站、YouBike、周邊路況、停車場、路邊停車與計程車招呼站，以及各頁面之「交通資訊」入口。'),
        ('models/transit.dart, services/api/transit_api.dart, utils/map_links.dart（Flutter）', '前端',
         '交通資訊資料模型與API呼叫，以及開啟Google地圖導航之共用函式。'),
        ('features/admin/admin_cabinet_edit_screen.dart（Flutter）', '前端',
         '新增與編輯書櫃：以「使用目前位置」填入座標並顯示定位精確度、於地圖上確認座標，以及附近交通預覽。'),
    ]:
        last = _after(last, list(values))

    # 9-2 套件、限流、錯誤代碼、權限與路由（表號已由 update_part4 重新編排）
    caps = {p.text.strip().split(' ', 2)[2]: p.text.strip().split(' ', 2)[1] for p in doc.paragraphs
            if p.style.name == 'Caption' and p.text.strip().startswith('表 9-2-')}

    def t92(name_part):
        num = next(v for k, v in caps.items() if name_part in k)
        return t(f'表 {num}')

    x = t92('後端')
    _after(x.findall(W('tr'))[-1], ['yauzl', '^3.4.0', '串流讀取路邊停車格位圖層壓縮檔（SHP／DBF）'])
    x = t92('前端')
    _set(_row(x, 'geolocator'), [None, None, '取得使用者位置以排序鄰近智慧書櫃、於掃描書櫃時確認使用者位於書櫃附近、於手機上找出最近之捷運站，以及管理員新增書櫃時填入座標'])
    _set(_row(x, 'url_launcher'), [None, None, '開啟外部連結（服務條款等）與Google地圖導航'])
    x = t92('限流')
    _after(x.findall(W('tr'))[-1], ['書櫃交通資訊（附近交通、捷運車站與票價）', '1分鐘', '60次', '使用者'])
    x = t92('錯誤代碼')
    _after(row_by_key(x, 'DEVICE_STALE_BOOT'), ['TRANSIT_UNAVAILABLE', '503', '捷運車站或票價資料暫時無法取得'])
    x = t92('權限')
    _append_cell(row_by_key(x, 'cabinets'), 2, '、新增與編輯書櫃時之附近交通預覽', before='')
    x = t92('路由')
    _set(row_by_key(x, '/api/cabinets'), [None, None, '智慧書櫃據點查詢、書櫃周邊交通資訊，以及捷運車站與票價查詢'])

    # 10 測試模型
    x = t('表 10-1-1')
    _after(row_by_key(x, 'test/platform'), ['test/transit',
        '書櫃交通資訊：捷運出入口、票價與無障礙設施之Big5解碼、公車站牌與預估到站、YouBike、停車場與剩餘車位、路邊停車格位圖層之索引建立與即時空位對應、'
        '道路路況、計程車招呼站、快取期限、單一來源故障與沿用舊資料、資源編號更換、TWD97座標換算、新增書櫃之附近交通預覽', '21'])
    _set(row_by_key(x, '合計'), [None, '共11組測試群組，全數通過', '1,558'])
    x = t('表 10-2-1')
    for values in [
        ('交通資訊單一來源故障不影響其他區塊', 'YouBike資料來源回傳500時查詢書櫃附近交通', 'YouBike區塊標示無法取得，捷運與停車場正常回傳；曾成功取得之來源於故障期間沿用上次資料', '通過'),
        ('路邊停車依格位位置對應即時空位', '以師大路附近之書櫃查詢路邊停車', '依格位圖層列出300公尺內之路段，並以路段編號對應即時空位與收費時段', '通過'),
        ('附近交通預覽限書櫃管理權限', '無書櫃管理權限之管理員查詢附近交通預覽', '回傳403', '通過'),
    ]:
        _after(x.findall(W('tr'))[-1], list(values))
    x = t('表 10-2-2')
    _after(row_by_key(x, 'book_detail_actions_test.dart'), ['cabinet_transit_test.dart', '7', '7',
        '前往書櫃頁：捷運出口與無障礙電梯、出發車站與票價（定位於手機上計算）、公車到站與展開路線、YouBike、周邊路況、停車場、路邊停車、計程車招呼站與無法取得之提示；'
        '新增書櫃之使用目前位置、定位精確度提示與附近交通預覽'])
    p = _para(doc, '後端10組測試群組共1,536項')
    text = p.text.strip()
    for old, new in [('後端10組測試群組共1,536項', '後端11組測試群組共1,558項'), ('49個測試檔、531個', '50個測試檔、538個'),
                     ('執行2,563項', '執行2,571項'), ('後台書櫃裝置管理', '前往書櫃交通資訊、新增書櫃取得目前座標、後台書櫃裝置管理')]:
        assert old in text, old
        text = text.replace(old, new)
    set_para(p._p, text)

    # 11 操作手冊
    # 表 11-1-1 不加列：該表剛好排滿一頁，多一列會使最後一列單獨落到下一頁；對外連線需求寫在 11-2-1 安裝步驟。
    x = t('表 11-2-1')
    cab = _row(x, '設定智慧書櫃', col=1)
    n = int(text_of(tcs(cab)[0]).strip())
    for tr in x.findall(W('tr'))[1:]:
        k = text_of(tcs(tr)[0]).strip()
        if k.isdigit() and int(k) > n:
            set_cell(tcs(tr)[0], str(int(k) + 1))
    _after(cab, [str(n + 1), '設定書櫃交通資訊：確認伺服器可對外以HTTPS連線至data.taipei與tcgbusfs.blob.core.windows.net，'
                 '並確認路邊停車格位索引之存放目錄可寫入（預設為API目錄下storage/transit，可以TRANSIT_DATA_DIR變更）；'
                 'API啟動約2分鐘後自動下載臺北市路邊停車格位圖層（約56MB）並建立索引，之後每日檢查，索引逾30天重新建立'])
    x = t('表 11-2-3')
    _after(x.findall(W('tr'))[-1], ['TRANSIT_DATA_DIR', '選用', 'storage/transit', '路邊停車格位索引（約9MB）之存放目錄，須可寫入'])

    # 12 使用手冊
    _manual_section(doc, '智慧書櫃存書與取書', '前往書櫃（交通資訊）', [
        '於書籍詳情之書櫃資訊、訂單詳情之「取書資訊」，或上架時選定書櫃後，點擊「交通資訊」進入「前往書櫃」頁；點擊「導航」以Google地圖前往書櫃，或點擊「複製地址」。',
        '「捷運」列出書櫃1.5公里內最近之車站、最近出口與無障礙電梯或坡道所在出口；「票價」顯示自出發車站至各站之全票與敬老・愛心・兒童票價及里程。'
        '出發車站預設為上次選擇之車站，或依手機定位算出之最近車站（位置僅於手機上計算，不傳送至伺服器），點擊後可搜尋更改。',
        '「公車」列出300公尺內之公車站，以及各路線之方向與到站狀態（即將進站、約N分、尚未發車、末班已過等），路線較多時可點擊「顯示全部」；'
        '「YouBike 2.0」列出500公尺內站點之可借與可還數量，暫停營運之站點另行標示。',
        '「開車與計程車」上方之「周邊路況」顯示附近道路之時速與順暢、車多或壅塞；「停車場」分頁列出800公尺內停車場之剩餘車位與收費說明，'
        '「路邊停車」分頁依格位實際位置列出300公尺內之汽車格與機車格（汽車格附即時空位、收費時段與費率），「計程車招呼站」分頁列出800公尺內之招呼站與排班時間。',
        '點選任一項目即以地圖導航至該處，下拉頁面可重新整理。資料取自臺北市資料大平臺，公車、YouBike與停車資訊僅涵蓋臺北市，距離皆為直線距離。',
    ])
    _manual_section(doc, '書櫃裝置與櫃門管理（管理員）', '智慧書櫃據點設定（管理員）', [
        '於後台「硬體與營運」之「書櫃監控」，點擊右上角之「＋」圖示新增書櫃，或點擊書櫃卡片之編輯圖示修改書櫃。',
        '填寫書櫃名稱與地址後，可於書櫃現場點擊「使用目前位置」，App以精確位置填入緯度與經度並顯示「定位精確度約 ±N 公尺」；'
        '誤差大於50公尺時會提示「誤差較大，建議移至戶外或空曠處後重新定位」，iOS僅允許大約位置時須依提示開啟精確位置。亦可手動輸入經緯度。',
        '「附近交通預覽」依填入之座標顯示最近之捷運站、公車站、YouBike與停車場數量及路邊停車路名，可據以確認座標與地址相符；點擊「在地圖上確認」可於地圖檢視該座標。',
        '新增書櫃時另設定櫃位數量（1至100），並視需要設定開放時間與關閉時間後點擊「建立書櫃」；修改書櫃時點擊「儲存變更」。新增或修改皆記錄於操作紀錄。',
    ])

    # 14 參考資料
    return _references(doc)


FIG_TAGS = ('keepNext', 'keepLines', 'pageBreakBefore', 'spacing', 'ind', 'jc')


def _copy_ppr(dst, src):
    from update_1001 import _copy_format
    _copy_format(dst, src, FIG_TAGS)


def finalize(doc):
    """新增之圖（5-3-35、5-3-36、6-1-32）沿用前一張圖之段落格式。"""
    done = 0
    # 活動圖只有圖與圖名；循序圖另有說明段落在圖之前
    for new, prev, parts in [('5-3-35', '5-3-34', 2), ('5-3-36', '5-3-35', 2), ('6-1-32', '6-1-31', 3)]:
        a, b = _caption_el(doc, f'圖 {new} '), _caption_el(doc, f'圖 {prev} ')
        for _ in range(parts):
            _copy_ppr(a, b)
            a, b = a.getprevious(), b.getprevious()
        done += 1
    return done
