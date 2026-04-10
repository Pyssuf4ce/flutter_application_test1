import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 💡 Import หน้าต่างๆ เข้ามาให้ครบ
import 'discover_page.dart';
import 'chat_list_page.dart'; 
import 'post_item_page.dart';
import 'profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 💡 สร้างกุญแจสำหรับควบคุมหน้าลูกๆ (ระบุ Type ให้ชัดเจน)
  final GlobalKey<DiscoverPageState> _discoverKey = GlobalKey<DiscoverPageState>();
  final GlobalKey<ChatListPageState> _chatKey = GlobalKey<ChatListPageState>(); 
  final GlobalKey<PostItemPageState> _sellKey = GlobalKey<PostItemPageState>();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 💡 จัดลำดับหน้าให้ตรงกับ Index ของปุ่มกด (0, 1, 2, 4)
    _pages = [
      DiscoverPage(key: _discoverKey), // Index 0 (SHOP)
      ChatListPage(key: _chatKey),     // Index 1 (CHAT)
      PostItemPage(key: _sellKey),     // Index 2 (SELL)
      const SizedBox(),                // Index 3 (เว้นว่างไว้)
      ProfilePage(key: _profileKey),   // Index 4 (PROFILE)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages, 
        ),
        
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4D58A5).withOpacity(0.06),
                blurRadius: 40,
                offset: const Offset(0, -10),
              )
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.storefront, "SHOP", 0),
                  _buildNavItem(Icons.chat_bubble_outline_rounded, "CHAT", 1), 
                  _buildSellButton(),
                  _buildNavItem(Icons.person_outline, "PROFILE", 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 💡 ปุ่มเมนูทั่วไป (SHOP, CHAT, PROFILE)
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onTap: () {
        if (_currentIndex == index) {
          // ระบบ Double Tap: กดย้ำหน้าเดิมให้เลื่อนขึ้นบนสุด/รีเฟรช
          if (index == 0) _discoverKey.currentState?.scrollToTopAndRefresh();
          if (index == 1) _chatKey.currentState?.scrollToTopAndRefresh(); 
          if (index == 4) _profileKey.currentState?.scrollToTopAndRefresh();
        } else {
          setState(() => _currentIndex = index);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF4D58A5) : Colors.grey[400]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isSelected ? const Color(0xFF4D58A5) : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 ปุ่มลงขายสินค้า (SELL)
  Widget _buildSellButton() {
    final isSelected = _currentIndex == 2; 
    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onTap: () {
        setState(() => _currentIndex = 2);
        // เมื่อกดมาหน้า Sell ให้เด้งขึ้นบนสุดทันที ไม่ค้างอยู่ที่เดิม
        _sellKey.currentState?.jumpToTop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD1DDFA) : Colors.transparent, 
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle, color: isSelected ? const Color(0xFF35408B) : Colors.grey[400]),
            const SizedBox(height: 2),
            Text(
              "SELL",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF35408B) : Colors.grey[400], 
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}