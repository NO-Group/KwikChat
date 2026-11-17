import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import 'app_shell.dart';
import 'claim_username_screen.dart';
import 'onboarding_screen.dart';

/// Decides what the user sees before any tab renders:
/// unconfigured build → setup card, no session → onboarding,
/// session without a handle → @username claim, otherwise → the app.
class GateScreen extends ConsumerWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isConfigured) return const ConfigMissingScreen();

    final profile = ref.watch(profileProvider);
    return profile.when(
      loading: () => const SplashView(),
      error: (error, _) => Scaffold(
        body: SafeArea(
          child: ErrorView(
            message: error is Exception ? 'We could not reach KwikChat.' : '$error',
            onRetry: () => ref.invalidate(profileProvider),
          ),
        ),
      ),
      data: (p) {
        if (p == null) return const OnboardingScreen();
        if (p.username.isEmpty) return const ClaimUsernameScreen();
        return const AppShell();
      },
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/kwikchat_logo.png', width: 96, height: 96),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: kc.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the binary was built without --dart-define values.
/// Better than a white screen: it tells you exactly what to pass.
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/kwikchat_logo.png', width: 72, height: 72),
                ),
                const SizedBox(height: 20),
                Text('Backend not configured', style: TextStyle(color: kc.text, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'This build has no Supabase URL or anon key, so it cannot sign anyone in.',
                  style: TextStyle(color: kc.muted, fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kc.codeBg,
                    borderRadius: BorderRadius.circular(KwikRadius.control),
                    border: Border.all(color: kc.border),
                  ),
                  child: Text(
                    'flutter run \\\n'
                    '  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\\n'
                    '  --dart-define=SUPABASE_ANON_KEY=eyJ...',
                    style: TextStyle(
                      color: kc.text,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'In CI, set the SUPABASE_URL and SUPABASE_ANON_KEY repository secrets — '
                  'see docs/SETUP.md.',
                  style: TextStyle(color: kc.muted, fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted sheet used across the app for quick actions.
Future<T?> showKwikSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final kc = context.kc;
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: kc.surface,
              border: Border(top: BorderSide(color: kc.border)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
