import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../i18n.dart';
import '../theme/tokens.dart';

/// Home's switch, beside the search: one tap flips हिंदी / English. Shows the letter of the language it switches to.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(languageProvider) == Language.hi;
    return IconButton(
      tooltip: tr('Change language'),
      onPressed: () => ref.read(languageProvider.notifier).choose(hi ? Language.en : Language.hi),
      icon: Text(hi ? 'A' : 'अ', style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1)),
    );
  }
}

/// "Choose your language": हिंदी or English, from Account and on first open.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // both languages, so it reads whichever the customer knows
          Text('भाषा चुनें · Choose your language', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.md),
          for (final l in Language.values)
            ListTile(
              title: Text(l.label, style: Theme.of(context).textTheme.titleMedium),
              trailing: currentLanguage == l ? const Icon(PhosphorIconsFill.checkCircle) : null,
              onTap: () {
                ref.read(languageProvider.notifier).choose(l);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: Space.sm),
          Text(tr('You can change it any time from Account.'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  ),
);

/// Asks the language once, over [child] (Home), the first time the app opens. Closing the sheet keeps the language
/// shown, so it never asks again.
class AskLanguageOnce extends ConsumerStatefulWidget {
  const AskLanguageOnce({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AskLanguageOnce> createState() => _AskLanguageOnceState();
}

class _AskLanguageOnceState extends ConsumerState<AskLanguageOnce> {
  static bool _asking = false; // Home can mount twice (a deep link back to it): one sheet

  @override
  void initState() {
    super.initState();
    final n = ref.read(languageProvider.notifier);
    if (!askLanguageOnFirstOpen || n.chosen || _asking) return;
    _asking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted) await showLanguageSheet(context, ref);
        if (!n.chosen) await n.choose(currentLanguage); // closed without a pick: keep this one
      } finally {
        _asking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
