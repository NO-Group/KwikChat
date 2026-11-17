import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'theme/kwik_theme.dart';
import 'ui/screens/gate_screen.dart';

class KwikChatApp extends ConsumerWidget {
  const KwikChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'KwikChat',
      debugShowCheckedModeBanner: false,
      theme: KwikTheme.light(),
      darkTheme: KwikTheme.dark(),
      themeMode: themeMode,
      home: const GateScreen(),
    );
  }
}
