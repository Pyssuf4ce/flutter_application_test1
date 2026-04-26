
import 'dart:io';

void main() {
  final dir = Directory('lib');
  dir.listSync(recursive: true).forEach((file) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      
      // ลบส่วนที่ซ้ำซ้อนออก (ใช้รหัสที่ยืดหยุ่นขึ้น)
      // ลบ textStyle: TextStyle(...) ทั้งก้อน
      final regex = RegExp(
        r'textStyle:\s*TextStyle\s*\(\s*fontFamilyFallback:\s*\[\s*GoogleFonts\.notoSansThai\(\)\.fontFamily\s*\?\?\s*[\x27\x22]Noto Sans Thai[\x27\x22]\s*,?\s*\]\s*,?\s*\)\s*,?',
        multiLine: true,
        dotAll: true,
      );
      
      content = content.replaceAll(regex, '');
      
      // ซ่อมแซมวงเล็บและคอมม่าที่อาจจะเกินมา
      content = content.replaceAll(RegExp(r',\s*,'), ',');
      content = content.replaceAll(RegExp(r'\(\s*,'), '(');
      content = content.replaceAll(RegExp(r',\s*\)'), ')');

      file.writeAsStringSync(content);
    }
  });
  print('Deep clean completed!');
}
