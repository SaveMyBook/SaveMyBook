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

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

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

  void _showImageSourceActionSheet() {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      clipBehavior: Clip.antiAlias,
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
                _pickCameraImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: c.textPrimary),
              title: Text('從相簿選取', style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickGalleryImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCameraImage() async {
    try {
      if (_images.length >= 10) return;
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 65,
      );
      if (image != null && mounted) {
        setState(() => _images.add(image));
      }
    } catch (e) {
      _showAlertDialog('錯誤', '無法開啟相機，請確認已授權。');
    }
  }

  Future<void> _pickGalleryImages() async {
    try {
      final int remaining = 10 - _images.length;
      if (remaining <= 0) return;

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 65,
      );
      if (images.isNotEmpty && mounted) {
        setState(() {
          _images.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      _showAlertDialog('錯誤', '無法讀取相簿，請確認已授權。');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  String _getImageLabel(int index) {
    if (index == 0) return '封面';
    if (index == 1) return '背面';
    if (index == 2) return '條碼';
    return '補充照片';
  }

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
    if (_images.length < 3) {
      _showAlertDialog('照片不足', '請至少上傳 3 張必填照片（封面、背面、條碼）。');
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
      request.fields['description'] = widget.description;
      request.fields['category_id'] = widget.categoryId.toString();
      request.fields['price'] = _priceController.text.trim();
      request.fields['condition_level'] = _condition;
      request.fields['cabinet_id'] = _selectedCabinet.toString();

      request.files.add(await http.MultipartFile.fromPath('cover_image', _images[0].path));
      request.files.add(await http.MultipartFile.fromPath('back_image', _images[1].path));
      request.files.add(await http.MultipartFile.fromPath('barcode_image', _images[2].path));

      for (var i = 3; i < _images.length; i++) {
        request.files.add(await http.MultipartFile.fromPath('optional_images', _images[i].path));
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
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
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
    int requiredCount = _images.length > 3 ? 3 : _images.length;
    int itemCount = _images.length < 3 ? 3 : (_images.length < 10 ? _images.length + 1 : 10);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
                      children: const [
                        TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ]
                  ),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(width: 8),
                Text('($requiredCount/3)', style: TextStyle(fontSize: 14, color: requiredCount < 3 ? Colors.red.shade400 : c.textSecondary, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_images.length}/10', style: TextStyle(fontSize: 14, color: c.textHint)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: index >= _images.length
                          ? _buildAddImageButton(c, index, key: ValueKey('add_$index'))
                          : _buildImageItem(c, index, _images[index], key: ValueKey('img_${_images[index].path}')),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(AppColors c, int index, XFile imageFile, {Key? key}) {
    return Column(
      key: key,
      children: [
        Container(
          width: 90, height: 110,
          decoration: BoxDecoration(border: Border.all(color: c.divider, width: 1.5), borderRadius: BorderRadius.circular(8)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(imageFile.path), fit: BoxFit.cover)),
              Positioned(
                top: 4, right: 4,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _removeImage(index),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.black87, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
            _getImageLabel(index),
            style: TextStyle(color: index < 3 ? Colors.red.shade400 : c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)
        ),
      ],
    );
  }

  Widget _buildAddImageButton(AppColors c, int index, {Key? key}) {
    return Column(
      key: key,
      children: [
        Material(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _showImageSourceActionSheet,
            child: Container(
              width: 90, height: 110,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                  SizedBox(height: 4),
                  Text('加入', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
            _getImageLabel(index),
            style: TextStyle(color: index < 3 ? Colors.red.shade400 : c.textHint, fontSize: 12, fontWeight: FontWeight.w600)
        ),
      ],
    );
  }

  Widget _buildCardRow(AppColors c, String label, Widget child, {bool isRequired = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text.rich(
                TextSpan(
                    text: label,
                    children: [
                      if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ]
                ),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              )
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