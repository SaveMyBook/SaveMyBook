"""字幕字型：把專案 App 的 Noto Sans TC 複製並改名（SMB Sub ZH／EN），確保 libass 一定選到正確字重，不會誤抓系統字型"""
import os
from fontTools.ttLib import TTFont

D = os.path.join(os.path.dirname(__file__), "../../../../savemybook_app/assets/fonts")
os.makedirs("fonts", exist_ok=True)
for src, fam, out in (("NotoSansTC-Medium.ttf", "SMB Sub ZH", "fonts/smb-sub-zh.ttf"), ("NotoSansTC-Regular.ttf", "SMB Sub EN", "fonts/smb-sub-en.ttf")):
    f = TTFont(os.path.join(D, src))
    n = f["name"]
    for nid in (16, 17): n.removeNames(nameID=nid)
    for pid, eid, lid in ((3, 1, 0x409), (1, 0, 0)):
        n.setName(fam, 1, pid, eid, lid); n.setName("Regular", 2, pid, eid, lid)
        n.setName(fam, 4, pid, eid, lid); n.setName(fam.replace(" ", "") + "-Regular", 6, pid, eid, lid)
    f.save(out)
