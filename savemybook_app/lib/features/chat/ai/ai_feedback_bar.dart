import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/ai.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/state_views.dart';
import '../../../i18n/strings.dart';

class AiFeedbackBar extends StatefulWidget {
  final String feature;
  final String messageNo;
  final AiMessageFeedback? initial;
  final ValueChanged<AiMessageFeedback?> onChanged;

  const AiFeedbackBar({
    super.key,
    required this.feature,
    required this.messageNo,
    required this.initial,
    required this.onChanged,
  });

  static String reasonLabel(String code) => switch (code) {
        'books_mismatch' => S.recommendedBooksDoNotMatchMy,
        'inaccurate' => S.inaccurateInformation,
        'off_topic' => S.didNotAnswerQuestion,
        'incomplete' => S.insufficientInformation,
        _ => S.ticketCatOther,
      };

  static List<SheetOption<String>> reasonOptions(String feature) => [
        for (final code in [
          if (feature == 'book_chat') 'books_mismatch',
          'inaccurate',
          'off_topic',
          if (feature == 'support') 'incomplete',
          'other',
        ])
          SheetOption(value: code, label: reasonLabel(code)),
      ];

  @override
  State<AiFeedbackBar> createState() => _AiFeedbackBarState();
}

class _AiFeedbackBarState extends State<AiFeedbackBar> {
  late AiMessageFeedback? _feedback = widget.initial;
  bool _busy = false;

  Future<void> _rate(String rating) async {
    if (_busy) return;
    final clearing = _feedback?.rating == rating;
    String? reason;
    if (!clearing && rating == 'unhelpful') {
      reason = await showOptionSheet<String>(
        context,
        title: S.selectReason,
        options: AiFeedbackBar.reasonOptions(widget.feature),
      );
      if (reason == null || !mounted) return;
    }
    final previous = _feedback;
    final next = clearing ? null : AiMessageFeedback(rating: rating, reason: reason);
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _feedback = next;
    });
    final result = await ApiService().rateAiMessage(widget.feature, widget.messageNo, rating: next?.rating, reason: next?.reason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!result.isOk) _feedback = previous;
    });
    if (!result.isOk) {
      showAppSnackBar(context, result.error ?? '', isError: true);
      return;
    }
    widget.onChanged(_feedback);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final rating = _feedback?.rating;
    Widget button(String value, IconData outlined, IconData filled, String tooltip) {
      final selected = rating == value;
      return IconButton(
        tooltip: tooltip,
        onPressed: _busy ? null : () => _rate(value),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        iconSize: 16,
        isSelected: selected,
        icon: Icon(outlined, color: c.textHint),
        selectedIcon: Icon(filled, color: c.accent),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button('helpful', Icons.thumb_up_alt_outlined, Icons.thumb_up_alt_rounded, S.helpful),
        button('unhelpful', Icons.thumb_down_alt_outlined, Icons.thumb_down_alt_rounded, S.notHelpful),
      ],
    );
  }
}
