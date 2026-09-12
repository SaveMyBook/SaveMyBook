# -*- coding: utf-8 -*-
"""上架流程優化、停用原因提示與防呆相關的譯文。"""

T = {
    '要改自己的密碼請到「設定 → 更改密碼」': (
        'To change your own password, go to Settings → Change password',
        '自分のパスワードは「設定 → パスワード変更」から変更してください',
        '본인 비밀번호는 설정 → 비밀번호 변경에서 바꾸세요',
        '要改自己的密码请到“设置 → 更改密码”',
    ),
    '這位會員不是管理員，沒有後台權限可以設定。先在上方把身分改成管理員。': (
        'This member is not an admin, so there are no admin permissions to set. Change their role above first.',
        'この会員は管理者ではないため、設定できる管理権限がありません。先に上で役割を管理者に変更してください。',
        '이 회원은 관리자가 아니므로 설정할 관리자 권한이 없습니다. 위에서 역할을 관리자로 먼저 변경하세요.',
        '这位会员不是管理员，没有后台权限可以设置。先在上方把身份改成管理员。',
    ),
    '你自己': ('You', '自分', '본인', '你自己'),
    r'ISBN 要 10 或 13 碼，目前 ${isbn.length} 碼': (
        r'ISBN must be 10 or 13 digits; this one has $p0',
        r'ISBNは10桁か13桁です。現在は$p0桁です',
        r'ISBN은 10자리 또는 13자리여야 합니다. 현재 $p0자리입니다',
        r'ISBN 要 10 或 13 位，目前 $p0 位',
    ),
    '這個畫面有尚未儲存的修改，離開後會遺失。': (
        'This screen has unsaved changes. They are lost if you leave.',
        'この画面には未保存の変更があります。離れると失われます。',
        '이 화면에 저장하지 않은 변경 사항이 있습니다. 나가면 사라집니다.',
        '这个界面有尚未保存的修改，离开后会丢失。',
    ),
    r'還差：$text': (r'Still needed: $p0', r'あと $p0', r'남은 항목: $p0', r'还差：$p0'),
}

T.update({
    r'照片：$_totalImages 張': (r'Photos: $p0', r'写真：$p0枚', r'사진: $p0장', r'照片：$p0 张'),
    '確認上架': ('Confirm listing', '出品を確認', '등록 확인', '确认上架'),
    '查詢書籍資料中': ('Looking up the book', '書籍情報を検索中', '도서 정보 조회 중', '查询书籍资料中'),
    '掃描': ('Scan', 'スキャン', '스캔', '扫描'),
})
