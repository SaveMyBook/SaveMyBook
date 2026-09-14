# -*- coding: utf-8 -*-
"""測試通知、系統通知設定與管理員權限授予的提示。"""

T = {
    '你自己沒有這項權限，所以不能開給別人。': (
        "You don't have this permission yourself, so you can't grant it to others.",
        '自分がこの権限を持っていないため、他の人に付与できません。',
        '본인에게 이 권한이 없어서 다른 사람에게 부여할 수 없습니다.',
        '你自己没有这项权限，所以不能开给别人。',
    ),
    '通知權限已關閉': ('Notifications are turned off', '通知がオフになっています', '알림이 꺼져 있습니다', '通知权限已关闭'),
    '前往設定': ('Open Settings', '設定を開く', '설정 열기', '前往设置'),
    '傳送測試通知': ('Send a test notification', 'テスト通知を送信', '테스트 알림 보내기', '发送测试通知'),
    '10 秒後送達，送出後先回到主畫面或鎖定手機': (
        'Arrives in 10 seconds. Go to the Home Screen or lock your phone after sending.',
        '10秒後に届きます。送信後はホーム画面に戻るか、端末をロックしてください。',
        '10초 후 도착합니다. 보낸 뒤 홈 화면으로 가거나 휴대폰을 잠그세요.',
        '10 秒后送达，发送后先回到主屏幕或锁定手机',
    ),
    '系統通知設定': ('System notification settings', 'システムの通知設定', '시스템 알림 설정', '系统通知设置'),
    '開關通知、聲音與鎖定畫面顯示': (
        'Turn notifications, sounds and Lock Screen previews on or off',
        '通知、サウンド、ロック画面の表示を切り替えます',
        '알림, 소리, 잠금 화면 표시를 켜거나 끕니다',
        '开关通知、声音与锁定屏幕显示',
    ),
    '這個版本的 App 還沒有設定推播，請先放入 Firebase 設定檔後重新編譯。': (
        'Push notifications are not set up in this build. Add the Firebase config files and rebuild.',
        'このビルドではプッシュ通知が設定されていません。Firebaseの設定ファイルを追加して再ビルドしてください。',
        '이 빌드에는 푸시 알림이 설정되어 있지 않습니다. Firebase 설정 파일을 추가하고 다시 빌드하세요.',
        '这个版本的 App 还没有设置推送，请先放入 Firebase 配置文件后重新编译。',
    ),
    '通知權限已被關閉，請到系統設定允許這個 App 傳送通知。': (
        'Notifications are turned off. Allow this app to send notifications in system settings.',
        '通知がオフになっています。システム設定でこのアプリの通知を許可してください。',
        '알림이 꺼져 있습니다. 시스템 설정에서 이 앱의 알림을 허용하세요.',
        '通知权限已被关闭，请到系统设置允许这个 App 发送通知。',
    ),
}
