import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import 'state_views.dart';
import '../utils/motion.dart';
import 'animations.dart';

class FormRowCard extends StatelessWidget {
  final String label;
  final Widget child;
  final bool alignTop;
  final double labelWidth;
  final EdgeInsetsGeometry margin;

  const FormRowCard({
    super.key,
    required this.label,
    required this.child,
    this.alignTop = false,
    this.labelWidth = 76,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return AppCard(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 10 : 0),
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? prefixText;
  final TextInputAction? textInputAction;

  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefixText,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: TextStyle(color: enabled ? c.textPrimary : c.textHint, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        errorText: errorText,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: c.textPrimary, fontSize: 14),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 24),
        hintStyle: TextStyle(color: c.textHint, fontSize: 13),
        filled: true,
        fillColor: c.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
      ),
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = '請選擇',
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.inputFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: c.textHint, fontSize: 13)),
          dropdownColor: c.card,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.iconInactive),
          style: TextStyle(color: c.textPrimary, fontSize: 14, fontFamily: 'NotoSansTC'),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: c.iconInactive, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) => SwitchIn(
            duration: Motion.micro,
            child: value.text.isEmpty
                ? const SizedBox.shrink(key: ValueKey('empty'))
                : IconButton(
                    key: const ValueKey('clear'),
                    icon: Icon(Icons.close_rounded, size: 18, color: c.iconInactive),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                      onSubmitted?.call('');
                    },
                  ),
          ),
        ),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
      ),
    );
  }
}

class AppDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String hint;

  final DateTime? firstDate;
  final DateTime? lastDate;
  final String helpText;
  final bool clearable;
  final bool enabled;

  const AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '請選擇日期',
    this.firstDate,
    this.lastDate,
    this.helpText = '選擇日期',
    this.clearable = true,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final c = AppColors.of(context);
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 100);
    final last = lastDate ?? now;

    var initial = value ?? (last.isBefore(now) ? last : now);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      cancelText: '取消',
      confirmText: '確定',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c.accent),
        ),
        child: child!,
      ),
    );

    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final date = value;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _pick(context) : null,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date == null
                    ? hint
                    : '${date.year} 年 ${date.month} 月 ${date.day} 日',
                style: TextStyle(
                  fontSize: 14,
                  color: date == null ? c.textHint : c.textPrimary,
                ),
              ),
            ),
            if (date != null && clearable)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(null),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.close_rounded, size: 18, color: c.iconInactive),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today_outlined, size: 16, color: enabled ? c.accent : c.iconInactive),
          ],
        ),
      ),
    );
  }
}

class Validators {
  const Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^0\d{8,9}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPhone(String value) => _phone.hasMatch(value.trim().replaceAll('-', ''));

  static String? password(String value) {
    if (value.length < 8) return '密碼長度至少 8 個字元';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return '密碼需包含英文字母';
    if (!RegExp(r'[0-9]').hasMatch(value)) return '密碼需包含數字';
    return null;
  }
}
