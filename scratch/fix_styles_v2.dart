import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    var changed = false;

    // 1. Fix the double TextStyle pattern from previous script
    // TextStyle(fontFamily: '...', fontFamilyFallback: [...], textStyle: TextStyle(
    final doubleTextStyle = RegExp(r"TextStyle\(\s*fontFamily: '.*?',\s*fontFamilyFallback: \[.*? \],\s*textStyle: TextStyle\(");
    if (doubleTextStyle.hasMatch(content)) {
      content = content.replaceAll(doubleTextStyle, "TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Noto Sans Thai'], ");
      changed = true;
    }

    // 2. Fix the nested FontFamily pattern: TextStyle(fontFamily: 'Noto Sans Thai', ...).fontFamily
    final nestedFontFamily = RegExp(r"TextStyle\(fontFamily: 'Noto Sans Thai', fontFamilyFallback: \['Noto Sans Thai'\], \)\.fontFamily \?\? 'Noto Sans Thai'");
    if (nestedFontFamily.hasMatch(content)) {
      content = content.replaceAll(nestedFontFamily, "'Noto Sans Thai'");
      changed = true;
    }

    // 3. Cleanup: fontFamilyFallback: [ 'Noto Sans Thai' ] if it's double wrapped
    content = content.replaceAll("fontFamilyFallback: [ 'Noto Sans Thai' ]", "fontFamilyFallback: ['Noto Sans Thai']");
    content = content.replaceAll("fontFamilyFallback: [['Noto Sans Thai']]", "fontFamilyFallback: ['Noto Sans Thai']");

    if (changed) {
      file.writeAsStringSync(content);
      print('Fixed: ${file.path}');
    }
  }
}
