import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'product_detail_page.dart';
import 'chat_room_page.dart'; // 💡 1. Import หน้า ChatRoomPage เข้ามา

class SellerProfilePage extends StatelessWidget {
  final String sellerId;
  const SellerProfilePage({super.key, required this.sellerId});

  Future<Map<String, dynamic>> _fetchProfile() async {
    return await Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url, created_at')
        .eq('id', sellerId)
        .single();
  }

  @override
  Widget build(BuildContext context) {
    // 💡 ดึง ID ของเราเองมาเช็ก
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isOwnProfile = currentUserId == sellerId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191C1D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Seller Profile",
          style: GoogleFonts.manrope(
            textStyle: TextStyle(
              fontFamilyFallback: [
                GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai',
              ],
            ),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF191C1D),
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4D58A5)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'ไม่สามารถโหลดข้อมูลได้',
                    style: GoogleFonts.manrope(
                      textStyle: TextStyle(
                        fontFamilyFallback: [
                          GoogleFonts.notoSansThai().fontFamily ??
                              'Noto Sans Thai',
                        ],
                      ),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final profile = snapshot.data!;
          final String username = profile['username'] ?? 'User';
          final String avatarUrl = profile['avatar_url'] ?? '';

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFF5F7FA),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            username,
                            style: GoogleFonts.manrope(
                              textStyle: TextStyle(
                                fontFamilyFallback: [
                                  GoogleFonts.notoSansThai().fontFamily ??
                                      'Noto Sans Thai',
                                ],
                              ),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF35408B),
                            size: 20,
                          ),
                        ],
                      ),
                      const Text(
                        "Verified Identity",
                        style: TextStyle(
                          color: Color(0xFF767682),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (isOwnProfile)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD1DDFA,
                            ).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                color: Color(0xFF35408B),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Public Storefront View",
                                style: GoogleFonts.manrope(
                                  textStyle: TextStyle(
                                    fontFamilyFallback: [
                                      GoogleFonts.notoSansThai().fontFamily ??
                                          'Noto Sans Thai',
                                    ],
                                  ),
                                  color: const Color(0xFF35408B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () {
                                // 💡 ส่งข้อมูลโปรไฟล์ที่เราดึงมาโชว์ในหน้านี้อยู่แล้วข้ามหน้าไปเลย
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatRoomPage(
                                      targetSellerId: sellerId,
                                      peerName:
                                          username, // 💡 ส่งชื่อจากตัวแปรในหน้านี้
                                      peerAvatar:
                                          avatarUrl, // 💡 ส่งรูปจากตัวแปรในหน้านี้
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE2E9EC),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Color(0xFF35408B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 48),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Active Listings",
                          style: GoogleFonts.manrope(
                            textStyle: TextStyle(
                              fontFamilyFallback: [
                                GoogleFonts.notoSansThai().fontFamily ??
                                    'Noto Sans Thai',
                              ],
                            ),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              StreamBuilder<List<Product>>(
                stream: ProductService.instance.streamProductsBySeller(
                  sellerId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          "No items currently listed.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  final products = snapshot.data!
                      .where((item) => item.isAvailable)
                      .toList();

                  if (products.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          "No active items currently listed.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = products[index];
                        return _buildSmallProductCard(context, item);
                      }, childCount: products.length),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSmallProductCard(BuildContext context, Product item) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(productData: item.toRawMap()),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F3F4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF5F7FA),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${formatPrice(item.price)} THB",
                    style: const TextStyle(
                      color: Color(0xFF35408B),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
