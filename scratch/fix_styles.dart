import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    var changed = false;

    // Fix: TextStyle(..., textStyle: TextStyle( ... ))
    // This happens when GoogleFonts.manrope(textStyle: TextStyle(...)) was replaced.
    // We want to merge or just flatten it.
    
    // Pattern 1: TextStyle(..., textStyle: TextStyle(
    final nestedPattern = RegExp(r"TextStyle\(fontFamily: '.*?', fontFamilyFallback: \['Noto Sans Thai'\], textStyle: TextStyle\(");
    if (nestedPattern.hasMatch(content)) {
      content = content.replaceAll(nestedPattern, "TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], ");
      changed = true;
    }
    
    // Pattern 2: Sometimes it's just TextStyle(textStyle: TextStyle(...)) if my script was weird
    if (content.contains("textStyle: TextStyle(")) {
      content = content.replaceAll("textStyle: TextStyle(", "");
      // We also need to remove one closing parenthesis at the end of that block.
      // This is harder with regex, let's try a simpler approach.
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Fixed: ${file.path}');
    }
  }
}
