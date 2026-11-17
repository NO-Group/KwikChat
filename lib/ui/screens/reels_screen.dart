import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import '../widgets/common.dart';

/// v0.1 renders the feed shell against the real `reel_feed` view.
/// Playback (HLS ladder + Data-Saver rendition) lands in v0.2 — see
/// docs/CORRECTIONS.md for why a client-side toggle alone cannot ship this.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final reels = ref.watch(reelsProvider);
    final dataSaver = ref.watch(reelsDataSaverProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: reels.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e is KwikError ? e.message : 'Could not load Reels.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const _ReelsPlaceholder();
                }
                return PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: list.length,
                  itemBuilder: (context, i) => _ReelCard(reel: list[i], index: i),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  _FeedTab(
                    label: 'For You',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _FeedTab(
                    label: 'Naija',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const Spacer(),
                  DataSaverPill(
                    enabled: dataSaver,
                    onTap: () => ref.read(reelsDataSaverProvider.notifier).toggle(!dataSaver),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(KwikRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReelsPlaceholder extends StatelessWidget {
  const _ReelsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF161A17), Color(0xFF0A0C0B)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Color(0x1FB8F226), shape: BoxShape.circle),
                child: const Icon(Icons.smart_display, color: Color(0xFFB8F226), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reels',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6),
              ),
              const SizedBox(height: 8),
              const Text(
                'The feed shell is live and reading real data. Video playback, the 480p/720p ladder and Data-Saver streaming arrive in v0.2.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.reel, required this.index});
  final Reel reel;
  final int index;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final palette = [
      const [Color(0xFF1B2A18), Color(0xFF0A0C0B)],
      const [Color(0xFF1A1F2A), Color(0xFF0A0C0B)],
      const [Color(0xFF2A1A1A), Color(0xFF0A0C0B)],
    ][index % 3];

    final begin = index.isEven ? Alignment.topLeft : Alignment.topRight;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: begin, end: Alignment.bottomCenter, colors: palette),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KwikAvatar(initials: reel.creatorUsername.isEmpty ? '?' : reel.creatorUsername.substring(0, 1).toUpperCase(), size: 34),
                  const SizedBox(width: 9),
                  Text('@${reel.creatorUsername}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Text('· ${reel.city}', style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 10),
              Text(reel.caption, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (reel.priceNgn != null)
                    GestureDetector(
                      onTap: () => showKwikSnack(context, 'Commerce hooks land with the vendor tools in v0.2.'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: kc.accent,
                          borderRadius: BorderRadius.circular(KwikRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront, size: 14, color: kc.accentOn),
                            const SizedBox(width: 6),
                            Text('Message vendor',
                                style: TextStyle(color: kc.accentOn, fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  _RailAction(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Hype',
                    onTap: () => showKwikSnack(context, 'Hype on Reels ships in v0.2.'),
                  ),
                  const SizedBox(width: 14),
                  _RailAction(
                    icon: Icons.volunteer_activism_outlined,
                    label: 'Spray',
                    onTap: () => showKwikSnack(context, 'Cowrie spraying arrives with the wallet in v0.2.'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
