import 'dart:ui';
// // import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'page/splash_screen_page.dart';
import 'models/message_model.dart';

Future<void> main() async {
  // 1. เตรียมความพร้อมของ Flutter Engine
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);

  // 2. เริ่มการทำงานของ Hive (ระบบ Local Database สำหรับเล่น Offline)
  await Hive.initFlutter();

  // 3. จดทะเบียน Adapter เพื่อให้ Hive รู้จักโครงสร้างข้อมูล LocalMessage
  Hive.registerAdapter(LocalMessageAdapter());

  // 4. เปิดกล่องสำหรับเก็บข้อความแชทไว้ในเครื่อง
  await Hive.openBox<LocalMessage>('messages');

  // 5. เชื่อมต่อกับ Supabase หลังบ้านของคุณ
  await Supabase.initialize(
    url: 'https://rcgweqiqhycnobppmass.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjZ3dlcWlxaHljbm9icHBtYXNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3MDI5NDQsImV4cCI6MjA5MTI3ODk0NH0.qGeIgwL7JV8qraE2LCsw46zZnIK7G6x99FNVZABg1Es',
  );

  // 6. 🔤 Local Fonts are handled by pubspec.yaml and ThemeData

  runApp(const VaultApp());
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAULT Marketplace',
      debugShowCheckedModeBanner: false,

      // ✅ ระบบ Scroll ที่ทำให้ลากเมาส์เลื่อนหน้าจอได้ (สำคัญมากสำหรับ Web/Desktop)
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),

      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35408B),
          primary: const Color(0xFF4D58A5),
          surface: const Color(0xFFF8F9FA),
        ),
        // ✅ ใช้ Local Fonts
        fontFamily: 'Prompt',
        fontFamilyFallback: const ['Noto Sans Thai', 'sans-serif'],
      ),

      // 💡 ตั้งหน้าแรกให้เป็น SplashScreen
      home: const SplashScreenPage(),
    );
  }
}
