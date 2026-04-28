import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class IconGeneratorPage extends StatefulWidget {
  const IconGeneratorPage({super.key});

  @override
  State<IconGeneratorPage> createState() => _IconGeneratorPageState();
}

class _IconGeneratorPageState extends State<IconGeneratorPage> {
  // 1. สร้างกุญแจ (Key) เพื่อเอาไว้ชี้ว่าเราจะถ่ายรูป Widget ตัวไหน
  final GlobalKey _iconKey = GlobalKey();

  Future<void> _captureAndSaveIcon() async {
    try {
      // 2. ตามหา Widget จาก Key ที่เราผูกไว้
      RenderRepaintBoundary boundary =
          _iconKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // 3. 💡 พระเอกอยู่ตรงนี้: แปลง Widget เป็นรูป!
      // กล่องเรากว้าง 100 ถ้าอยากได้ 1024x1024 ต้องคูณความละเอียด (pixelRatio) ไป 10.24 เท่า!
      ui.Image image = await boundary.toImage(pixelRatio: 10.24);

      // 4. แปลงภาพให้เป็นไฟล์ PNG
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 5. บันทึกไฟล์ลงเครื่อง (มือถือจำลอง)
      final directory = await getApplicationDocumentsDirectory();
      final file = await File(
        '${directory.path}/vault_app_icon_1024.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      print('✅ โคตรเท่! เซฟรูปสำเร็จที่: ${file.path}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เซฟไอคอนแล้ว! ลองดู Path ใน Console นะ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เครื่องผลิต Icon 1024')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💡 เอา RepaintBoundary มาครอบ Widget โลโก้ของมึง แล้วผูก Key ซะ!
            RepaintBoundary(
              key: _iconKey,
              child: Container(
                width: 100, // ขนาดเดิม
                height: 100,
                // ✅ เปลี่ยนเป็นสีโปร่งใส ไม่ต้องมี BoxDecoration อีกแล้ว
                color: Colors.transparent,
                child: const Center(
                  child: Icon(
                    Icons.dashboard_rounded,
                    size: 50, // ขนาดเดิม
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: _captureAndSaveIcon,
              icon: const Icon(Icons.camera_alt),
              label: const Text('กดแชะ! สร้างไฟล์ PNG 1024x1024'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
