"""誌謝：改寫內文與落款日期。須在 update_1001 之後執行，新段落沿用原段落之版面。"""
import copy
from doctools import W, text_of, set_para

BODY = [
    '本系統「救『舊』我的書」從構思、開發到完成實體書櫃，承蒙許多師長與同儕的協助，謹在此致上誠摯的謝意。',
    '首先感謝指導老師——國立臺北商業大學林俊杰老師。從題目發想開始，老師即協助團隊確立研發方向，並在系統架構與實作細節上給予嚴謹的指導，'
    '使我們學會以系統化的方式分析與解決實務問題。',
    '在書櫃的設計上，感謝國立雲林科技大學吳政佑同學。開發初期，吳同學協助團隊完成書櫃的3D建模，讓我們得以建立初步的硬體規劃與構想；'
    '其後更與國立中山大學林甲同學共同為新版書櫃的定義與規劃提供許多想法，成為現行書櫃設計的基礎。'
    '也感謝龍華科技大學盧士玄同學，在雛形製作階段協助3D列印，使初期的設計得以實際做出成品。',
    '在書櫃的製作上，感謝新北市立新北高級工業職業學校實習處汪師弘主任，在加工設備上給予團隊大力協助；'
    '也感謝國立臺北科技大學劉韋廷同學、龍華科技大學李承恩同學及國立臺灣科技大學林詠軒同學，在木工機具的操作上提供建議與指導，讓書櫃得以順利完成。',
    '在視覺設計與使用流程方面，感謝國立臺北商業大學創意科技與產品設計系的友人，在識別設計的構思過程中提供許多寶貴意見；'
    '也感謝國立臺灣科技大學林天佑同學，在使用情境的規劃上提出分析觀點，協助團隊改善系統流程與使用者體驗。',
    '本系統能順利完成，有賴上述師長與同學的協助與支持，在此再次表達感謝。',
]
DATE = '中華民國一一五年十月'


def run(doc):
    body = list(doc.element.body.iterchildren())
    head = next(e for e in body if e.tag == W('p') and text_of(e).strip() == '誌謝')
    paras = []
    e = head.getnext()
    while text_of(e).strip():
        paras.append(e)
        e = e.getnext()
    assert len(paras) <= len(BODY), len(paras)
    while len(paras) < len(BODY):
        extra = copy.deepcopy(paras[-2])
        paras[-2].addnext(extra)
        paras.insert(len(paras) - 1, extra)
    for p, text in zip(paras, BODY):
        set_para(p, text)
    date = e
    while not text_of(date).startswith('中華民國'):
        date = date.getnext()
    set_para(date, DATE)
    return len(BODY)
