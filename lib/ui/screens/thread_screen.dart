import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import '../widgets/common.dart';
import '../widgets/voice_note.dart';
import 'gate_screen.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.orderStatus = OrderStatus.none,
  });

  final String conversationId;
  final String title;
  final OrderStatus orderStatus;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _canSend = false;
  late OrderStatus _orderStatus = widget.orderStatus;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final canSend = _input.text.trim().isNotEmpty;
      if (canSend != _canSend) setState(() => _canSend = canSend);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom({bool animate = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(threadProvider(widget.conversationId).notifier).sendText(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final state = ref.watch(threadProvider(widget.conversationId));
    final myId = ref.watch(profileProvider).valueOrNull?.id;

    ref.listen(threadProvider(widget.conversationId), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        showKwikSnack(context, next.error!, error: true);
        ref.read(threadProvider(widget.conversationId).notifier).clearError();
      }
      final grew = (next.messages.length) > (previous?.messages.length ?? 0);
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
      }
    });

    return Scaffold(
      backgroundColor: kc.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(color: kc.text, fontSize: 15.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
            ),
            if (_orderStatus != OrderStatus.none)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: KwikPill(
                  label: orderStatusLabel(_orderStatus),
                  color: _orderStatus == OrderStatus.paid ? kc.accent : kc.info,
                  filled: true,
                  icon: Icons.receipt_long,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat options',
            icon: Icon(Icons.more_vert, color: kc.muted, size: 20),
            onPressed: () => _openOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.offline) const OfflineBanner(),
          Expanded(
            child: state.loading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.waving_hand_outlined,
                        title: 'Start the gist',
                        message: 'Send a message, or hold the mic to record a voice note.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) {
                          final message = state.messages[i];
                          final isMine = message.senderId == myId;
                          return _MessageRow(message: message, isMine: isMine);
                        },
                      ),
          ),
          _Composer(
            controller: _input,
            canSend: _canSend,
            onSend: _send,
            onVoice: (bytes, durationMs, extension, contentType) async {
              await ref.read(threadProvider(widget.conversationId).notifier).sendVoice(
                    bytes: bytes,
                    durationMs: durationMs,
                    extension: extension,
                    contentType: contentType,
                  );
              WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animate: true));
            },
          ),
        ],
      ),
    );
  }

  void _openOptions(BuildContext context) {
    final kc = context.kc;
    final isVendor = ref.read(profileProvider).valueOrNull?.isVendor ?? false;

    showKwikSheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isVendor)
              ListTile(
                leading: Icon(Icons.receipt_long, color: kc.accent, size: 20),
                title: Text('Order status', style: TextStyle(color: kc.text, fontSize: 14)),
                subtitle: Text(
                  _orderStatus == OrderStatus.none ? 'Not set' : orderStatusLabel(_orderStatus),
                  style: TextStyle(color: kc.muted, fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickOrderStatus(context);
                },
              ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: kc.muted, size: 20),
              title: Text('Mute this chat', style: TextStyle(color: kc.text, fontSize: 14)),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(apiProvider).setMuted(widget.conversationId, true);
                  if (mounted) showKwikSnack(context, 'Chat muted');
                } catch (_) {
                  if (mounted) showKwikSnack(context, 'Could not mute this chat', error: true);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: kc.muted, size: 20),
              title: Text('Report this chat', style: TextStyle(color: kc.text, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                _submitReport(block: false);
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: kc.danger, size: 20),
              title: Text('Block and report', style: TextStyle(color: kc.danger, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                _submitReport(block: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Vendors move an order along without leaving the chat — the whole point of
  /// order tags is that the thread stays the source of truth.
  Future<void> _pickOrderStatus(BuildContext context) async {
    final kc = context.kc;
    await showKwikSheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order status', style: TextStyle(color: kc.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Only you see this as the vendor. Your customer sees it too once set.',
              style: TextStyle(color: kc.muted, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            for (final status in OrderStatus.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  status == OrderStatus.none ? 'Clear status' : orderStatusLabel(status),
                  style: TextStyle(
                    color: status == OrderStatus.none ? kc.muted : kc.text,
                    fontSize: 14,
                  ),
                ),
                trailing: _orderStatus == status ? Icon(Icons.check, color: kc.accent, size: 18) : null,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  try {
                    await ref.read(apiProvider).setOrderStatus(widget.conversationId, status);
                    if (!mounted) return;
                    setState(() => _orderStatus = status);
                    navigator.pop();
                    showKwikSnack(
                      context,
                      status == OrderStatus.none ? 'Order status cleared' : 'Marked as ${orderStatusLabel(status)}',
                    );
                    ref.invalidate(chatListProvider);
                  } on KwikError catch (e) {
                    navigator.pop();
                    if (mounted) showKwikSnack(context, e.message, error: true);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport({required bool block}) async {
    final api = ref.read(apiProvider);
    final handle = widget.title.replaceFirst('@', '').trim();
    try {
      await api.report(
        subjectType: 'conversation',
        subjectId: widget.conversationId,
        reason: block ? 'blocked_and_reported' : 'reported',
      );
      if (block && handle.isNotEmpty) {
        await api.blockByUsername(handle);
      }
      ref.invalidate(chatListProvider);
      if (!mounted) return;
      if (block) {
        showKwikSnack(context, '@$handle blocked and reported.');
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      } else {
        showKwikSnack(context, 'Report sent. Our team reviews these within 24 hours.');
      }
    } on KwikError catch (e) {
      if (mounted) showKwikSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showKwikSnack(context, 'Could not send that. Try again.', error: true);
    }
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final bubbleColor = isMine ? kc.accent : kc.surface;
    final textColor = isMine ? kc.accentOn : kc.text;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 10, 11, 7),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(KwikRadius.bubble),
            topRight: const Radius.circular(KwikRadius.bubble),
            bottomLeft: Radius.circular(isMine ? KwikRadius.bubble : KwikRadius.bubbleTail),
            bottomRight: Radius.circular(isMine ? KwikRadius.bubbleTail : KwikRadius.bubble),
          ),
          border: isMine ? null : Border.all(color: kc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.kind == MessageKind.voice)
              VoiceNoteBubble(
                message: message,
                isMine: isMine,
                accentColor: isMine ? kc.accentOn : kc.accent,
                textColor: textColor,
              )
            else
              Text(
                message.body,
                style: TextStyle(color: textColor, fontSize: 14.5, height: 1.35),
              ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clock(message.createdAt),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.55),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 3),
                  Icon(
                    message.sendState == SendState.failed
                        ? Icons.error_outline
                        : message.sendState == SendState.pending
                            ? Icons.schedule
                            : Icons.done_all,
                    size: 11.5,
                    color: message.sendState == SendState.failed
                        ? kc.danger
                        : textColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _clock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.onVoice,
  });

  final TextEditingController controller;
  final bool canSend;
  final Future<void> Function() onSend;
  final Future<void> Function(Uint8List bytes, int durationMs, String extension, String contentType) onVoice;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      decoration: BoxDecoration(
        color: kc.surface,
        border: Border(top: BorderSide(color: kc.border)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom * 0.2),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: kc.text, fontSize: 14.5),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            if (canSend)
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kc.accent, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_upward_rounded, color: kc.accentOn, size: 22),
                ),
              )
            else
              VoiceRecordButton(onRecorded: onVoice),
          ],
        ),
      ),
    );
  }
}
