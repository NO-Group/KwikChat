import 'package:flutter/material.dart';

import '../../theme/kwik_theme.dart';

class KwikAvatar extends StatelessWidget {
  const KwikAvatar({super.key, required this.initials, this.size = 46, this.isGroup = false});
  final String initials;
  final double size;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kc.surface2,
        borderRadius: BorderRadius.circular(isGroup ? KwikRadius.control : KwikRadius.pill),
        border: Border.all(color: kc.border),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: kc.accent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class KwikCard extends StatelessWidget {
  const KwikCard({super.key, required this.child, this.padding, this.onTap, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final content = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: BorderRadius.circular(KwikRadius.card),
        border: Border.all(color: borderColor ?? kc.border),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KwikRadius.card),
      child: content,
    );
  }
}

class KwikPill extends StatelessWidget {
  const KwikPill({super.key, required this.label, this.color, this.icon, this.filled = false});
  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final tint = color ?? kc.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? tint.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(KwikRadius.pill),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}

class DataSaverPill extends StatelessWidget {
  const DataSaverPill({super.key, required this.enabled, this.onTap});
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: enabled ? kc.accent : kc.surface2,
          borderRadius: BorderRadius.circular(KwikRadius.pill),
          border: Border.all(color: enabled ? kc.accent : kc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.data_saver_on : Icons.data_saver_off,
              size: 13,
              color: enabled ? kc.accentOn : kc.muted,
            ),
            const SizedBox(width: 5),
            Text(
              enabled ? 'Data Saver' : 'HD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: enabled ? kc.accentOn : kc.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kc.accentDim, shape: BoxShape.circle),
              child: Icon(icon, color: kc.accent, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: kc.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: kc.muted, fontSize: 13, height: 1.4),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: kc.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.message = 'Offline — showing saved messages'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      width: double.infinity,
      color: kc.info.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 13, color: kc.info),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: TextStyle(color: kc.info, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

void showKwikSnack(BuildContext context, String message, {bool error = false}) {
  final kc = context.kc;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? kc.danger : null,
      duration: const Duration(seconds: 3),
    ),
  );
}
