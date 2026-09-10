import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
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
  final GlobalKey _qrBoundary = GlobalKey();

  String? _qrData;
  bool _isLoading = true;
  bool _isBusy = false;

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

  /// 把畫面上的 QR 卡片轉成 PNG 檔，分享與存檔都用同一份。
  Future<String?> _captureQr() async {
    try {
      final boundary =
          _qrBoundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;

      final file = File(
        '${Directory.systemTemp.path}/savemybook_qr_${ApiService.currentUser?.userId ?? 0}.png',
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyLink() async {
    final data = _qrData;
    if (data == null) return;
    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) return;
    showAppSnackBar(context, '已複製連結');
  }

  Future<void> _share() async {
    final data = _qrData;
    if (data == null || _isBusy) return;

    setState(() => _isBusy = true);
    final path = await _captureQr();
    final nickname = ApiService.currentUser?.nickname ?? '';
    final message = nickname.isEmpty
        ? '在 SaveMyBook 上加我：$data'
        : '在 SaveMyBook 上加我（$nickname）：$data';

    final ok = path == null
        ? await ShareService.shareText(message)
        : await ShareService.shareImage(path, text: message);

    if (!mounted) return;
    setState(() => _isBusy = false);
    if (!ok) showAppSnackBar(context, '無法開啟分享，已幫你複製連結', isError: true);
    if (!ok) _copyLink();
  }

  Future<void> _saveToPhotos() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final path = await _captureQr();
    final ok = path != null && await ShareService.saveImage(path);

    if (!mounted) return;
    setState(() => _isBusy = false);
    showAppSnackBar(
      context,
      ok ? '已儲存到相簿' : '儲存失敗，請確認已允許相簿權限',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.62),
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
            Positioned(
              top: 8,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                tooltip: '掃描對方的 QR Code',
                onPressed: _scan,
              ),
            ),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeSlideIn(
                            child: RepaintBoundary(
                              key: _qrBoundary,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    UserAvatar(
                                      imageUrl: user?.avatarUrl,
                                      radius: 32,
                                      background: const Color(0xFFEDF1F4),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      user?.nickname ?? '使用者',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF151E27),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    QrImageView(
                                      data: _qrData!,
                                      version: QrVersions.auto,
                                      size: 210,
                                      backgroundColor: Colors.white,
                                      // 中間挖洞放 logo 會蓋掉部分模組，
                                      // 容錯等級必須拉到 H 才掃得出來。
                                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                                      embeddedImage: const AssetImage('assets/images/logo.png'),
                                      embeddedImageStyle: const QrEmbeddedImageStyle(
                                        size: Size(44, 44),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'SaveMyBook',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: Color(0xFF627D8D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          FadeSlideIn(
                            index: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildAction(Icons.link_rounded, '複製連結', _copyLink),
                                _buildAction(Icons.ios_share_rounded, '分享', _share),
                                _buildAction(Icons.download_rounded, '儲存', _saveToPhotos),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FadeSlideIn(
                            index: 3,
                            child: TextButton.icon(
                              onPressed: _isBusy ? null : _load,
                              icon: Icon(Icons.refresh_rounded, size: 18, color: c.card),
                              label: Text('更新', style: TextStyle(color: c.card)),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (_isBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
    return PressableScale(
      scale: 0.9,
      onTap: _isBusy ? null : onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
