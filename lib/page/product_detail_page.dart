import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_profile_page.dart'; 
import 'edit_item_page.dart';
import 'chat_room_page.dart'; 

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData; 
  const ProductDetailPage({super.key, required this.productData});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  
  late Future<Map<String, dynamic>> _sellerProfileFuture;

  @override
  void initState() {
    super.initState();
    final String sellerId = widget.productData['seller_id'] ?? '';
    _sellerProfileFuture = _fetchSellerProfile(sellerId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchSellerProfile(String sellerId) async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', sellerId)
        .single();
    return response;
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.productData['id'];

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('id', productId),
      builder: (context, snapshot) {
        // 💡 ถ้าสินค้าโดนลบ (snapshot ว่าง) ให้ดีดกลับหน้าก่อนหน้าทันที (ป้องก้นหน้าค้าง)
        if (snapshot.hasData && snapshot.data!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final freshData = (snapshot.hasData && snapshot.data!.isNotEmpty) 
            ? snapshot.data!.first 
            : widget.productData;

        return _buildUI(freshData);
      },
    );
  }

  Widget _buildUI(Map<String, dynamic> data) {
    final String title = data['name'] ?? 'ไม่มีชื่อสินค้า';
    final String price = data['price']?.toString() ?? '0';
    final String description = data['description'] ?? 'ไม่มีรายละเอียดเพิ่มเติม';
    final String category = data['category'] ?? 'ทั่วไป';
    final String sellerId = data['seller_id'] ?? '';
    final List<dynamic> imageUrls = data['image_urls'] ?? ([data['image_url']].where((e) => e != null).toList());
    final isOwnProduct = Supabase.instance.client.auth.currentUser?.id == sellerId;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildCircleBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
        actions: [
          if (!isOwnProduct)
            _buildCircleBtn(Icons.favorite_border, () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("เพิ่มในรายการโปรดแล้ว", style: GoogleFonts.manrope()), behavior: SnackBarBehavior.floating),
              );
            }),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- รูปภาพสินค้า Hero Animation ---
            Hero(
              tag: 'product_image_${data['id']}', 
              child: Stack(
                children: [
                  SizedBox(
                    height: 480,
                    width: double.infinity,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: imageUrls.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) => Image.network(imageUrls[index], fit: BoxFit.cover),
                    ),
                  ),
                  if (imageUrls.length > 1)
                    Positioned(
                      bottom: 20, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imageUrls.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 4,
                            width: _currentImageIndex == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index ? const Color(0xFF35408B) : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(6)),
                    child: Text(category.toUpperCase(), style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF35408B), letterSpacing: 1)),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF191C1D))),
                  const SizedBox(height: 16),
                  Text("$price THB", style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF35408B))),
                  const SizedBox(height: 32),

                  Text("รายละเอียด", style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(description, style: GoogleFonts.manrope(fontSize: 15, color: Colors.grey[700], height: 1.6)),
                  const SizedBox(height: 32),
                  
                  Text("ข้อมูลผู้ขาย", style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildSellerCard(sellerId),
                  const SizedBox(height: 120),
                ],
              ),
            )
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(data, isOwnProduct),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.black, size: 18), onPressed: onTap),
    );
  }

  Widget _buildSellerCard(String sellerId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _sellerProfileFuture, 
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 80);
        final sellerName = snapshot.data?['username'] ?? 'ไม่ทราบชื่อ';
        final sellerAvatar = snapshot.data?['avatar_url'] ?? '';

        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerProfilePage(sellerId: sellerId))),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E9EC))),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: const Color(0xFFF5F7FA), backgroundImage: sellerAvatar.isNotEmpty ? NetworkImage(sellerAvatar) : null, child: sellerAvatar.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sellerName, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)), Text("Verified Member", style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey))])),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(Map<String, dynamic> data, bool isOwn) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F3F4)))),
      child: isOwn 
        ? SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditItemPage(item: data))),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5F7FA), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text("แก้ไขข้อมูลสินค้า", style: GoogleFonts.manrope(color: const Color(0xFF35408B), fontWeight: FontWeight.bold)),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  // 🚀 💡 จุดเปลี่ยนสำคัญ: ส่งข้อมูลคู่สนทนาไปโชว์รอที่หน้าแชททันที
                  onPressed: () async {
                    // ดึงโปรไฟล์ผู้ขายจาก Future ที่เราโหลดรอไว้แล้ว
                    final sellerProfile = await _sellerProfileFuture;

                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomPage(
                            product: data,
                            peerName: sellerProfile['username'],    // 💡 ส่งชื่อผู้ขายไป
                            peerAvatar: sellerProfile['avatar_url'], // 💡 ส่งรูปผู้ขายไป
                          ),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Color(0xFFE2E9EC))),
                  child: Text("ทักแชท", style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF35408B), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text("ซื้อเลย", style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
    );
  }
}