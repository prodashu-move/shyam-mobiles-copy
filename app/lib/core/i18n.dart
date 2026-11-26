import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/hindi.dart';

/// The app's languages: English (the code's own text) and Hindi ([hindi]).
enum Language {
  en('English'),
  hi('हिंदी');

  const Language(this.label);

  final String label; // in its own language, for the switch
}

Language _current = Language.en;

/// The language [tr] speaks now. Set only by [LanguageNotifier] (and tests).
Language get currentLanguage => _current;

/// [en] in the chosen language: the Hindi from [hindi] when Hindi is on and a line exists (else the English), with
/// each `{name}` filled from [args]. The English text is the key, so untranslated text simply stays English.
/// `tr('{n} items', {'n': 3})`
String tr(String en, [Map<String, Object?> args = const {}]) {
  var s = _current == Language.hi ? (hindi[en] ?? en) : en;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

const _key = 'language';

/// The chosen language, kept on the phone. Before any choice: Hindi on a phone set to Hindi, else English.
final languageProvider = NotifierProvider<LanguageNotifier, Language>(LanguageNotifier.new);

class LanguageNotifier extends Notifier<Language> {
  /// Whether the customer has picked a language (the first-open question is asked once).
  bool chosen = false;

  @override
  Language build() => _current;

  /// Reads the saved choice before the first frame (main.dart), so the app never flashes the other language.
  Future<void> load() async {
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {} // no plugin (tests): English
    chosen = saved != null;
    final device = PlatformDispatcher.instance.locale.languageCode == 'hi' ? Language.hi : Language.en;
    _set(Language.values.where((l) => l.name == saved).firstOrNull ?? device);
  }

  Future<void> choose(Language l) async {
    chosen = true;
    _set(l);
    try {
      await (await SharedPreferences.getInstance()).setString(_key, l.name);
    } catch (_) {}
  }

  void _set(Language l) {
    final changed = l != _current;
    _current = l;
    state = l;
    if (!changed) return;
    // tr() is a plain function, so no widget depends on the language: rebuild them all (nothing before runApp)
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }
}

/// Whether Home asks "हिंदी / English?" on first open. Off under `flutter test`, where every screen test would meet it;
/// the prompt's own test turns it on.
bool askLanguageOnFirstOpen = !Platform.environment.containsKey('FLUTTER_TEST');

/// Test only: switch [tr] without the provider.
void debugSetLanguage(Language l) => _current = l;
