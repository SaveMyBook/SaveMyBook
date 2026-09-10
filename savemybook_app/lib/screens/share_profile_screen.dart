import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_tiles.dart';
import '../widgets/state_views.dart';
import 'barcode_scanner_screen.dart';
import 'chat_room_screen.dart';

class ShareProfileScreen extends StatefulWidget {
  const ShareProfileScreen({super.key});

  @override
  State<ShareProfileScreen> createState() => _ShareProfileScreenState();
}

class _ShareProfileScreenState extends State<ShareProfileScreen> {
  final ApiService _api = ApiService();
  String? _qrData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.fetchProfileQrData();
    if (!mounted) return;
    setState(() {
      _qrData = data ?? ApiService.profileUrlFor(ApiService.currentUser?.userId ?? 0);
      _isLoading = false;
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          formats: [BarcodeFormat.qrCode],
          title: '掃描個人 QR Code',
          hint: '將對方的 QR Code 放入框內',
        ),
      ),
    );

    if (code == null || !mounted) return;

    final userId = ApiService.parseProfileUserId(code);
    if (userId == null) {
      showAppSnackBar(context, '這不是 SaveMyBook 的個人 QR Code', isError: true);
      return;
    }
    if (userId == ApiService.currentUser?.userId) {
      showAppSnackBar(context, '這是你自己的 QR Code');
      return;
    }

    final roomId = await _api.openChatRoom(userId: userId);
    if (!mounted) return;

    if (roomId == null) {
      showAppSnackBar(context, '無法建立聊天室，請稍後再試', isError: true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(imageUrl: user?.avatarUrl, radius: 44, background: c.card),
                        const SizedBox(height: 14),
                        Text(
                          user?.nickname ?? '使用者',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.85, end: 1),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          builder: (_, value, child) => Transform.scale(scale: value, child: child),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: _qrData!,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '用任何相機掃描都能開啟你的個人頁',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: GestureDetector(
                onTap: _scan,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: c.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
