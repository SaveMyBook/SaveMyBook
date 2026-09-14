#!/usr/bin/env python3
"""讀取 firebase/ 裡的 GoogleService-Info.plist 與 google-services.json，產生 lib/firebase_options.dart。

用這支腳本而不是 flutterfire configure：不必另外安裝 Firebase CLI、登入 Google 帳號，
也不會去改 Xcode 專案與 Gradle 設定。產生的類別名稱與 flutterfire 相同，日後改用它也能直接覆蓋。
"""
import json, plistlib, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
IOS_BUNDLE = 'today.savemybook.app'
ANDROID_PACKAGE = 'today.savemybook.app'


def fail(msg):
    print(f'❌ {msg}')
    sys.exit(1)


def load_ios():
    path = ROOT / 'firebase' / 'GoogleService-Info.plist'
    if not path.exists():
        return None
    with open(path, 'rb') as f:
        p = plistlib.load(f)
    if p.get('BUNDLE_ID') != IOS_BUNDLE:
        fail(f'GoogleService-Info.plist 的 Bundle ID 是 {p.get("BUNDLE_ID")}，應該是 {IOS_BUNDLE}。'
             '請在 Firebase 以正確的 Bundle ID 新增 iOS App 後重新下載。')
    return {
        'apiKey': p['API_KEY'],
        'appId': p['GOOGLE_APP_ID'],
        'messagingSenderId': p['GCM_SENDER_ID'],
        'projectId': p['PROJECT_ID'],
        'storageBucket': p.get('STORAGE_BUCKET'),
        'iosBundleId': p['BUNDLE_ID'],
    }


def load_android():
    path = ROOT / 'firebase' / 'google-services.json'
    if not path.exists():
        return None
    data = json.load(open(path, encoding='utf-8'))
    client = next((c for c in data.get('client', [])
                   if c['client_info']['android_client_info']['package_name'] == ANDROID_PACKAGE), None)
    if client is None:
        names = [c['client_info']['android_client_info']['package_name'] for c in data.get('client', [])]
        fail(f'google-services.json 裡沒有 {ANDROID_PACKAGE}（找到的是 {names}）。'
             '請在 Firebase 以正確的套件名稱新增 Android App 後重新下載。')
    info = data['project_info']
    return {
        'apiKey': client['api_key'][0]['current_key'],
        'appId': client['client_info']['mobilesdk_app_id'],
        'messagingSenderId': info['project_number'],
        'projectId': info['project_id'],
        'storageBucket': info.get('storage_bucket'),
    }


def dart_options(values):
    lines = []
    for key, value in values.items():
        if value:
            lines.append(f"    {key}: '{value}',")
    return 'FirebaseOptions(\n' + '\n'.join(lines) + '\n  )'


def main():
    ios, android = load_ios(), load_android()
    if not ios and not android:
        fail('firebase/ 資料夾裡找不到 GoogleService-Info.plist 或 google-services.json')
    if ios and android and ios['projectId'] != android['projectId']:
        fail(f'兩個設定檔屬於不同的 Firebase 專案（{ios["projectId"]} / {android["projectId"]}）')

    out = ["import 'package:firebase_core/firebase_core.dart';",
           "import 'package:flutter/foundation.dart';",
           '',
           '/// 由 tool/firebase_setup.py 讀取 firebase/ 資料夾裡的設定檔產生，不要手動修改。',
           'class DefaultFirebaseOptions {',
           '  static FirebaseOptions? get currentPlatform {',
           '    switch (defaultTargetPlatform) {']
    if ios:
        out += ['      case TargetPlatform.iOS:', '        return ios;']
    if android:
        out += ['      case TargetPlatform.android:', '        return android;']
    out += ['      default:', '        return null;', '    }', '  }', '']
    if ios:
        out += [f'  static const FirebaseOptions ios = {dart_options(ios)};', '']
    if android:
        out += [f'  static const FirebaseOptions android = {dart_options(android)};', '']
    while out[-1] == '':
        out.pop()
    out += ['}', '']

    (ROOT / 'lib' / 'firebase_options.dart').write_text('\n'.join(out), encoding='utf-8')
    print('✅ 已產生 lib/firebase_options.dart')
    print(f'   iOS：{"已設定" if ios else "未設定"}　Android：{"已設定" if android else "未設定"}')


if __name__ == '__main__':
    main()
