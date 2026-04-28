import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../services/product_service.dart';

class EditItemPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditItemPage({super.key, required this.item});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;

  String _selectedCategory = kProductCategories.first;
  final List<String> _categories = kProductCategories;

  List<String> _initialImages = [];
  List<String> _existingImages = [];
  final List<XFile> _newPickedFiles = [];
  final List<Uint8List> _newImagesBytes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name']);
    _priceController = TextEditingController(
      text: widget.item['price'].toString(),
    );
    _descController = TextEditingController(
      text: widget.item['description'] ?? '',
    );

    if (_categories.contains(widget.item['category'])) {
      _selectedCategory = widget.item['category'];
    }

    if (widget.item['image_urls'] != null) {
      _existingImages = List<String>.from(widget.item['image_urls']);
    } else if (widget.item['image_url'] != null) {
      _existingImages = [widget.item['image_url']];
    }

    _initialImages = List<String>.from(_existingImages);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 70);

    if (pickedFiles.isNotEmpty) {
      List<Uint8List> bytesList = [];
      for (var file in pickedFiles) {
        bytesList.add(await file.readAsBytes());
      }
      setState(() {
        _newPickedFiles.addAll(pickedFiles);
        _newImagesBytes.addAll(bytesList);
      });
    }
  }

  // 💡 ฟังก์ชันลบรายการสินค้าแบบมืออาชีพ (RPC + DB First)
  Future<void> _deleteListing() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "ลบรายการนี้?",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Noto Sans Thai'],
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          "ยืนยันการลบสินค้า ข้อมูลจะหายไปถาวรนะ",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Noto Sans Thai'],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "ยกเลิก",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Noto Sans Thai'],
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "ลบเลย",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Noto Sans Thai'],
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // ✅ ใช้ ProductService ลบสินค้าพร้อมรูปใน Storage
        await ProductService.instance.deleteProduct(
          widget.item['id'] as String,
          _initialImages,
        );

        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบรายการเรียบร้อยแล้ว'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context)
            ..pop()
            ..pop();
        }
      } catch (e) {
        _showSnackBar('เกิดข้อผิดพลาด: ${e.toString()}', Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateListing() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackBar('ใส่ชื่อและราคาก่อนนะ', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // ลบรูปที่ถูกลบออกไปจาก Storage
      final removed = _initialImages
          .where((u) => !_existingImages.contains(u))
          .toList();
      if (removed.isNotEmpty)
        await ProductService.instance.deleteImageUrls(removed);

      // ✅ ใช้ ProductService อัปเดตสินค้า
      await ProductService.instance.updateProduct(
        id: widget.item['id'] as String,
        name: _nameController.text.trim(),
        price:
            double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0,
        description: _descController.text.trim(),
        category: _selectedCategory,
        existingImageUrls: _existingImages,
        newImageBytesList: List<Uint8List>.from(_newImagesBytes),
        newFileNames: _newPickedFiles.map((f) => f.name).toList(),
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        _showSnackBar('อัปเดตข้อมูลสำเร็จ!', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Noto Sans Thai'],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF191C1D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "แก้ไขข้อมูล",
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Noto Sans Thai'],
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF191C1D),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "อัปเดตสินค้า",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Noto Sans Thai'],
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF191C1D),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "รูปภาพสินค้า",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Noto Sans Thai'],
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E9EC),
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Color(0xFF35408B),
                            size: 28,
                          ),
                          SizedBox(height: 4),
                          Text(
                            "เพิ่มรูป",
                            style: TextStyle(
                              color: Color(0xFF767682),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._existingImages.asMap().entries.map(
                    (entry) => _buildThumbnail(
                      isNetwork: true,
                      url: entry.value,
                      onRemove: () =>
                          setState(() => _existingImages.removeAt(entry.key)),
                    ),
                  ),
                  ..._newImagesBytes.asMap().entries.map(
                    (entry) => _buildThumbnail(
                      isNetwork: false,
                      bytes: entry.value,
                      onRemove: () => setState(() {
                        _newPickedFiles.removeAt(entry.key);
                        _newImagesBytes.removeAt(entry.key);
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildInputField(
              "ชื่อสินค้า",
              "ขายอะไรดีวันนี้?",
              _nameController,
              TextInputType.text,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              "ราคา (บาท)",
              "ตั้งราคาใหม่",
              _priceController,
              const TextInputType.numberWithOptions(decimal: true),
              isPriceField: true,
            ),
            const SizedBox(height: 16),

            Text(
              "หมวดหมู่",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Noto Sans Thai'],
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF767682),
                  ),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: ['Noto Sans Thai'],
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF191C1D),
                    fontSize: 15,
                  ),
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontFamilyFallback: ['Noto Sans Thai'],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputField(
              "รายละเอียด",
              "อธิบายจุดเด่น...",
              _descController,
              TextInputType.multiline,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35408B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "บันทึกการเปลี่ยนแปลง",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: ['Noto Sans Thai'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton.icon(
                onPressed: _isLoading ? null : _deleteListing,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: Text(
                  "ลบรายการสินค้านี้",
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: ['Noto Sans Thai'],
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail({
    required bool isNetwork,
    String? url,
    Uint8List? bytes,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isNetwork
                ? Image.network(
                    url!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Image.memory(
                    bytes!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller,
    TextInputType type, {
    int maxLines = 1,
    bool isPriceField = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Noto Sans Thai'],
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: label == 'ชื่อสินค้า',
          keyboardType: type,
          maxLines: maxLines,
          inputFormatters: isPriceField ? [_PriceInputFormatter()] : null,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Noto Sans Thai'],
            fontWeight: FontWeight.w600,
            color: const Color(0xFF191C1D),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixText: isPriceField ? '฿ ' : null,
            prefixStyle: TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['Noto Sans Thai'],
              fontWeight: FontWeight.bold,
              color: const Color(0xFF35408B),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Price input formatter: ใส่ comma ขณะพิมพ์ ──
class _PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final number = int.tryParse(digits) ?? 0;
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
