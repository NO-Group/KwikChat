import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';

/// Email-code sign-in.
///
/// Deliberately email-first for v0.1: phone OTP costs real money per signup in
/// Nigeria (SMS aggregation) and needs a provider account. Phone OTP is wired
/// behind the same screen in v0.2 — the @username still hides the number.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _focus = FocusNode();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).sendEmailCode(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _busy = false;
      });
      _focus.requestFocus();
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
        _error = 'Could not send the code. Check your connection.';
      });
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).verifyEmailCode(email: _email.text.trim(), code: code);
      // GateScreen reacts to the auth stream and moves on automatically.
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
        _error = 'Could not verify that code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: context.pagePad, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/kwikchat_logo.png', width: 76, height: 76),
              ),
              const SizedBox(height: 26),
              Text(
                _codeSent ? 'Check your mail' : 'No long talk.',
                style: TextStyle(color: kc.text, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.0),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'We sent a 6-digit code to ${_email.text.trim()}. It expires in a few minutes.'
                    : 'Sign in with email. You will pick an @username next — your phone number is never shown to anyone.',
                style: TextStyle(color: kc.muted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (!_codeSent) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  style: TextStyle(color: kc.text, fontSize: 15),
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                  onSubmitted: (_) => _sendCode(),
                ),
              ] else ...[
                TextField(
                  controller: _code,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    color: kc.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(hintText: '••••••'),
                  onSubmitted: (_) => _verify(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: kc.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: kc.danger, fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                      )
                    : Text(_codeSent ? 'Verify code' : 'Send code'),
              ),
              const SizedBox(height: 14),
              if (_codeSent)
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _codeSent = false;
                              _code.clear();
                              _error = null;
                            }),
                    child: const Text('Use a different email'),
                  ),
                ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: kc.surface2,
                  borderRadius: BorderRadius.circular(KwikRadius.control),
                  border: Border.all(color: kc.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 15, color: kc.accent),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'KwikChat never shares your email or phone number in chats, groups or the Market.',
                        style: TextStyle(color: kc.muted, fontSize: 12, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
