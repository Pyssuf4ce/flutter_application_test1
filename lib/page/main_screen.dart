import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Import หน้าต่างๆ
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

  final GlobalKey<DiscoverPageState> _discoverKey = GlobalKey<DiscoverPageState>();
  final GlobalKey<ChatListPageState> _chatKey = GlobalKey<ChatListPageState>(); 
  final GlobalKey<PostItemPageState> _sellKey = GlobalKey<PostItemPageState>();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: IndexedStack(
            key: ValueKey<int>(_currentIndex),
            index: _currentIndex,
            children: _pages, 
          ),
        ),
        
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4D58A5).withValues(alpha: 0.06),
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
    );
  }

  // ปุ่มเมนูทั่วไป (SHOP, CHAT, PROFILE) — เพิ่ม haptic + active dot
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onTap: () {
        HapticFeedback.selectionClick();
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: isSelected ? const Color(0xFF4D58A5) : Colors.grey[400]),
            ),
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
            // ── Active tab dot ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 4),
              width: isSelected ? 5 : 0,
              height: isSelected ? 5 : 0,
              decoration: const BoxDecoration(
                color: Color(0xFF4D58A5),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ปุ่มลงขายสินค้า (SELL) — เพิ่ม haptic
  Widget _buildSellButton() {
    final isSelected = _currentIndex == 2; 
    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _currentIndex = 2);
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
              style: GoogleFonts.inter(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), 
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF35408B) : Colors.grey[400], 
                letterSpacing: 0.5,
              ),
            ),
            // ── Active dot for SELL tab ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 4),
              width: isSelected ? 5 : 0,
              height: isSelected ? 5 : 0,
              decoration: const BoxDecoration(
                color: Color(0xFF35408B),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}