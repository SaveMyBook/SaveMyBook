import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class SellBookScreen extends StatefulWidget {
  const SellBookScreen({super.key});

  @override
  State<SellBookScreen> createState() => _SellBookScreenState();
}

class _SellBookScreenState extends State<SellBookScreen> {
  final _isbnController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();

  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ApiService().fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  @override
  void dispose() {
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_titleController.text.trim().isEmpty) {
      _showError('請輸入書名');
      return;
    }
    if (_selectedCategory == null) {
      _showError('請選擇分類');
      return;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _onScanISBN() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (result != null && mounted) {
      setState(() => _isbnController.text = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          _buildAppBar(c),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildFieldRow(c, label: 'ISBN', child: Row(
                    children: [
                      Expanded(child: _buildInput(c, _isbnController, keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _onScanISBN,
                        child: Icon(Icons.qr_code_scanner_rounded, size: 28, color: c.textPrimary),
                      ),
                    ],
                  )),
                  _buildFieldRow(c, label: '書名', child: _buildInput(c, _titleController)),
                  _buildFieldRow(c, label: '作者', child: _buildInput(c, _authorController)),
                  _buildFieldRow(c, label: '出版社', child: _buildInput(c, _publisherController)),
                  _buildFieldRow(c, label: '出版日期', child: Row(
                    children: [
                      _buildSmallInput(c, _yearController, width: 64),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('年', style: TextStyle(color: c.textSecondary, fontSize: 14))),
                      _buildSmallInput(c, _monthController, width: 48),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('月', style: TextStyle(color: c.textSecondary, fontSize: 14))),
                      _buildSmallInput(c, _dayController, width: 48),
                      Padding(padding: const EdgeInsets.only(left: 6), child: Text('日', style: TextStyle(color: c.textSecondary, fontSize: 14))),
                    ],
                  )),
                  _buildFieldRow(c, label: '選擇分類', child: _buildCategoryDropdown(c)),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 140, height: 46,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text('下一步', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('詳細資訊都可至會員中心-書籍管理編輯', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(AppColors c) {
    return Container(
      decoration: BoxDecoration(color: c.headerBg),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 22),
              const Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('我要賣書', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(AppColors c, {required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 72, child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary))),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildInput(AppColors c, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 15, color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: c.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSmallInput(AppColors c, TextEditingController controller, {required double width}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(fontSize: 15, color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          filled: true, fillColor: c.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Category>(
          value: _selectedCategory,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: c.iconInactive),
          hint: Text('', style: TextStyle(color: c.textHint, fontSize: 15)),
          dropdownColor: c.card,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(fontSize: 15, color: c.textPrimary),
          items: _isLoadingCategories
              ? [DropdownMenuItem<Category>(value: null, child: Text('載入中...', style: TextStyle(color: c.textHint)))]
              : _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.categoryName))).toList(),
          onChanged: (val) => setState(() => _selectedCategory = val),
        ),
      ),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  bool _hasPopped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasPopped) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _hasPopped = true;
      Navigator.pop(context, barcode!.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.5)],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22)),
                      ),
                      const Expanded(child: Text('掃描 ISBN', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 30),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('將條碼放入框內自動掃描', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280, height: 160,
                  child: CustomPaint(painter: _CornerFramePainter(color: Colors.white, cornerLength: 30, strokeWidth: 4, radius: 12)),
                ),
                const Spacer(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double radius;

  _CornerFramePainter({required this.color, required this.cornerLength, required this.strokeWidth, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final cl = cornerLength;

    canvas.drawPath(Path()..moveTo(0, cl)..lineTo(0, r)..quadraticBezierTo(0, 0, r, 0)..lineTo(cl, 0), paint);
    canvas.drawPath(Path()..moveTo(w - cl, 0)..lineTo(w - r, 0)..quadraticBezierTo(w, 0, w, r)..lineTo(w, cl), paint);
    canvas.drawPath(Path()..moveTo(0, h - cl)..lineTo(0, h - r)..quadraticBezierTo(0, h, r, h)..lineTo(cl, h), paint);
    canvas.drawPath(Path()..moveTo(w - cl, h)..lineTo(w - r, h)..quadraticBezierTo(w, h, w, h - r)..lineTo(w, h - cl), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}