import 'package:flutter/material.dart';
import 'app_dialogs.dart';
import 'state_views.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../i18n/strings.dart';

/// 有未儲存的內容時攔下返回。
///
/// 直接用 PopScope 要在每個畫面重寫一次「問要不要捨棄、使用者說要才 pop」，
/// 而且 canPop 與 onPopInvokedWithResult 的搭配很容易寫錯——canPop 給 false
/// 會連 iOS 的左滑返回一起關掉。集中在這裡實作一次。
class UnsavedGuard extends StatelessWidget {
  final bool isDirty;
  final Widget child;

  /// 覆寫提示文字。預設是「捨棄變更？／這份內容有尚未儲存的修改」。
  final String? message;

  const UnsavedGuard({
    super.key,
    required this.isDirty,
    required this.child,
    this.message,
  });

  static Future<bool> confirm(BuildContext context, {String? message}) {
    return showConfirmDialog(
      context,
      title: S.discardChanges,
      message: message ?? S.screenUnsavedChangesTheyLostIf,
      confirmLabel: S.discard,
      cancelLabel: S.keepEditing,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 沒有未存的東西就完全不攔，左滑返回維持原本的手感。
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirm(context, message: message)) navigator.pop();
      },
      child: child,
    );
  }
}

/// 看起來停用、但按下去會說明為什麼。
///
/// 直接把 onTap 設成 null 的話，使用者只會看到一個沒反應的按鈕，
/// 分不出是「不能按」還是「壞掉了」。這裡照樣吃掉點擊，但回一句原因。
class DisabledHint extends StatelessWidget {
  final bool disabled;
  final String reason;
  final Widget child;

  const DisabledHint({
    super.key,
    required this.disabled,
    required this.reason,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!disabled) return child;

    return Semantics(
      enabled: false,
      hint: reason,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAppSnackBar(context, reason),
        child: AnimatedOpacity(
          opacity: 0.45,
          duration: Motion.base,
          curve: Motion.standard,
          // AbsorbPointer 在內層：外面的 GestureDetector 仍收得到點擊，
          // 裡面的按鈕收不到。
          child: AbsorbPointer(child: child),
        ),
      ),
    );
  }
}

/// 表單底部的「還差什麼」提示。
///
/// 按下去才用 snackbar 說「請填書名」，使用者得先撞一次牆才知道。
/// 把未完成的項目直接列在送出鍵上方，填的過程就看得到還剩什麼。
class MissingHint extends StatelessWidget {
  final List<String> missing;

  const MissingHint({super.key, required this.missing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = missing.join('、');

    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: missing.isEmpty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.stillNeededP0(text),
                      style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
