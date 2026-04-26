import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/product_service.dart';
import 'login_page.dart';
import 'edit_profile_page.dart'; 
import 'my_listings_page.dart';
import 'security_page.dart';
import 'seller_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String _username = 'Loading...';
  String _avatarUrl = '';
  String _userId = ''; 
  int _activeListingsCount = 0; // 💡 ตัวแปรเก็บจำนวนสินค้าที่ลงขาย
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.fastOutSlowIn);
    }
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        _userId = user.id; 
        
        // 1. ดึงข้อมูลโปรไฟล์
        final profileData = await supabase.from('profiles').select('username, avatar_url').eq('id', user.id).single();
        
        // 2. ดึงจำนวนสินค้าที่เราลงขาย (Active Assets) ผ่าน ProductService
        final products = await ProductService.instance.getProductsBySeller(user.id);

        if (mounted) {
          setState(() {
            _username = profileData['username'] ?? 'Unknown User';
            _avatarUrl = profileData['avatar_url'] ?? '';
            _activeListingsCount = products.length; // นับจำนวน
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D58A5)))
          : RefreshIndicator(
              onRefresh: _fetchProfileData,
              color: const Color(0xFF35408B),
              child: SingleChildScrollView(
                controller: _scrollController, 
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // --- Header Section ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                      decoration: const BoxDecoration(
                        color: Color(0xFF35408B),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                  image: _avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover) : null,
                                ),
                                child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("VERIFIED MEMBER", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD1DDFA), letterSpacing: 1.5)),
                                    const SizedBox(height: 4),
                                    Text(_username, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage())).then((_) => _fetchProfileData()),
                                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                              )
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerProfilePage(sellerId: _userId))),
                              icon: const Icon(Icons.storefront, color: Colors.white, size: 18),
                              label: const Text("Preview Public Storefront", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // --- Dynamic Stats Card ---
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: const Color(0xFF4D58A5).withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // 💡 เปลี่ยนจากคำว่า View เป็นตัวเลขจำนวนสินค้าจริงๆ
                              _buildStatItem("Active Assets", _activeListingsCount.toString(), Icons.inventory_2_rounded, () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const MyListingsPage())).then((_) => _fetchProfileData());
                              }),
                              Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.2)),
                              _buildStatItem("Vault Rating", "100%", Icons.star_rounded, () {}),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // --- Cleaned Up Menu ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SHOPPING", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF767682))),
                          const SizedBox(height: 16),
                        
                          _buildMenuTile(
                            icon: Icons.favorite_border_rounded,
                            title: "Saved Items",
                            subtitle: "View your wishlist and favorite assets",
                            onTap: () {}, // รอทำหน้า Favorite ในอนาคต
                          ),
                          _buildMenuTile(
                            icon: Icons.shopping_bag_outlined,
                            title: "My Purchases",
                            subtitle: "Track assets you've acquired",
                            onTap: () {},
                          ),
                          
                          const SizedBox(height: 32),
                          Text("ACCOUNT", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF767682))),
                          const SizedBox(height: 16),
                          _buildMenuTile(
                            icon: Icons.security_rounded,
                            title: "Security & Account",
                            subtitle: "Password and account deletion",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityPage())),
                          ),
                          
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _logout,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFFba1a1a).withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.logout, color: Color(0xFFba1a1a)),
                              label: Text("LOG OUT", style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFba1a1a), letterSpacing: 1)),
                            ),
                          ),
                          const SizedBox(height: 100), 
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4D58A5), size: 28),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF191C1D))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF767682), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: const Color(0xFF35408B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF191C1D))),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF767682), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFC6C5D3)),
            ],
          ),
        ),
      ),
    );
  }
}