import 'package:flutter_test/flutter_test.dart';
import 'package:shyam_mobiles/core/i18n.dart';
import 'package:shyam_mobiles/l10n/hindi.dart';

void main() {
  tearDown(() => debugSetLanguage(Language.en));

  test('every Hindi line keeps exactly the placeholders of its English', () {
    Set<String> names(String s) => {for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m[1]!};
    final bad = [
      for (final e in hindi.entries)
        if (e.value.trim().isEmpty || !setEquals(names(e.key), names(e.value))) e.key,
    ];
    expect(bad, isEmpty);
  });

  test('tr: English by default, Hindi when on, English for a line not yet translated, placeholders filled', () {
    expect(tr('Language'), 'Language');
    expect(tr('{n} items', {'n': 3}), '3 items');
    debugSetLanguage(Language.hi);
    expect(tr('Language'), 'भाषा');
    expect(tr('No such line {x}', {'x': 1}), 'No such line 1');
  });
}

bool setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
