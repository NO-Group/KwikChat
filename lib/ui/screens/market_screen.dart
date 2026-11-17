import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import '../widgets/common.dart';
import 'gate_screen.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final profile = ref.watch(profileProvider).valueOrNull;
    final dataSaver = ref.watch(dataSaverProvider);
    final isDark = ref.watch(themeModeProvider) != ThemeMode.light;

    return Scaffold(
      backgroundColor: kc.bg,
      appBar: AppBar(
        title: Text('Market & Wallet',
            style: TextStyle(color: kc.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 26),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WalletCard(profile: profile),
          ),
          const SectionLabel('Cowrie bundles'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                for (final bundle in kCowrieBundles) _BundleCard(bundle: bundle),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: kc.surface2,
                borderRadius: BorderRadius.circular(KwikRadius.control),
                border: Border.all(color: kc.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: kc.info),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Checkout is intentionally not live yet. Cowries are in-app credit, so iOS and Android both require '
                      'StoreKit / Play Billing — shipping a Paystack button inside the app gets the build rejected. '
                      'The wallet, ledger and webhook are already built; only the store-compliant purchase sheet is pending.',
                      style: TextStyle(color: kc.muted, fontSize: 11.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionLabel('Settings'),
          _SettingTile(
            icon: Icons.data_saver_on,
            title: 'Data Saver',
            subtitle: 'Compress media before upload, smaller images in feeds',
            trailing: Switch(
              value: dataSaver,
              onChanged: (v) => ref.read(dataSaverProvider.notifier).toggle(v),
            ),
          ),
          _SettingTile(
            icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            title: isDark ? 'Dark theme' : 'Daylight theme',
            subtitle: 'Tungsten Graphene is the default',
            trailing: Switch(
              value: isDark,
              onChanged: (v) => ref.read(themeModeProvider.notifier).toggle(!v),
            ),
          ),
          _SettingTile(
            icon: Icons.verified_user_outlined,
            title: 'Vendor verification',
            subtitle: 'NIN / CAC checks arrive with the vendor tools in v0.2',
            trailing: Icon(Icons.lock_outline, size: 15, color: kc.muted),
          ),
          _SettingTile(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: profile?.handle ?? '',
            onTap: () async {
              await ref.read(apiProvider).signOut();
              await ref.read(cacheProvider).wipe();
              ref.invalidate(profileProvider);
            },
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'KwikChat v0.1 · built for Nigerian networks',
              style: TextStyle(color: kc.muted, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kc.accent, kc.accent.withValues(alpha: 0.72)],
        ),
        borderRadius: BorderRadius.circular(KwikRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spa_outlined, color: kc.accentOn, size: 16),
              const SizedBox(width: 6),
              Text('COWRIES',
                  style: TextStyle(
                      color: kc.accentOn.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4)),
              const Spacer(),
              if (profile != null)
                Text(profile!.handle,
                    style: TextStyle(color: kc.accentOn.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile == null ? '—' : '${profile!.cowriesBalance}',
            style: TextStyle(
                color: kc.accentOn, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1.0),
          ),
          const SizedBox(height: 6),
          Text(
            'Boost posts, spray creators, transcribe voice notes.',
            style: TextStyle(color: kc.accentOn.withValues(alpha: 0.78), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle});
  final CowrieBundle bundle;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return GestureDetector(
      onTap: () => showKwikSheet<void>(
        context,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${bundle.name} · ${bundle.label} Cowries',
                  style: TextStyle(color: context.kc.text, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Top-up needs a store-compliant purchase sheet on iOS and Android. '
                'Paystack on the web build works today once PAYSTACK_SECRET_KEY is set on the '
                'paystack-webhook function.',
                style: TextStyle(color: context.kc.muted, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: kc.surface,
          borderRadius: BorderRadius.circular(KwikRadius.card),
          border: Border.all(color: kc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(bundle.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kc.muted, fontSize: 11, fontWeight: FontWeight.w600)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(bundle.label,
                        style: TextStyle(
                            color: kc.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('cowries', style: TextStyle(color: kc.muted, fontSize: 10)),
                    ),
                  ],
                ),
                if (bundle.bonus > 0)
                  Text('+${bundle.bonus} bonus',
                      style: TextStyle(color: kc.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(bundle.naira, style: TextStyle(color: kc.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 19, color: kc.muted),
      title: Text(title, style: TextStyle(color: kc.text, fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: kc.muted, fontSize: 11.5, fontFamily: 'monospace')),
      trailing: trailing,
    );
  }
}
