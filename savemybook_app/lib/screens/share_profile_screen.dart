import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/state_views.dart';
import 'barcode_scanner_screen.dart';

/// 分享個人檔案：以半透明遮罩蓋在會員中心上，中間顯示個人 QR Code。
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
      _qrData = data ?? 'savemybook://user/${ApiService.currentUser?.userId ?? 0}';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.55),
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
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: c.card,
                          backgroundImage:
                              user?.avatarUrl == null ? null : NetworkImage(user!.avatarUrl!),
                          child: user?.avatarUrl == null
                              ? Icon(Icons.person, size: 44, color: c.iconInactive)
                              : null,
                        ),
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
                        Container(
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
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '讓朋友掃描即可看到你的個人檔案',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                        ),
                      ],
                    ),
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: GestureDetector(
                onTap: () async {
                  final code = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                  );
                  if (code != null && mounted) {
                    showAppSnackBar(context, '掃描結果：$code');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
