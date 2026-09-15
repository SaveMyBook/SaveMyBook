import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_forms.dart';
import '../../../widgets/app_header.dart';
import 'legal_section.dart';
import 'legal_text.dart';

class LegalSectionPage extends StatefulWidget {
  final List<LegalSection> sections;
  final TextEditingController intro;
  final int initialIndex;
  final int Function() onAppend;

  const LegalSectionPage({
    super.key,
    required this.sections,
    required this.intro,
    required this.initialIndex,
    required this.onAppend,
  });

  @override
  State<LegalSectionPage> createState() => _LegalSectionPageState();
}

class _LegalSectionPageState extends State<LegalSectionPage> {
  late int _index = widget.initialIndex;

  bool get _isIntro => _index < 0;

  LegalSection? get _section => _isIntro ? null : widget.sections[_index];

  String _headline(int index) => index < 0 ? S.preamble : S.sectionP0(index + 1);

  void _go(int index) {
    if (index == _index) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  void _next() {
    if (_index + 1 < widget.sections.length) {
      _go(_index + 1);
      return;
    }
    final created = widget.onAppend();
    _go(created);
  }

  Future<void> _jump() async {
    final c = AppColors.of(context);
    FocusScope.of(context).unfocus();
    final target = await showOptionSheet<int>(
      context,
      title: S.goSection,
      options: [
        SheetOption(value: -1, label: S.preamble, icon: Icons.notes_rounded, selected: _index == -1),
        for (var i = 0; i < widget.sections.length; i++)
          SheetOption(
            value: i,
            label: '${i + 1}. ${widget.sections[i].title.text.trim().isEmpty ? S.untitledSection : widget.sections[i].title.text.trim()}',
            color: widget.sections[i].title.text.trim().isEmpty ? c.textSecondary : null,
            selected: _index == i,
          ),
      ],
    );
    if (target != null && mounted) _go(target);
  }

  Future<void> _delete() async {
    final section = _section;
    if (section == null) return;
    if (!section.isBlank) {
      final title = section.title.text.trim();
      final ok = await showConfirmDialog(
        context,
        title: S.deleteSection,
        message: title.isEmpty ? S.contentsSectionRemovedWith : S.p0ItsContentsRemoved(title),
        confirmLabel: S.actionDelete,
        isDestructive: true,
      );
      if (!ok || !mounted) return;
    }
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _index);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final section = _section;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: _headline(_index),
            actions: [
              HeaderIconButton(icon: Icons.toc_rounded, onTap: _jump),
              if (section != null) HeaderIconButton(icon: Icons.delete_outline_rounded, onTap: _delete),
            ],
          ),
          Expanded(
            child: SwitchIn(
              duration: Motion.micro,
              child: ListView(
                key: ValueKey(section?.id ?? 'intro'),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (section != null) ...[
                    _label(S.sectionTitle, c),
                    AppTextField(
                      controller: section.title,
                      hint: S.sectionTitle,
                      maxLength: LegalText.maxTitleLength,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      Expanded(child: _label(section == null ? S.preamble : S.sectionContent, c)),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: section?.body ?? widget.intro,
                        builder: (_, value, _) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            S.p0Characters(LegalText.charCount(value.text)),
                            style: TextStyle(fontSize: 12, color: c.textHint),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: c.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: TextField(
                      controller: section?.body ?? widget.intro,
                      maxLines: null,
                      minLines: 12,
                      keyboardType: TextInputType.multiline,
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      style: TextStyle(fontSize: 15, height: 1.8, color: c.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: section == null ? S.unnumberedOpeningTextLeaveEmptyIf : S.bodySectionSingleLineBreaksKept,
                        hintMaxLines: 4,
                        hintStyle: TextStyle(color: c.textHint, height: 1.8, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, keyboardOpen ? 8 : MediaQuery.paddingOf(context).bottom + 8),
            decoration: BoxDecoration(
              color: c.card,
              border: Border(top: BorderSide(color: c.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavButton(
                    icon: Icons.chevron_left_rounded,
                    label: _index <= 0 ? S.preamble : S.previous,
                    onTap: _index < 0 ? null : () => _go(_index - 1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _isIntro ? '—' : '${_index + 1} / ${widget.sections.length}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
                  ),
                ),
                Expanded(
                  child: _NavButton(
                    icon: _index + 1 < widget.sections.length ? Icons.chevron_right_rounded : Icons.add_rounded,
                    label: _index + 1 < widget.sections.length ? S.next2 : S.addSection,
                    trailingIcon: true,
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool trailingIcon;

  const _NavButton({required this.icon, required this.label, this.onTap, this.trailingIcon = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = onTap == null ? c.textHint : c.accent;
    final iconWidget = Icon(icon, size: 20, color: color);

    return PressableScale(
      scale: 0.96,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.transparent : c.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!trailingIcon) iconWidget,
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            if (trailingIcon) iconWidget,
          ],
        ),
      ),
    );
  }
}
