import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../widgets/state_views.dart';
import '../models/security.dart';
import 'api_service.dart';
import '../i18n/strings.dart';

class ServerCompat {
  static bool _checked = false;

  static Future<void> check(BuildContext context) async {
    if (_checked || ApiService.authToken == null) return;
    _checked = true;

    final status = await ApiService().fetchServerStatus();
    if (status == null || !context.mounted) {
      _checked = false;
      return;
    }
    if (!status.isOutdated) return;

    if (ApiService.currentUser?.role != 'admin') {
      showAppSnackBar(context, S.someFeaturesTemporarilyUnavailableWhileServer, isError: true);
      return;
    }

    final c = AppColors.of(context);
    final current = status.apiRevision;
    final needed = ServerStatus.requiredApiRevision;
    final commit = status.commit;
    final lines = <String>[
      S.serverRunningOutdatedApiRevisionP0(current, needed),
      if (commit != null) S.serverVersionP0(commit),
      S.runNpmRunVerifyApiDirectory,
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.serverUpdateRequired, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17)),
        content: SingleChildScrollView(
          child: Text(lines.join('\n\n'), style: TextStyle(fontSize: 14, height: 1.6, color: c.textSecondary)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.actionConfirm, style: TextStyle(color: c.accent))),
        ],
      ),
    );
  }
}
