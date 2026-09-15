import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../utils/api_helpers.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../widgets/state_views.dart';

class LegalPreview extends StatelessWidget {
  final String title;
  final String content;
  final DateTime updatedAt;

  const LegalPreview({super.key, required this.title, required this.content, required this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 40 + bottomInset),
      children: [
        Row(
          children: [
            Icon(Icons.smartphone_rounded, size: 13, color: c.textHint),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                S.howUsersSee,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.scaffold,
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 46,
                color: c.headerBg,
                padding: const EdgeInsets.symmetric(horizontal: 44),
                alignment: Alignment.center,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        content.isEmpty ? S.noContentYet : content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.9,
                          color: content.isEmpty ? c.textHint : c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      S.lastUpdated(formatDate(updatedAt)),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
