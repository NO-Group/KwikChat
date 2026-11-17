import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';

final _handlePattern = RegExp(r'^[a-z0-9_]{3,20}$');

class ClaimUsernameScreen extends ConsumerStatefulWidget {
  const ClaimUsernameScreen({super.key});

  @override
  ConsumerState<ClaimUsernameScreen> createState() => _ClaimUsernameScreenState();
}

class _ClaimUsernameScreenState extends ConsumerState<ClaimUsernameScreen> {
  final _handle = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handle.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _handle.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _cleanHandle => _handle.text.trim().toLowerCase();

  bool get _valid => _handlePattern.hasMatch(_cleanHandle) && _name.text.trim().length >= 2;

  Future<void> _claim() async {
    if (!_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).claimUsername(
            username: _cleanHandle,
            displayName: _name.text.trim(),
          );
      ref.invalidate(profileProvider);
    } on KwikError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not claim that handle. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim your handle'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(apiProvider).signOut();
              ref.invalidate(profileProvider);
            },
            child: Text('Sign out', style: TextStyle(color: kc.muted, fontSize: 12.5)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: context.pagePad, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick the name people will know you by.',
                style: TextStyle(color: kc.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6),
              ),
              const SizedBox(height: 8),
              Text(
                'This is how people find and message you. It is not your phone number.',
                style: TextStyle(color: kc.muted, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _handle,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: TextStyle(
                  color: kc.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle: TextStyle(color: kc.accent, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                  hintText: 'yourname',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _cleanHandle.isEmpty
                    ? '3–20 characters · letters, numbers, underscore'
                    : _handlePattern.hasMatch(_cleanHandle)
                        ? '@$_cleanHandle is available to claim'
                        : 'Too short or has invalid characters',
                style: TextStyle(
                  color: _cleanHandle.isEmpty
                      ? kc.muted
                      : _handlePattern.hasMatch(_cleanHandle)
                          ? kc.accent
                          : kc.danger,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: kc.text, fontSize: 15),
                decoration: const InputDecoration(hintText: 'Display name (e.g. Amina K.)'),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: kc.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_error!, style: TextStyle(color: kc.danger, fontSize: 12.5))),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (!_valid || _busy) ? null : _claim,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                      )
                    : const Text('Claim handle'),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'You get 50 Cowries free when you join.',
                  style: TextStyle(color: kc.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
