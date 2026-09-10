import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/photo_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import 'home_screen.dart';

class SellBookDetailScreen extends StatefulWidget {
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String publishDate;
  final String description;
  final int categoryId;

  const SellBookDetailScreen({
    super.key,
    required this.isbn,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishDate,
    required this.description,
    required this.categoryId,
  });

  @override
  State<SellBookDetailScreen> createState() => _SellBookDetailScreenState();
}

class _SellBookDetailScreenState extends State<SellBookDetailScreen> {
  final _priceController = TextEditingController();
  String _condition = 'good';
  int? _selectedCabinet;

  List<Map<String, dynamic>> _cabinets = [];
  bool _isLoadingCabinets = true;

  /// 前三格是固定欄位（封面／背面／條碼），點哪一格就放哪一格，
  /// 不能用單一 List append，否則點第三格的照片會被塞到第二格去。
  static const _requiredLabels = ['封面', '背面', '條碼'];
  final List<XFile?> _slots = List<XFile?>.filled(_requiredLabels.length, null, growable: false);
  final List<XFile> _extra = [];

  int get _filledRequired => _slots.where((f) => f != null).length;
  int get _totalImages => _filledRequired + _extra.length;

  @override
  void initState() {
    super.initState();
    _loadCabinets();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadCabinets() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/cabinets');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${ApiService.authToken}',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        List<Map<String, dynamic>> fetchedCabinets = List<Map<String, dynamic>>.from(data['data'] ?? []);

        Position? currentPos;
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
              currentPos = await Geolocator.getCurrentPosition();
            }
          }
        } catch (_) {}

        if (currentPos != null && fetchedCabinets.isNotEmpty) {
          fetchedCabinets.sort((a, b) {
            final latA = double.tryParse(a['latitude'].toString()) ?? 0.0;
            final lngA = double.tryParse(a['longitude'].toString()) ?? 0.0;
            final latB = double.tryParse(b['latitude'].toString()) ?? 0.0;
            final lngB = double.tryParse(b['longitude'].toString()) ?? 0.0;
            final distA = Geolocator.distanceBetween(currentPos!.latitude, currentPos.longitude, latA, lngA);
            final distB = Geolocator.distanceBetween(currentPos.latitude, currentPos.longitude, latB, lngB);
            return distA.compareTo(distB);
          });
        }

        if (mounted) {
          setState(() {
            _cabinets = fetchedCabinets;
            if (_cabinets.isNotEmpty) {
              _selectedCabinet = _cabinets.first['cabinet_id'];
            }
            _isLoadingCabinets = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingCabinets = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCabinets = false);
    }
  }

  /// 指定其中一個固定欄位（封面／背面／條碼），一次一張，會直接覆蓋該格。
  Future<void> _pickRequired(int slot) async {
    final path = await PhotoService.pickAndCrop(context, aspectRatio: 3 / 4, outputSize: 1200);
    if (path == null || !mounted) return;
    setState(() => _slots[slot] = XFile(path));
  }

  Future<void> _addExtraImages() async {
    final remaining = 10 - _totalImages;
    if (remaining <= 0) {
      _showAlertDialog('照片已滿', '最多只能上傳 10 張照片。');
      return;
    }

    final paths = await PhotoService.pickAndCropMultiple(
      context,
      remaining: remaining,
      aspectRatio: 3 / 4,
      outputSize: 1200,
    );
    if (paths.isEmpty || !mounted) return;
    setState(() => _extra.addAll(paths.map(XFile.new)));
  }

  void _removeRequired(int slot) => setState(() => _slots[slot] = null);

  void _removeExtra(int index) => setState(() => _extra.removeAt(index));

  String _getImageLabel(int index) =>
      index < _requiredLabels.length ? _requiredLabels[index] : '補充照片';

  void _showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_filledRequired < _requiredLabels.length) {
      final missing = [
        for (var i = 0; i < _slots.length; i++)
          if (_slots[i] == null) _requiredLabels[i],
      ].join('、');
      _showAlertDialog('照片不足', '還缺少：$missing。這三張是必填的。');
      return;
    }
    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      _showAlertDialog('資料不齊全', '請輸入自訂價格。');
      return;
    }
    if (price <= 0) {
      _showAlertDialog('價格不正確', '售價必須大於 0 元。');
      return;
    }
    if (price > 99999) {
      _showAlertDialog('價格不正確', '售價不可超過 99999 元。');
      return;
    }
    if (_selectedCabinet == null) {
      _showAlertDialog('資料不齊全', '請選擇存放區域。');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/books');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer ${ApiService.authToken}';

      request.fields['title'] = widget.title;
      request.fields['author'] = widget.author;
      request.fields['publisher'] = widget.publisher;
      request.fields['publish_date'] = widget.publishDate;
      request.fields['isbn'] = widget.isbn;
      request.fields['description'] = widget.description;
      request.fields['category_id'] = widget.categoryId.toString();
      request.fields['price'] = price.toStringAsFixed(0);
      request.fields['condition_level'] = _condition;
      request.fields['cabinet_id'] = _selectedCabinet.toString();

      request.files.add(await http.MultipartFile.fromPath('cover_image', _slots[0]!.path));
      request.files.add(await http.MultipartFile.fromPath('back_image', _slots[1]!.path));
      request.files.add(await http.MultipartFile.fromPath('barcode_image', _slots[2]!.path));

      for (final file in _extra) {
        request.files.add(await http.MultipartFile.fromPath('optional_images', file.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上架成功！'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const HomeScreen(),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
              (route) => false,
        );
      } else {
        String errMsg = '未知錯誤';
        try {
          final data = jsonDecode(response.body);
          errMsg = data['message'] ?? response.body;
        } catch (_) {
          errMsg = response.body;
        }
        _showAlertDialog('上架失敗', '伺服器回應錯誤：$errMsg');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showAlertDialog('連線異常', '無法連線至伺服器或上傳超時，請檢查網路狀態。');
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  _buildImageUploadSection(c),
                  const SizedBox(height: 16),
                  _buildCardRow(c, '書況', _buildConditionDropdown(c), isRequired: true),
                  const SizedBox(height: 16),
                  _buildCardRow(c, '自訂價格', _buildInput(c, _priceController, TextInputType.number), isRequired: true),
                  const SizedBox(height: 16),
                  _buildCardRow(c, '存放區域', _buildCabinetDropdown(c), isRequired: true),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('確認完成上架', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 80),
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
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                splashRadius: 24,
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('詳細資訊與照片', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection(AppColors c) {
    final canAddMore = _totalImages < 10;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text.rich(
                  TextSpan(
                    text: '書籍照片',
                    children: [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  '($_filledRequired/3)',
                  style: TextStyle(
                    fontSize: 14,
                    color: _filledRequired < 3 ? c.danger : c.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text('$_totalImages/10', style: TextStyle(fontSize: 14, color: c.textHint)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '封面、背面、條碼三格請分別點選，其餘為補充照片',
              style: TextStyle(fontSize: 11, color: c.textHint),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _slots.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildSlot(c, i),
                    ),
                  for (var i = 0; i < _extra.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildExtra(c, i),
                    ),
                  if (canAddMore)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildAddImageButton(c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(AppColors c, int slot) {
    final file = _slots[slot];

    return _buildTile(
      c,
      label: _requiredLabels[slot],
      labelColor: file == null ? c.danger : c.textSecondary,
      child: file == null
          ? _buildEmptyTile(c, Icons.add_a_photo_outlined, '必填', c.danger)
          : _buildFilledTile(c, file, onRemove: () => _removeRequired(slot)),
      onTap: () => _pickRequired(slot),
    );
  }

  Widget _buildExtra(AppColors c, int index) {
    return _buildTile(
      c,
      label: '補充 ${index + 1}',
      labelColor: c.textSecondary,
      child: _buildFilledTile(c, _extra[index], onRemove: () => _removeExtra(index)),
      onTap: null,
    );
  }

  Widget _buildTile(
    AppColors c, {
    required String label,
    required Color labelColor,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        PressableScale(
          scale: onTap == null ? 1 : 0.94,
          onTap: onTap,
          child: SizedBox(
            width: 90,
            height: 110,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (widget, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: widget),
              ),
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEmptyTile(AppColors c, IconData icon, String hint, Color tint) {
    return Container(
      key: ValueKey('empty_$hint$icon'),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        border: Border.all(color: tint.withValues(alpha: 0.45), width: 1.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: tint, size: 26),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilledTile(AppColors c, XFile file, {required VoidCallback onRemove}) {
    return Stack(
      key: ValueKey('img_${file.path}'),
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(file.path), fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Colors.black87, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton(AppColors c) {
    return _buildTile(
      c,
      label: '補充照片',
      labelColor: c.textHint,
      onTap: _addExtraImages,
      child: _buildEmptyTile(c, Icons.add_photo_alternate_outlined, '加入', c.accent),
    );
  }

  Widget _buildCardRow(AppColors c, String label, Widget child, {bool isRequired = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (isRequired)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildInput(AppColors c, TextEditingController controller, TextInputType type) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(fontSize: 15, color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: c.inputFill,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }

  Widget _buildConditionDropdown(AppColors c) {
    return Material(
      color: c.inputFill,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _condition,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: c.iconInactive),
            dropdownColor: c.card,
            style: TextStyle(fontSize: 15, color: c.textPrimary),
            items: const [
              DropdownMenuItem(value: 'like_new', child: Text('全新')),
              DropdownMenuItem(value: 'good', child: Text('近全新')),
              DropdownMenuItem(value: 'fair', child: Text('良好')),
              DropdownMenuItem(value: 'poor', child: Text('尚可')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _condition = val);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCabinetDropdown(AppColors c) {
    return Material(
      color: c.inputFill,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: _isLoadingCabinets
              ? Center(child: Text('載入中...', style: TextStyle(color: c.textHint, fontSize: 15)))
              : DropdownButton<int>(
            value: _selectedCabinet,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: c.iconInactive),
            dropdownColor: c.card,
            style: TextStyle(fontSize: 15, color: c.textPrimary),
            items: _cabinets.map((cab) => DropdownMenuItem<int>(value: cab['cabinet_id'], child: Text(cab['cabinet_name'] ?? '未知機櫃'))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCabinet = val);
            },
          ),
        ),
      ),
    );
  }
}