import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/models/book.dart';

import 'manual_api.dart';
import 'manual_host.dart';

const _folder = '_pilot';

void main() {
  setUpAll(setUpManual);

  testWidgets('首頁', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    await shoot(tester, folder: _folder, home: HomeScreen.new, act: (tester, snap) async {
      await snap('home');
    });
  });

  testWidgets('商品詳情與鍵盤', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    await shoot(tester, folder: _folder, home: () => BookDetailScreen(book: Book.fromJson(bookJson(bookIds.first))), act: (tester, snap) async {
      await snap('detail');
      systemOverlay.value = [const Positioned.fill(child: IosAlert(title: '「救「舊」我的書」想要使用相機', message: '掃描書櫃 QR Code 與拍攝書籍照片時需要使用相機。', actions: ['不允許', '好']))];
      await tester.pump();
      await snap('alert');
      systemOverlay.value = [];
      showKeyboard(tester, candidates: ['可愛', '我', '喜歡', '的', '有', '開心', '了']);
      await tester.pump();
      await snap('keyboard');
      hideKeyboard(tester);
      systemOverlay.value = [
        const Positioned.fill(
          child: IosPasskeySheet(
            title: 'Save a passkey?',
            message: '“救舊我的書” supports passkeys, a stronger alternative to passwords that cannot be leaked or stolen. A passkey for “es@savemybook.today” will be saved in “Passwords”.',
            primary: 'Add Passkey',
            secondary: 'More Options',
          ),
        ),
      ];
      await tester.pump();
      await snap('passkey');
    });
  });
}
