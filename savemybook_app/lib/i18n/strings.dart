import 'app_localizations.dart';

/// 給沒有 BuildContext 的地方用的譯文存取點。
///
/// 模型與服務層（Order.statusText、AppLabels…）拿不到 context，
/// 但那些字串正是全 App 重複最多次的。由 MaterialApp.builder 在每次
/// 語系變動時更新這個參考，其餘地方直接用 S。
///
/// 畫面裡有 context 時仍應優先用 AppLocalizations.of(context)。
AppLocalizations S = AppLocalizations.fallback;
