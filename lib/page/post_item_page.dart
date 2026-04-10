import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; 
import 'product_detail_page.dart'; 

class PostItemPage extends StatefulWidget {
  const PostItemPage({super.key});

  @override
  // 💡 เปิด Public State เพื่อให้ MainScreen สั่งเลื่อนขึ้น (jumpToTop) ได้
  State<PostItemPage> createState() => PostItemPageState();
}

// 💡 ลบขีดล่าง (_) ออกเพื่อให้ไฟล์อื่นเรียกใช้งานฟังก์ชันภายในได้
class PostItemPageState extends State<PostItemPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController(); 
  final ScrollController _scrollController = ScrollController();
  
  String _selectedCategory = 'แฟชั่น'; 
  final List<String> _categories = [
    'แฟชั่น', 
    'ไอที/อุปกรณ์', 
    'ความงาม', 
    'งานบริการ', 
    'อาหาร', 
    'ของสะสม', 
    'ทั่วไป'
  ];

  final List<XFile> _pickedFiles = []; 
  final List<Uint8List> _imagesBytes = []; 
  bool _isLoading = false; 

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _scrollController.dispose(); 
    super.dispose();
  }

  // 💡 ฟังก์ชันสั่งวาร์ปกลับขึ้นบนสุด (ถูกเรียกจาก MainScreen)
  void jumpToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0); 
    }
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
        _pickedFiles.addAll(pickedFiles);
        _imagesBytes.addAll(bytesList);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
      _imagesBytes.removeAt(index);
    });
  }

  Future<void> _postListing() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackBar('ใส่ชื่อสินค้ากับราคาก่อนนะคุณ Kong', Colors.orange);
      return;
    }
    
    if (_imagesBytes.isEmpty) {
      _showSnackBar('เอารูปมาโชว์หน่อย อย่างน้อย 1 รูปนะ', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw Exception('เข้าสู่ระบบก่อนนะ');

      // 1. ระบบอัปโหลดรูปแบบใหม่ ทำงานขนานพร้อมกัน
      List<Future<String>> uploadTasks = [];

      for (int i = 0; i < _pickedFiles.length; i++) {
        final fileExtension = _pickedFiles[i].name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExtension';
        final filePath = '${user.id}/$fileName'; 

        uploadTasks.add(() async {
          await supabase.storage.from('product_images').uploadBinary(
            filePath, 
            _imagesBytes[i],
            fileOptions: FileOptions(contentType: 'image/$fileExtension'),
          );
          return supabase.storage.from('product_images').getPublicUrl(filePath);
        }());
      }

      List<String> uploadedImageUrls = await Future.wait(uploadTasks);

      // 2. แก้บั๊กราคา: ลบลูกน้ำออกก่อนบันทึก
      final rawPrice = _priceController.text.replaceAll(',', '').trim();
      final double finalPrice = double.tryParse(rawPrice) ?? 0.0;

      // 3. บันทึกข้อมูลและดึงข้อมูลกลับมาเพื่อนำทาง
      final newProductData = await supabase.from('products').insert({
        'seller_id': user.id,
        'name': _nameController.text.trim(),
        'price': finalPrice,
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'image_url': uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : '', 
        'image_urls': uploadedImageUrls, 
        'status': 'available',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      if (mounted) {
        HapticFeedback.lightImpact(); 
        _showSnackBar('เย้! ลงขายเรียบร้อยแล้ว', Colors.green);
        _clearFields();

        // นำทางไปหน้า ProductDetailPage ทันที
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productData: newProductData),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearFields() {
    _nameController.clear();
    _priceController.clear();
    _descController.clear();
    _pickedFiles.clear();
    _imagesBytes.clear();
    setState(() => _selectedCategory = 'แฟชั่น'); 
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating
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
        title: Text(
          "ลงขายสินค้า", 
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF191C1D))
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        // 💡 ลบ SizedBox สูงๆ ออกแล้ว หน้าจอจะล็อคการเลื่อนอัตโนมัติถ้าเนื้อหายังไม่ล้น
        controller: _scrollController, 
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ปล่อยของ", 
              style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF191C1D))
            ),
            const SizedBox(height: 24),
            
            Text("รูปภาพสินค้า", style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
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
                        border: Border.all(color: const Color(0xFFE2E9EC), width: 2),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF35408B), size: 28),
                          SizedBox(height: 4),
                          Text("เพิ่มรูป", style: TextStyle(color: Color(0xFF767682), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  ..._imagesBytes.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(entry.key),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildInputField("ชื่อสินค้า", "ขายอะไรดีวันนี้?", _nameController, TextInputType.text),
            const SizedBox(height: 16),
            _buildInputField("ราคา (บาท)", "ตั้งราคาที่คุณพอใจ", _priceController, const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 16),
            
            Text("หมวดหมู่", style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
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
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF767682)),
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: const Color(0xFF191C1D), fontSize: 15),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCategory = newValue);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildInputField("รายละเอียด", "อธิบายจุดเด่นของสินค้านี้สักหน่อย...", _descController, TextInputType.multiline, maxLines: 3),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _postListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35408B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("ลงขายเลย!", style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller, TextInputType type, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: const Color(0xFF191C1D), fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}