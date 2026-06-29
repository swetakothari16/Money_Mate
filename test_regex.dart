void main() {
  final RegExp datePattern2 = RegExp(
    r'\b(\d{1,2})[\s\-./]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*[\s\-./,]+(\d{2,4})\b',
    caseSensitive: false,
  );
  
  List<String> tests = [
    '05 Mar, 2026',
    '20 Apr, 2026',
    '18 May, 2026',
    '05 Mar 2026',
  ];
  
  for (var test in tests) {
    print('"$test" -> ${datePattern2.hasMatch(test)} (matches: ${datePattern2.firstMatch(test)?.group(0)})');
  }
}
