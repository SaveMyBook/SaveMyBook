import 'package:flutter/widgets.dart';
import 'legal_text.dart';

class LegalSection {
  final String id;
  final TextEditingController title;
  final TextEditingController body;
  bool removing = false;

  LegalSection({required this.id, String title = '', String body = ''})
      : title = TextEditingController(text: title),
        body = TextEditingController(text: body);

  LegalSectionData get data => LegalSectionData(title.text, body.text);

  bool get isBlank => title.text.trim().isEmpty && body.text.trim().isEmpty;

  bool get missingTitle => title.text.trim().isEmpty && body.text.trim().isNotEmpty;

  void dispose() {
    title.dispose();
    body.dispose();
  }
}
