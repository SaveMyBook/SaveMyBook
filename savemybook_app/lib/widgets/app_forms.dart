import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import 'state_views.dart';

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
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: c.iconInactive),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                    onSubmitted?.call('');
                  },
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

class DateFieldGroup extends StatelessWidget {
  final TextEditingController year;
  final TextEditingController month;
  final TextEditingController day;

  const DateFieldGroup({
    super.key,
    required this.year,
    required this.month,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget unit(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13)),
        );

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AppTextField(
            controller: year,
            hint: '2026',
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        unit('年'),
        Expanded(
          flex: 2,
          child: AppTextField(
            controller: month,
            hint: '01',
            maxLength: 2,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        unit('月'),
        Expanded(
          flex: 2,
          child: AppTextField(
            controller: day,
            hint: '01',
            maxLength: 2,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        unit('日'),
      ],
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

  static String? date(String year, String month, String day) {
    if (year.isEmpty && month.isEmpty && day.isEmpty) return null;
    if (year.isEmpty || month.isEmpty || day.isEmpty) return '日期請填寫完整';

    final y = int.tryParse(year);
    final m = int.tryParse(month);
    final d = int.tryParse(day);
    if (y == null || m == null || d == null) return '日期格式不正確';
    if (y < 1900 || y > DateTime.now().year + 1) return '年份不在合理範圍';
    if (m < 1 || m > 12) return '月份必須介於 1 ~ 12';

    final lastDay = DateTime(y, m + 1, 0).day;
    if (d < 1 || d > lastDay) return '該月份沒有這一天';
    return null;
  }
}
