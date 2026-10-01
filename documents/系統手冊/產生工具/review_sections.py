"""第二章新增之 2-5～2-7 節內容。數據與來源另列於 review_data.py。"""
import os
import review_data as D


def add(w, here):
    payments(w, here)
    costs(w)
    hardware(w)
    return 3


def payments(w, here):
    w.h2('金流機制與營運管理')
    w.body('本節說明系統現行之金流機制與後台管理功能，並列出商品化階段規劃補強之金流、合作夥伴管理與效益分析功能。')
    w.sub('現行金流機制')
    for t in D.PAYMENT_NOW:
        w.bullet(t)
    w.body('訂單款項之流轉如圖2-5-1所示：款項於結帳時即由平台暫管，並依存書、取書與爭議結果撥付賣家或退回買家，買賣雙方均無須於面交時收付現金。')
    w.figure(os.path.join(here, 'review', 'payment_flow.png'), '圖 2-5-1 訂單金流流程圖', 18.0, 13.0)
    w.sub('金流規劃補強')
    for t in D.PAYMENT_PLAN:
        w.bullet(t)
    w.sub('系統管理與效益分析')
    w.body('後台依權限分工提供營運管理功能，現行功能與規劃補強項目如表2-5-1所示；效益分析規劃之指標定義如表2-5-2所示。')
    w.table('表 2-5-1 後台管理與效益分析功能表', D.ADMIN_ROWS, [16, 44, 40])
    w.table('表 2-5-2 營運效益分析指標表', D.KPI_ROWS, [22, 42, 36])
    w.sub('合作夥伴管理（規劃）')
    for t in D.PARTNER_PLAN:
        w.bullet(t)


def costs(w):
    w.h2('成本與收益分析')
    w.body(D.COST_INTRO)
    w.sub('建置成本')
    w.body(D.BUILD_TEXT)
    w.table('表 2-6-1 單台智慧書櫃建置成本估算表', D.BOM_ROWS, D.BOM_WIDTHS, D.BOM_ALIGN)
    w.table('表 2-6-2 開發期一次性投入估算表', D.DEV_ROWS, D.DEV_WIDTHS, D.DEV_ALIGN)
    w.sub('人力成本')
    w.body(D.LABOR_TEXT)
    w.table('表 2-6-3 人力成本估算表', D.LABOR_ROWS, D.LABOR_WIDTHS, D.LABOR_ALIGN)
    w.sub('營運成本')
    w.body(D.OPEX_TEXT)
    w.table('表 2-6-4 年度營運成本估算表', D.OPEX_ROWS, D.OPEX_WIDTHS, D.OPEX_ALIGN)
    w.sub('收益預估與損益兩平')
    w.body(D.REVENUE_TEXT)
    w.table('表 2-6-5 收益預估假設表', D.ASSUMPTION_ROWS, D.ASSUMPTION_WIDTHS, D.ASSUMPTION_ALIGN)
    w.table('表 2-6-6 三年損益預估表', D.PNL_ROWS, D.PNL_WIDTHS, D.PNL_ALIGN)
    w.body(D.PNL_NOTES[0])
    w.body(D.PNL_NOTES[1])
    w.table('表 2-6-7 營運損益兩平所需書櫃數表', D.BE_ROWS, D.BE_WIDTHS, D.BE_ALIGN)
    for t in D.PNL_NOTES[2:]:
        w.body(t)


def hardware(w):
    w.h2('智慧書櫃設備可行性與維運')
    w.body(D.HW_INTRO)
    w.sub('設備可行性')
    for t in D.HW_FEASIBILITY:
        w.bullet(t)
    w.sub('妥善率')
    w.body(D.AVAIL_TEXT)
    w.table('表 2-7-1 主要元件故障模式與處置表', D.FAILURE_ROWS, D.FAILURE_WIDTHS, D.FAILURE_ALIGN)
    w.body(D.AVAIL_CALC_TEXT)
    w.sub('故障偵測與備援機制')
    for t in D.HW_FALLBACK:
        w.bullet(t)
    w.sub('維護作業與成本')
    w.body(D.MAINT_TEXT)
    w.table('表 2-7-2 單台書櫃年度維護成本估算表', D.MAINT_ROWS, D.MAINT_WIDTHS, D.MAINT_ALIGN)
    for t in D.MAINT_NOTES:
        w.body(t)
