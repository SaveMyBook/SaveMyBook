import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';

class SellBookDetailScreen extends StatefulWidget {
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String publishDate;
  final String description; // <-- 這裡接收了簡介
  final int categoryId;

  const SellBookDetailScreen({
    super.key,
    required this.isbn,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishDate,
    required this.description, // <-- 構造函數加入簡介
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

  final ImagePicker _picker = ImagePicker();
  XFile? _coverImage;
  XFile? _backImage;
  XFile? _barcodeImage;
  final List<XFile> _optionalImages = [];

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

  void _showImageSourceActionSheet(int index) {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: c.textPrimary),
              title: Text('拍照', style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(index, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: c.textPrimary),
              title: Text('從相簿選取', style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(index, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(int index, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 65,
      );
      if (image != null && mounted) {
        setState(() {
          if (index == 0) _coverImage = image;
          if (index == 1) _backImage = image;
          if (index == 2) _barcodeImage = image;
        });
      }
    } catch (e) {
      _showAlertDialog('錯誤', '無法讀取圖片，請確認已開啟權限：$e');
    }
  }

  Future<void> _pickOptionalImages() async {
    try {
      final int remaining = 7 - _optionalImages.length;
      if (remaining <= 0) return;

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 65,
      );
      if (images.isNotEmpty && mounted) {
        setState(() {
          _optionalImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      _showAlertDialog('錯誤', '無法讀取多張圖片：$e');
    }
  }

  void _removeMainImage(int index) {
    setState(() {
      if (index == 0) _coverImage = null;
      if (index == 1) _backImage = null;
      if (index == 2) _barcodeImage = null;
    });
  }

  void _removeOptionalImage(int index) {
    setState(() {
      _optionalImages.removeAt(index);
    });
  }

  void _showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_coverImage == null || _backImage == null || _barcodeImage == null) {
      _showAlertDialog('資料不齊全', '請務必上傳「封面」、「背面」與「條碼」這三張必填照片。');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showAlertDialog('資料不齊全', '請輸入自訂價格。');
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
      request.fields['description'] = widget.description; // <-- 將簡介送往後端
      request.fields['category_id'] = widget.categoryId.toString();
      request.fields['price'] = _priceController.text.trim();
      request.fields['condition_level'] = _condition;
      request.fields['cabinet_id'] = _selectedCabinet.toString();

      request.files.add(await http.MultipartFile.fromPath('cover_image', _coverImage!.path));
      request.files.add(await http.MultipartFile.fromPath('back_image', _backImage!.path));
      request.files.add(await http.MultipartFile.fromPath('barcode_image', _barcodeImage!.path));

      for (var i = 0; i < _optionalImages.length; i++) {
        request.files.add(await http.MultipartFile.fromPath('optional_images', _optionalImages[i].path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上架成功！'), backgroundColor: Colors.green),
        );
        // 上架成功後，清空頁面堆疊並重新載入首頁（達成自動清空與重新整理）
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      _showAlertDialog('連線異常', '無法連線至伺服器或上傳超時，請檢查網路狀態：\n$e');
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
                  _buildMainImagesSection(c),
                  const SizedBox(height: 16),
                  _buildOptionalImagesSection(c),
                  const SizedBox(height: 16),
                  _buildCardRow(c, '書況', _buildConditionDropdown(c)),
                  const SizedBox(height: 16),
                  _buildCardRow(c, '自訂價格', _buildInput(c, _priceController, TextInputType.number)),
                  const SizedBox(height: 16),
                  _buildCardRow(c, '存放區域', _buildCabinetDropdown(c)),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                ),
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
              const SizedBox(width: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainImagesSection(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('必填照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(width: 8),
              Text('(3/3)', style: TextStyle(fontSize: 14, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMainImageSlot(c, index: 0, imageFile: _coverImage, label: '封面'),
              _buildMainImageSlot(c, index: 1, imageFile: _backImage, label: '背面'),
              _buildMainImageSlot(c, index: 2, imageFile: _barcodeImage, label: '條碼'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalImagesSection(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('補充照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(width: 8),
              Text('(${_optionalImages.length}/7)', style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const Spacer(),
              const Text('選填', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              ..._optionalImages.asMap().entries.map((e) => _buildOptionalImageSlot(c, index: e.key, imageFile: e.value)),
              if (_optionalImages.length < 7) _buildAddOptionalButton(c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainImageSlot(AppColors c, {required int index, required XFile? imageFile, required String label}) {
    final bool isFilled = imageFile != null;
    return GestureDetector(
      onTap: () => isFilled ? null : _showImageSourceActionSheet(index),
      child: Container(
        width: 100, height: 130,
        decoration: BoxDecoration(border: Border.all(color: c.divider, width: 1.5), borderRadius: BorderRadius.circular(8)),
        child: isFilled
            ? Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(imageFile.path), fit: BoxFit.cover)),
            Positioned(
              top: -4, right: -4,
              child: IconButton(icon: const Icon(Icons.cancel, color: Colors.black87), onPressed: () => _removeMainImage(index)),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: c.iconInactive, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalImageSlot(AppColors c, {required int index, required XFile imageFile}) {
    return Container(
      width: 80, height: 104,
      decoration: BoxDecoration(border: Border.all(color: c.divider, width: 1), borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(imageFile.path), fit: BoxFit.cover)),
          Positioned(
            top: -10, right: -10,
            child: IconButton(icon: const Icon(Icons.cancel, color: Colors.black87, size: 20), onPressed: () => _removeOptionalImage(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOptionalButton(AppColors c) {
    return GestureDetector(
      onTap: _pickOptionalImages,
      child: Container(
        width: 80, height: 104,
        decoration: BoxDecoration(border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5, style: BorderStyle.solid), borderRadius: BorderRadius.circular(8), color: AppColors.primary.withOpacity(0.05)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
            SizedBox(height: 4),
            Text('加入', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow(AppColors c, String label, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary))),
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
    return Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: c.inputFill, border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _buildCabinetDropdown(AppColors c) {
    return Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: c.inputFill, border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
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
    );
  }
}