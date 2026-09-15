import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_forms.dart';
import '../../../widgets/state_views.dart';

class LegalTitleCard extends StatelessWidget {
  final TextEditingController controller;
  final bool showError;

  const LegalTitleCard({super.key, required this.controller, required this.showError});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              S.documentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
            ),
          ),
          AppTextField(
            controller: controller,
            hint: S.documentTitle,
            maxLength: 100,
            errorText: showError ? S.enterDocumentTitle : null,
          ),
        ],
      ),
    );
  }
}
