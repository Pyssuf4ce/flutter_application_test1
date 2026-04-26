import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    var changed = false;

    // 1. Remove import
    if (content.contains("import 'package:google_fonts/google_fonts.dart';")) {
      content = content.replaceAll("import 'package:google_fonts/google_fonts.dart';", "// import 'package:google_fonts/google_fonts.dart';");
      changed = true;
    }

    // 2. Replace complex GoogleFonts.manrope(...) with nested TextStyle
    // Pattern: GoogleFonts.manrope(textStyle: TextStyle(fontFamilyFallback: [GoogleFonts.notoSansThai().fontFamily ?? 'Noto Sans Thai']), ...
    final complexRegex = RegExp(r"GoogleFonts\.\w+\(textStyle: TextStyle\(fontFamilyFallback: \[GoogleFonts\..*?\.fontFamily \?\? '.*?'\]\),?\s*");
    if (complexRegex.hasMatch(content)) {
      content = content.replaceAllMapped(complexRegex, (match) {
        // We want to replace it with TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], ...
        // Determine the font family from the match
        String family = 'Manrope';
        if (match.group(0)!.contains('prompt')) family = 'Prompt';
        
        return "TextStyle(fontFamily: '$family', fontFamilyFallback: ['Noto Sans Thai'], ";
      });
      changed = true;
    }

    // 3. Replace simple GoogleFonts.manrope(...)
    final simpleRegex = RegExp(r"GoogleFonts\.(manrope|prompt|notoSansThai)\(");
    if (simpleRegex.hasMatch(content)) {
      content = content.replaceAllMapped(simpleRegex, (match) {
        String family = 'Manrope';
        if (match.group(1) == 'prompt') family = 'Prompt';
        if (match.group(1) == 'notoSansThai') family = 'Noto Sans Thai';
        return "TextStyle(fontFamily: '$family', fontFamilyFallback: ['Noto Sans Thai'], ";
      });
      changed = true;
    }
    
    // 4. Fix double TextStyle if it happened: TextStyle(fontFamily: '...', TextStyle(...)
    content = content.replaceAll("TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], TextStyle(", "TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], ");
    content = content.replaceAll("TextStyle(fontFamily: 'Prompt', fontFamilyFallback: ['Noto Sans Thai'], TextStyle(", "TextStyle(fontFamily: 'Prompt', fontFamilyFallback: ['Noto Sans Thai'], ");

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated: ${file.path}');
    }
  }
}
