import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../data/repairs_repository.dart';

import '../../../core/errors.dart';
import '../../../core/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../admin/widgets/admin_widgets.dart' show CancelButton;
import '../../feedback/widgets/feedback_widgets.dart';
import '../data/repairs.dart';
import '../widgets/repair_widgets.dart';
import '../../../core/i18n.dart';

const _steps = [
  RepairStatus.requested,
  RepairStatus.confirmed,
  RepairStatus.inProgress,
  RepairStatus.ready,
  RepairStatus.completed,
];

/// What happens next, in the customer's words, for the step they're on (the quote decides most of it).
String repairStepCopy(RepairBooking b) => switch (b.status) {
      _ when b.awaitingApproval => tr('Check the price below. Work starts only after you approve it.'),
      _ when b.quoteDeclined => b.canCancel
          ? tr('You declined the price. We’ll call you with other options, or you can cancel the booking.')
          : tr('You declined the new price. We’ll call you about your phone.'),
      RepairStatus.requested => tr('We’ll call to confirm your slot.'),
      RepairStatus.confirmed => b.quoteStatus == RepairQuoteStatus.approved
          ? tr('Price approved. We’ll start the repair soon.')
          : tr('Bring your phone in at your slot. We’ll check it and send you the price here.'),
      RepairStatus.inProgress => tr('Our technician is on it.'),
      RepairStatus.ready => tr('Pick it up from the shop.'),
      RepairStatus.completed => tr('All done. Thanks for coming in.'),
      RepairStatus.cancelled => tr('This booking is cancelled.'),
    };

class RepairDetailScreen extends ConsumerStatefulWidget {
  const RepairDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<RepairDetailScreen> createState() => _RepairDetailScreenState();
}

class _RepairDetailScreenState extends ConsumerState<RepairDetailScreen> {
  bool _busy = false;

