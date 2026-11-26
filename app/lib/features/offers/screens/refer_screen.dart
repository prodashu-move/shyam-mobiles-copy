import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/env.dart';
import '../../../core/errors.dart';
import '../../../core/format.dart';
import '../../../core/input.dart';
import '../../../core/links.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../data/offers.dart';
import '../widgets/offer_widgets.dart';
import '../../../core/i18n.dart';

/// The WhatsApp message a customer forwards: the code, what the friend gets, and the link that carries the code into
/// the app (the same text as the Share button). No contact is picked here.
Uri referralShareUri(Referral r, {String host = Env.linkHost}) => Uri.https('wa.me', '/', {
      'text': shareText('I shop for phones at Shyam Mobiles.', link: shareLink(code: r.code, host: host), referral: r),
    });

const _placeholder = Referral(enabled: true, code: 'ABCD1234', friendPaise: 20000, rewardPaise: 20000, minOrderPaise: 199900);

class ReferScreen extends ConsumerWidget {
  const ReferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referral = ref.watch(myReferralProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Refer & earn')), actions: [
        if (referral.value?.enabled ?? false) const ShareButton(what: 'I shop for phones at Shyam Mobiles.'),
      ]),
      body: AsyncBody<Referral>(
        value: referral,
        onRetry: () => ref.invalidate(myReferralProvider),
        loading: const Skeletonizer(child: _Body(referral: _placeholder)),
        data: (r) => r.enabled
            ? RefreshIndicator(
                onRefresh: () => ref.refresh(myReferralProvider.future),
                child: _Body(referral: r, monthlyCap: ref.watch(storeSettingsProvider).value?.referralMonthlyCap),
              )
            : EmptyState(
                icon: PhosphorIconsRegular.gift,
                tone: Worlds.offers,
                title: tr('Refer & earn isn’t running right now'),
                message: tr('Check Offers for today’s coupons and sales.'),
                action: FilledButton(onPressed: () => context.pushReplacement('/offers'), child: Text(tr('See offers'))),
              ),
      ),
    );
  }
}

/// The monthly reward cap, said plainly: past it, a friend still gets their discount but no reward is made.
String _capNote(int cap) => cap <= 0
    ? ''
    : cap == 1
        ? tr(' You can earn up to 1 reward a month. Friends who join after that still get their discount, but no reward is added for you.')
        : tr(' You can earn up to {cap} rewards a month. Friends who join after that still get their discount, but no reward is added for you.', {'cap': cap});

class _Body extends StatelessWidget {
  const _Body({required this.referral, this.monthlyCap});

  final Referral referral;
  final int? monthlyCap; // store_settings.referral_monthly_cap: rewards per IST month, the rest are void

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final r = referral;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.hero),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: heroGradients[0]),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(PhosphorIconsFill.gift, color: BrandColors.gold, size: 32),
                  const SizedBox(height: Space.sm),
                  Semantics(
                    header: true,
                    child: Text(
                      tr('Give {a}, get {b}', {'a': formatInr(r.friendPaise), 'b': formatInr(r.rewardPaise)}),
                      style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    tr('Your friend saves {a}. You get {b} when their order arrives.', {'a': formatInr(r.friendPaise), 'b': formatInr(r.rewardPaise)}),
                    style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ),
        ).enter(context),
        const SizedBox(height: Space.lg),
        Text(tr('Your code'), style: t.titleSmall),
        const SizedBox(height: Space.sm),
        CodeActions(code: r.code),
        const SizedBox(height: Space.md),
        // WhatsApp is this screen's main action: its own green, with ink on it (white fails contrast)
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.whatsapp, foregroundColor: BrandColors.ink),
          onPressed: () => openUri(context, referralShareUri(r)),
          icon: const Icon(PhosphorIconsFill.whatsappLogo, size: IconSizes.md, color: BrandColors.ink),
          label: Text(tr('Share on WhatsApp')),
        ),
        ListSection(tr('How it works')),
        for (final (i, line) in [
          tr('Share your code with a friend.'),
          tr('They get {a} off their first order of {b} or more.', {'a': formatInr(r.friendPaise), 'b': formatInr(r.minOrderPaise)}),
          tr('When that order is delivered, you get a {a} coupon.', {'a': formatInr(r.rewardPaise)}),
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: Worlds.cart.$1, shape: BoxShape.circle),
                  child: SizedBox.square(
                    dimension: 28,
                    child: Center(child: Text('${i + 1}', style: t.labelLarge?.copyWith(color: Worlds.cart.$2, fontWeight: FontWeight.w800))),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text(line, style: t.bodyMedium))),
              ],
            ),
          ),
        const SizedBox(height: Space.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Row(
              children: [
                for (final (n, label) in [(r.joined, tr('Friends joined')), (r.rewarded, tr('Rewards earned'))])
                  Expanded(
                    child: Semantics(
                      container: true,
                      label: '$label: $n',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text('$n', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(label, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          tr('Your coupon is for an order of {min} or more and lasts 90 days. It shows up in Offers & coupons.{note}',
              {'min': formatInr(r.minOrderPaise), 'note': _capNote(monthlyCap ?? 0)}),
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (r.canEnterCode) const _FriendCode(),
      ],
    );
  }
}

/// "Have a friend's code?": shown only until the customer has a referrer or an order.
class _FriendCode extends ConsumerStatefulWidget {
  const _FriendCode();

  @override
  ConsumerState<_FriendCode> createState() => _FriendCodeState();
}

class _FriendCodeState extends ConsumerState<_FriendCode> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_busy) return;
    final invalid = validateCode(_code.text, min: 6, max: 10);
    if (invalid != null) return setState(() => _error = invalid);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final welcome = await applyReferralCode(ref, _code.text.trim());
      if (mounted) showMessage(context, tr('Done. Use {code} for {deal}. It’s in Offers & coupons.', {'code': welcome.code, 'deal': offerHeadline(welcome)}));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.xl),
        Semantics(header: true, child: Text(tr('Have a friend’s code?'), style: t.titleMedium)),
        const SizedBox(height: Space.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                decoration: InputDecoration(labelText: tr('Friend’s code'), errorText: _error, errorMaxLines: 3),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: couponCodeInput,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _apply(),
              ),
            ),
            const SizedBox(width: Space.sm),
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: FilledButton(
                onPressed: _busy ? null : _apply,
                child: _busy ? const ButtonSpinner() : Text(tr('Apply')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
