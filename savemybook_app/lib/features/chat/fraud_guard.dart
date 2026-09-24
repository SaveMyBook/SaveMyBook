import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../i18n/strings.dart';

enum FraudSignal { contact, payment, offsite }

/// 聊天防詐提醒：只在手機上以規則比對對方訊息，不把聊天內容送到伺服器或 AI 服務。
/// 偵測到站外聯絡方式、私下匯款或站外交易的字眼時，在該則訊息下方提醒使用者。
class FraudGuard {
  const FraudGuard._();

  static final _payment = RegExp(
    // App 內建聊天室轉帳，「轉帳給你」屬正常用語，只有私下或另外轉帳才提醒。
    r'(私下|另外)\s*(匯款|轉帳|付款)|(直接|先)\s*匯款|匯款\s*(到|給|至)|'
    r'(銀行|郵局|帳戶|帳號|戶名|代碼)[^\n]{0,12}\d[\d\s-]{7,}|街口|LINE\s*Pay|全支付|悠遊付|無卡存款',
    caseSensitive: false,
  );

  static final _offsite = RegExp(
    r'(不用|不要|別|不必)\s*(透過|經過|用)\s*(平台|APP|app|網站)|站外交易|私下交易|私下面交|繞過平台',
    caseSensitive: false,
  );

  static final _contact = RegExp(
    r'(^|[^a-z])(line|ＬＩＮＥ|賴)\s*(id|ＩＤ|號|:|：)|加\s*(我\s*)?(line|ＬＩＮＥ|賴|好友)|line\.me/|lin\.ee/|'
    r'telegram|t\.me/|微信|wechat|whatsapp|(ig|instagram)\s*(私訊|帳號|:|：)|'
    r'(?:\+?886[-\s]?|(?<!\d)0)9\d{2}[-\s]?\d{3}[-\s]?\d{3}(?!\d)|'
    r'[\w.+-]+@[\w-]+\.(com|net|org|tw|edu)',
    caseSensitive: false,
  );

  // 同時符合多種時以金錢風險最高者為準。
  static FraudSignal? detect(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (_payment.hasMatch(value)) return FraudSignal.payment;
    if (_offsite.hasMatch(value)) return FraudSignal.offsite;
    if (_contact.hasMatch(value)) return FraudSignal.contact;
    return null;
  }

  static String message(FraudSignal signal) => switch (signal) {
    FraudSignal.payment => S.doNotPayTransferMoneyOutside,
    FraudSignal.offsite => S.pleaseCompleteDealAppWeCannot,
    FraudSignal.contact => S.personSharedOutsideContactDetailsWatch,
  };
}

class FraudWarning extends StatelessWidget {
  final FraudSignal signal;

  const FraudWarning({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: c.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_outlined, size: 14, color: c.warning),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              FraudGuard.message(signal),
              style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