  /// One action at a time, its dialog included, so a double tap can't open two or write twice.
  Future<void> _once(Future<void> Function() flow) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await flow();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs [write], says [done], and reloads the booking and the list either way (a refusal means it changed).
  Future<void> _write(String done, Future<void> Function(RepairsRepository repo) write) async {
    // The container outlives this screen: the lists still refresh if the customer goes back mid-call.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await write(container.read(repairsRepositoryProvider));
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      container
        ..invalidate(repairProvider(widget.bookingId))
        ..invalidate(myRepairsProvider);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmChoice(
      context,
      title: tr('Cancel this booking?'),
      message: tr('Your slot will be released. You can book again any time.'),
      action: tr('Cancel booking'),
      keep: tr('Keep booking'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _write(tr('Booking cancelled'), (repo) => repo.cancel(widget.bookingId));
  }

  Future<void> _approve(RepairBooking b) async {
    final quote = formatInr(b.quotePaise!);
    final ok = await confirmChoice(
      context,
      title: tr('Approve {q}?', {'q': quote}),
      message: tr('We’ll go ahead with the repair at this price. If we find anything else, we’ll ask you again first.'),
      action: tr('Approve'),
      keep: tr('Not now'),
    );
    if (!ok || !mounted) return;
    await _write(tr('Price approved'), (repo) => repo.approveQuote(b));
  }

  Future<void> _decline(RepairBooking b) async {
    final reason = await askReason(
      context,
      title: tr('Decline {q}?', {'q': formatInr(b.quotePaise!)}),
      message: tr('We won’t do the work at this price. We’ll call you with other options.'),
      action: tr('Decline'),
      keep: tr('Keep quote'),
      label: tr('Reason (optional)'),
      optional: true,
      maxLength: 300,
    );
    if (reason == null || !mounted) return;
    await _write(tr('Declined. We’ll call you.'), (repo) => repo.declineQuote(b.id, reason));
  }

  @override
  Widget build(BuildContext context) {
    final provider = repairProvider(widget.bookingId);
    final value = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(value.value == null ? tr('Repair') : tr('Repair {n}', {'n': value.value!.number}))),
      body: AsyncBody<RepairBooking>(
        value: value,
        onRetry: () => ref.invalidate(provider),
        loading: Skeletonizer(child: _Body(booking: skeletonBookings.first, busy: true)),
        data: (b) => RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: _Body(
            booking: b,
            busy: _busy,
            onCancel: () => _once(_cancel),
            onApprove: () => _once(() => _approve(b)),
            onDecline: () => _once(() => _decline(b)),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking, required this.busy, this.onCancel, this.onApprove, this.onDecline});

  final RepairBooking booking;
  final bool busy;
  final VoidCallback? onCancel;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final b = booking;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl + MediaQuery.paddingOf(context).bottom),
      children: [
        RepairStatusHero(booking: b),
        if (b.quotePaise != null) ...[
          const SizedBox(height: Space.md),
          _QuoteCard(booking: b, busy: busy, onApprove: onApprove, onDecline: onDecline),
        ],
        if (b.status != RepairStatus.cancelled) ...[
          const SizedBox(height: Space.lg),
          RepairTimeline(booking: b),
        ],
        if (b.status == RepairStatus.completed) ...[
          const SizedBox(height: Space.md),
          RateCard(title: tr('How was your repair?'), repairId: b.id),
        ],
        ListSection(tr('Details')),
        Card(
          child: Column(
            children: [
              InfoRow(tr('Phone'), '${b.deviceBrand} ${b.deviceModel}'),
              InfoRow(tr('Issue'), tr(b.issue.label)),
              if (b.description.isNotEmpty) InfoRow(tr('Notes'), b.description),
              InfoRow(tr('Slot'), '${repairWhen(b)} (${tr(b.slot.hours)})'),
              InfoRow(tr('Contact'), displayPhone(b.contactPhone)),
              if (b.quotePaise == null) InfoRow(tr('Quote'), tr('After inspection')),
            ],
          ),
        ),
        if (b.events.isNotEmpty) ...[
          ListSection(tr('Updates')),
          RepairHistory(events: b.events),
        ],
        const SizedBox(height: Space.lg),
        StoreContactButtons(message: 'Hi, about repair ${b.number}'),
        if (b.canCancel) ...[
          const SizedBox(height: Space.sm),
          CancelButton(label: tr('Cancel booking'), onPressed: busy ? null : onCancel),
        ],
        const SizedBox(height: Space.sm),
        Text(
          tr('Booked {d}', {'d': formatDateTime(b.createdAt)}),
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The quote and, while it waits for the customer, Decline and Approve.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.booking, required this.busy, this.onApprove, this.onDecline});

  final RepairBooking booking;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final b = booking;
    final date = b.quoteDecidedAt == null ? null : formatDate(b.quoteDecidedAt!);
    final line = switch (b.quoteStatus) {
      _ when b.awaitingApproval => tr('Work starts only after you approve this price.'),
      RepairQuoteStatus.approved => date == null ? tr('Price approved.') : tr('Price approved on {d}.', {'d': date}),
      RepairQuoteStatus.declined => date == null ? tr('You declined this price.') : tr('You declined this price on {d}.', {'d': date}),
      _ => tr('This price wasn’t approved.'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Quote'), style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
            Text(
              formatInr(b.quotePaise!),
              style: t.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(line, style: t.bodySmall),
            if (b.awaitingApproval) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: busy ? null : onDecline, child: Text(tr('Decline'))),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: FilledButton(onPressed: busy ? null : onApprove, child: Text(tr('Approve'))),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status card in its status tone with a serif headline (mockup 6 `.status-hero`). Shared with the admin detail.
class RepairStatusHero extends StatelessWidget {
  const RepairStatusHero({super.key, required this.booking});

  final RepairBooking booking;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // the same tone as the status tag: one table for every status
    final (bg, fg) = toneColors(booking.awaitingApproval ? TagTone.deal : repairTone(booking.status));
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.hero)),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.number,
              style: t.labelSmall?.copyWith(color: fg, letterSpacing: 1),
            ),
            const SizedBox(height: Space.xs),
            Semantics(
              header: true,
              child: Text(tr(booking.status.label), style: t.displaySmall?.copyWith(color: fg)),
            ),
            const SizedBox(height: Space.xs),
            Text(
              '${repairWhen(booking)} · ${tr(booking.slot.hours)}',
              style: t.bodySmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Requested → Confirmed → In repair → Ready → Completed (mockup 6 `.tl`), each done step with when it happened
/// (from repair_events) and, under the current one, what happens next ([hint]; staff turn it off).
class RepairTimeline extends StatelessWidget {
  const RepairTimeline({super.key, required this.booking, this.hint = true});

  final RepairBooking booking;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final current = _steps.indexOf(booking.status);
    DateTime? reached(RepairStatus s) =>
        booking.events.where((e) => e.status == s && e.quoteStatus == null).firstOrNull?.createdAt;
    return Column(
      children: [
        for (final (i, s) in _steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: i <= current ? c.secondary : c.surfaceContainer,
                          shape: BoxShape.circle,
                          border: i <= current ? null : Border.all(color: c.outlineVariant, width: 2),
                        ),
                        child: SizedBox.square(
                          dimension: 28,
                          child: i <= current
                              ? Icon(PhosphorIconsBold.check, size: 15, color: c.onSecondary)
                              : null,
                        ),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(width: 2, color: i < current ? c.secondary : c.outlineVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: Space.lg),
                    child: Semantics(
                      label: '${tr(s.label)}, ${tr(i <= current ? 'done' : 'not yet')}',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(s.label),
                            style: t.titleSmall?.copyWith(color: i <= current ? c.onSurface : c.onSurfaceVariant),
                          ),
                          if (i <= current && reached(s) != null)
                            Text(formatDateTime(reached(s)!), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                          if (hint && i == current)
                            Text(repairStepCopy(booking), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Every timeline entry, newest first: steps, quotes and their answers, notes. Shared with the admin detail.
class RepairHistory extends StatelessWidget {
  const RepairHistory({super.key, required this.events});

  final List<RepairEvent> events; // oldest first

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = events.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(PhosphorIconsFill.circle, size: 8, color: c.secondary),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(repairEventTitle(events[i], i == 0 ? null : events[i - 1]), style: t.titleSmall),
                      if (events[i].note != null) Text(events[i].note!, style: t.bodySmall),
                      Text(formatDateTime(events[i].createdAt), style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
