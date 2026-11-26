import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/errors.dart';
import '../../../core/format.dart';
import '../../../core/i18n.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../data/addresses.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  static const _fake = Address(
    name: 'Placeholder name',
    phone: '+919999999999',
    line1: 'House and street line',
    city: 'City name',
    state: 'State',
    pincode: '000000',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final count = addresses.value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Addresses'))),
      floatingActionButton: count == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => count >= 10 // DB trigger limit
                  ? showMessage(context, tr('You can save up to 10 addresses. Delete one to add another.'))
                  : context.push('/account/addresses/new'),
              icon: const Icon(PhosphorIconsRegular.plus),
              label: Text(tr('Add address')),
            ),
      body: AsyncBody(
        value: addresses,
        onRetry: () => ref.invalidate(addressesProvider),
        loading: Skeletonizer(child: _List(addresses: List.filled(3, _fake))),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: PhosphorIconsRegular.mapPin,
                tone: Worlds.search,
                title: tr('No saved addresses'),
                message: tr('Add one now and checkout gets quicker.'),
                action: FilledButton.icon(
                  onPressed: () => context.push('/account/addresses/new'),
                  icon: const Icon(PhosphorIconsRegular.plus),
                  label: Text(tr('Add address')),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(addressesProvider.future),
                child: _List(addresses: list),
              ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.addresses});

  final List<Address> addresses;

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Room for the FAB and the gesture bar.
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 96 + MediaQuery.paddingOf(context).bottom),
        itemCount: addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.md),
        itemBuilder: (_, i) => _AddressCard(address: addresses[i]),
      );
}

enum _Action { edit, makeDefault, delete }

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address});

  final Address address;

  Future<void> _run(BuildContext context, WidgetRef ref, _Action action) async {
    final notifier = ref.read(addressesProvider.notifier);
    try {
      switch (action) {
        case _Action.edit:
          await context.push('/account/addresses/${address.id}');
        case _Action.makeDefault:
          await notifier.setDefault(address.id!);
          if (context.mounted) showMessage(context, tr('Default address updated.'));
        case _Action.delete:
          final ok = await confirmChoice(
            context,
            title: tr('Delete this address?'),
            message: address.oneLine,
            action: tr('Delete'),
            keep: tr('Keep address'),
            destructive: true,
          );
          if (!ok) return;
          await notifier.delete(address.id!);
          if (context.mounted) showMessage(context, tr('Address deleted.'));
      }
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: () => _run(context, ref, _Action.edit),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.xs, Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.xs,
                  children: [
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(address.name, style: t.titleSmall),
                        Tag(tr(address.label.displayName)),
                        if (address.isDefault) Tag(tr('Default'), tone: TagTone.ok),
                      ],
                    ),
                    Text(address.oneLine, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                    Text(displayPhone(address.phone), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: tr('Address options'),
                icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
                onSelected: (a) => _run(context, ref, a),
                itemBuilder: (_) => [
                  PopupMenuItem(value: _Action.edit, child: Text(tr('Edit'))),
                  if (!address.isDefault)
                    PopupMenuItem(value: _Action.makeDefault, child: Text(tr('Set as default'))),
                  PopupMenuItem(value: _Action.delete, child: Text(tr('Delete'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
