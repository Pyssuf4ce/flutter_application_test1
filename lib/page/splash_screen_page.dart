import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'login_page.dart';
import 'main_screen.dart';

class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 1. ตั้งค่า Animation Controller (ความยาว 2 วินาที)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 2. แอนิเมชันขยายขนาด (Zoom in) แบบนุ่มนวล
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // 3. แอนิเมชันค่อยๆ สว่างขึ้น (Fade in)
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeIn),
      ),
    );

    // 4. แอนิเมชันเลื่อนขึ้นเบาๆ (Slide up)
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    // เริ่มเล่นแอนิเมชัน
    _controller.forward();

    // เตรียมเช็คสถานะการล็อกอินและเปลี่ยนหน้า
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // 1. รอให้แอนิเมชันตอนเปิด (Entrance) เล่นเกือบจบ
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    // 2. เริ่มเล่นแอนิเมชันปิด (Exit) ให้ไอคอนและข้อความค่อยๆ หดและจางหายไป
    _controller.animateBack(
      0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );

    // รอให้แอนิเมชันหดตัวเล่นจบ
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    // 3. เปลี่ยนหน้าด้วย Fade + Scale Zoom In Effect (ดู Premium)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (context, animation, secondaryAnimation) {
          return session != null ? const MainScreen() : const LoginPage();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // หน้าใหม่จะค่อยๆ สว่างขึ้นและขยายตัวนิดๆ (Scale 0.96 -> 1.0)
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // พื้นหลังสีเรียบหรูของแบรนด์
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _opacityAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // กล่องโลโก้ที่มีเงา (Shadow) แบบพรีเมียม
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF35408B), Color(0xFF4D58A5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF35408B,
                              ).withValues(alpha: 0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons
                                .dashboard_rounded, // ไอคอนชั่วคราว สามารถเปลี่ยนเป็นโลโก้จริงได้
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ชื่อแบรนด์พร้อมฟอนต์ที่สวยงาม
                      Text(
                        'VAULT',
                        style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], 
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 12,
                          color: Color(0xFF35408B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // สโลแกนหรือคำอธิบาย
                      Text(
                        'MARKETPLACE',
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: const Color(0xFF4D58A5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
