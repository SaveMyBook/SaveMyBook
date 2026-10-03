"""成本與收益試算：所有表格數字由此計算，避免表間不一致。匯率 31.92（臺灣銀行 2026-09-29 美元即期賣出）。"""
USD = 31.92
WAGE = 196  # 2026 最低工資時薪

# 單台書櫃建置（2026-10-04 查價）
ELEC = [('ESP32-S3開發板', 1, 350), ('12V櫃門電控鎖', 4, 350), ('4路繼電器模組', 1, 160), ('2.8吋TFT顯示模組（320×240）', 1, 580),
        ('12V 5A電源供應器', 1, 239), ('5V降壓模組', 1, 100), ('保護元件（估計）', 1, 60), ('配線與端子耗材', 1, 320)]
ELEC_TOTAL = sum(q * p for _, q, p in ELEC)
PRICE = {name: p for name, _, p in ELEC}
BODY = [('9mm合板（3×6尺）', 1, 350), ('5mm壓克力（60×90cm）', 1, 678)]
BODY_TOTAL = sum(q * p for _, q, p in BODY)
WOOD_CUTS, CUT_RATE = 12, 25
LASER_MIN, LASER_RATE = 20, 15
PROCESS = WOOD_CUTS * CUT_RATE + LASER_MIN * LASER_RATE
CONTINGENCY = round((ELEC_TOTAL + BODY_TOTAL) * 0.10)
CABINET = ELEC_TOTAL + BODY_TOTAL + PROCESS + CONTINGENCY

# 年度固定營運費用
SERVER_M = round(48 * USD)
SERVER_Y = SERVER_M * 12
DOMAIN_Y = round(22.20 * USD)
APPLE_Y = round(99 * USD)
GOOGLE_ONCE = round(25 * USD)
AI_USD_M = {1: 10, 2: 20, 3: 50}
MARKETING = {1: 20000, 2: 30000, 3: 60000}
SUPPORT_H_WEEK = {1: 10, 2: 10, 3: 20}

# 單台年度維護
INSPECT_H, REPAIR_H = 12, 4
SPARES = PRICE['12V櫃門電控鎖'] + PRICE['4路繼電器模組'] + 72
POWER_KWH = round(2 * 24 * 365 / 1000, 1)  # 平均 2 瓦
POWER = round(POWER_KWH * 2.71)
MAINT = INSPECT_H * WAGE + REPAIR_H * WAGE + SPARES + POWER

# 收益假設
AOV = 200
FEE = 0.10
DAYS = 300
CABINETS = {1: 3, 2: 8, 3: 20}
ORDERS_PER_DAY = {1: 1.5, 2: 2.0, 3: 2.5}
AD_M = {1: 0, 2: 500, 3: 800}
AD_FILL = {1: 0, 2: 0.5, 3: 0.6}
PARTNER_SHARE = 0.30

DEV_HOURS = 4 * 40 * 15
DEV_LABOR = DEV_HOURS * WAGE


def year(y):
    n = CABINETS[y]
    new = n - (CABINETS.get(y - 1, 0))
    orders = round(n * ORDERS_PER_DAY[y] * DAYS)
    gmv = orders * AOV
    fee = round(gmv * FEE)
    ads_gross = round(n * AD_M[y] * 12 * AD_FILL[y])
    ads = round(ads_gross * (1 - PARTNER_SHARE))
    capex = new * CABINET + (GOOGLE_ONCE + CABINET if y == 1 else 0)  # 第一年另含原型機一台與 Google Play 註冊
    it = SERVER_Y + DOMAIN_Y + APPLE_Y + round(AI_USD_M[y] * USD * 12)
    support = SUPPORT_H_WEEK[y] * 52 * WAGE
    maint = n * MAINT
    marketing = MARKETING[y]
    cost = capex + it + support + maint + marketing
    income = fee + ads
    return dict(n=n, new=new, orders=orders, gmv=gmv, fee=fee, ads_gross=ads_gross, ads=ads, income=income,
                capex=capex, it=it, support=support, maint=maint, marketing=marketing, cost=cost, pnl=income - cost)


def breakeven(orders_per_day, aov, y=3):
    """第三年成本結構下，達成損益兩平所需之書櫃數（不含當年新增書櫃之建置費）。"""
    fixed = SERVER_Y + DOMAIN_Y + APPLE_Y + round(AI_USD_M[y] * USD * 12) + SUPPORT_H_WEEK[y] * 52 * WAGE + MARKETING[y]
    per_cab = orders_per_day * DAYS * aov * FEE + AD_M[y] * 12 * AD_FILL[y] * (1 - PARTNER_SHARE) - MAINT
    return None if per_cab <= 0 else fixed / per_cab


if __name__ == '__main__':
    print('ELEC', ELEC_TOTAL, 'BODY', BODY_TOTAL, 'PROCESS', PROCESS, 'CONT', CONTINGENCY, 'CABINET', CABINET)
    print('SERVER_M', SERVER_M, 'SERVER_Y', SERVER_Y, 'DOMAIN', DOMAIN_Y, 'APPLE', APPLE_Y, 'GOOGLE', GOOGLE_ONCE)
    print('MAINT', MAINT, 'POWER', POWER_KWH, POWER, 'DEV', DEV_HOURS, DEV_LABOR)
    cum = 0
    for y in (1, 2, 3):
        r = year(y); cum += r['pnl']; print(y, r, 'cum', cum)
    for opd in (1.5, 2.5, 4):
        for aov in (200, 300):
            print('BE', opd, aov, round(breakeven(opd, aov), 1))
