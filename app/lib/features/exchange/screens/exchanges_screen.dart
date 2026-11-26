import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../data/exchanges.dart';
import '../data/exchange_repository.dart';
import '../widgets/exchange_widgets.dart';
import '../../../core/i18n.dart';

/// "Exchange requests": what the customer sent, and the shop's estimate once it's there (Repairs → /exchanges).
class ExchangesScreen extends ConsumerWidget {
  const ExchangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(tr('Exchange requests'))),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showExchangeSheet(context),
          icon: const Icon(PhosphorIconsRegular.arrowsLeftRight),
          label: Text(tr('New request')),
        ),
        body: AsyncBody<List<ExchangeRequest>>(
          value: ref.watch(myExchangesProvider),
          onRetry: () => ref.invalidate(myExchangesProvider),
          loading: const Center(child: CircularProgressIndicator()),
          data: (all) => all.isEmpty
              ? EmptyState(
                  icon: PhosphorIconsRegular.arrowsLeftRight,
                  title: tr('No exchange requests yet'),
                  message: tr('Tell the shop about your old phone and get an estimate.'),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(myExchangesProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 96),
                    children: [for (final r in all) ExchangeRequestCard(r)],
                  ),
                ),
        ),
      );
}
