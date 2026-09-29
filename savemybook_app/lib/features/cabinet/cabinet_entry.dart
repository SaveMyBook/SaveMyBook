import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../models/cabinet.dart';
import '../../services/api_service.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import 'cabinet_flow_controller.dart';
import 'cabinet_flow_screen.dart';
import 'cabinet_messages.dart';

export 'cabinet_flow_controller.dart' show CabinetFlowOutcome;
export 'cabinet_messages.dart' show CabinetAction, CabinetMessages, cabinetActionLabel;

Future<CabinetFlowOutcome> openCabinetFlow(BuildContext context, {CabinetContext? cabinetContext, String? code}) async {
  var outcome = CabinetFlowOutcome.dismissed;
  final result = await Navigator.of(context).push<CabinetFlowOutcome>(
    MaterialPageRoute(
      builder: (_) => CabinetFlowScreen(code: code, cabinetContext: cabinetContext, onOutcome: (value) => outcome = value),
    ),
  );
  return result ?? outcome;
}

IconData cabinetActionIcon(CabinetAccess? access, IconData manualIcon) =>
    access != null && !access.isManual ? Icons.qr_code_scanner_rounded : manualIcon;

Future<bool> runCabinetAction(
  BuildContext context, {
  required CabinetAction action,
  required CabinetAccess? access,
  required CabinetContext target,
  List<String> orderDoors = const [],
  required Future<bool> Function(String? notice) manual,
}) async {
  final blocked = CabinetMessages.precheck(access, action, orderDoors: orderDoors);
  if (blocked != null) {
    showAppSnackBar(context, blocked, isError: true);
    return false;
  }
  if (access != null && access.isScan) {
    final outcome = await openCabinetFlow(context, cabinetContext: target);
    if (outcome == CabinetFlowOutcome.manualRequested && context.mounted) {
      return manual(CabinetMessages.manualNotice(const CabinetAccess(mode: CabinetAccess.manual, reason: 'offline')));
    }
    return outcome != CabinetFlowOutcome.dismissed;
  }
  return manual(access == null ? null : CabinetMessages.manualNotice(access));
}

Future<bool> reportCabinetManually(
  BuildContext context, {
  required String title,
  required String message,
  List<String> items = const [],
  required String confirmLabel,
  required IconData icon,
  String? notice,
  required CabinetContext target,
  required Future<CabinetManualResult> Function() send,
  Future<void> Function(CabinetManualResult result)? onApplied,
}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: title,
    message: notice == null ? message : '$notice\n$message',
    items: items,
    confirmLabel: confirmLabel,
    icon: icon,
  );
  if (!confirmed || !context.mounted) return false;

  final result = await runBusy(context, send);
  if (!context.mounted || result == null) return true;
  if (result.scanRequired) {
    await openCabinetFlow(context, cabinetContext: target);
    return true;
  }
  final error = result.error;
  if (error != null) {
    showAppSnackBar(context, CabinetMessages.manualError(CabinetApiError(code: result.code ?? '', message: error)), isError: true);
    return true;
  }
  HapticFeedback.lightImpact();
  if (result.pending || onApplied == null) {
    showAppSnackBar(context, S.reportSubmittedTakesEffectAfterSupport);
    return true;
  }
  await onApplied(result);
  return true;
}
