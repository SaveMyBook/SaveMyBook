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
import '../utils/motion.dart';
import '../i18n/strings.dart';
import '../utils/app_info.dart';

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
  bool _scanning = false;

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
    if (_scanning || _isBusy) return;
    _scanning = true;
    try {
      await _scanAndOpen();
    } finally {
      _scanning = false;
    }
  }

  Future<void> _scanAndOpen() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          formats: [BarcodeFormat.qrCode],
          title: S.scanProfileQrCode,
          hint: S.lineUpTheirQrCodeWith,
        ),
      ),
    );

    if (code == null || !mounted) return;

    final userId = ApiService.parseProfileUserId(code);
    if (userId == null) {
      showAppSnackBar(context, S.notSavemybookProfileQrCode, isError: true);
      return;
    }
    if (userId == ApiService.currentUser?.userId) {
      showAppSnackBar(context, S.ownQrCode);
      return;
    }

    setState(() => _isBusy = true);
    final roomId = await _api.openChatRoom(userId: userId);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (roomId == null) {
      showAppSnackBar(context, S.couldNotStartChatPleaseTry, isError: true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId)),
    );
  }

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
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.linkCopied);
  }

  Future<void> _share() async {
    final data = _qrData;
    if (data == null || _isBusy) return;

    setState(() => _isBusy = true);
    final path = await _captureQr();
    final nickname = ApiService.currentUser?.nickname ?? '';
    final message = nickname.isEmpty
        ? S.addMeSavemybook(data)
        : S.addMeSavemybook2(nickname, data);

    final ok = path == null
        ? await ShareService.shareText(message)
        : await ShareService.shareImage(path, text: message);

    if (!mounted) return;
    setState(() => _isBusy = false);
    if (!ok) showAppSnackBar(context, S.sharingCouldNotOpenSoLink, isError: true);
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
      ok ? S.savedPhotos : S.couldNotSaveCheckPhotoLibrary,
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;

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
                tooltip: S.scanTheirQrCode,
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
                                  borderRadius: BorderRadius.circular(20),
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
                                      user?.nickname ?? S.user,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF151E27),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: 210,
                                      height: 210,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          QrImageView(
                                            data: _qrData!,
                                            version: QrVersions.auto,
                                            size: 210,
                                            backgroundColor: Colors.white,
                                            // 中央 logo 會蓋掉部分模組，容錯等級必須維持 H，否則會掃不到。
                                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.asset(
                                                'assets/images/logo.png',
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Container(
                                                  width: 40,
                                                  height: 40,
                                                  color: AppColors.primary,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.menu_book_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      kAppName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        color: AppColors.primary,
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
                                _buildAction(Icons.link_rounded, S.copyLink, _copyLink),
                                _buildAction(Icons.ios_share_rounded, S.share, _share),
                                _buildAction(Icons.download_rounded, S.actionSave, _saveToPhotos),
                              ],
                            ),
                          ),

                        ],
                      ),
                    ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isBusy,
                child: AnimatedOpacity(
                  opacity: _isBusy ? 1 : 0,
                  duration: Motion.base,
                  child: const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
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
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
