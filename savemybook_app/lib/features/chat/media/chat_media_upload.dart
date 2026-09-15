import 'dart:math' as math;

import '../../../i18n/strings.dart';
import '../../../services/api_service.dart';
import '../widgets/chat_entry.dart';

Future<String?> uploadChatSlots(ApiService api, List<ChatUploadSlot> slots, {int concurrency = 3}) async {
  final queue = [for (final slot in slots) if (!slot.uploaded) slot];
  for (final slot in queue) {
    slot.failed.value = false;
    slot.progress.value = 0;
  }
  String? error;

  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final slot = queue.removeAt(0);
      final (url, uploadError) = await api.uploadChatImage(
        slot.localPath,
        onProgress: (value) => slot.progress.value = value,
      );
      if (url == null) {
        slot.failed.value = true;
        error ??= uploadError ?? S.uploadFailedTryAgainLater;
      } else {
        slot.url = url;
        slot.progress.value = 1;
      }
    }
  }

  await Future.wait([for (var i = 0; i < math.min(concurrency, queue.length); i++) worker()]);
  return error;
}
