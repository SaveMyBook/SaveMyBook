final _cabinetCode = RegExp(r'^savemybook://k/([0-9a-f]{32})/?$', caseSensitive: false);

String? parseCabinetCode(String raw) => _cabinetCode.firstMatch(raw.trim())?.group(1)?.toLowerCase();

bool isCabinetCode(String raw) => parseCabinetCode(raw) != null;
