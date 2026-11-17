import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import '../widgets/common.dart';
import 'gate_screen.dart';
import 'thread_screen.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final state = ref.watch(chatListProvider);
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: kc.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Text('KwikChat', style: TextStyle(color: kc.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kc.accentDim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('v0.1', style: TextStyle(color: kc.accent, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: Icon(Icons.edit_square, color: kc.muted, size: 21),
            onPressed: () => _startNewChat(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.offline) const OfflineBanner(),
          _YarnRoomsStrip(rooms: rooms),
          Expanded(child: _buildBody(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ChatListState state) {
    if (state.loading && state.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.conversations.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(chatListProvider.notifier).refresh(),
      );
    }
    if (state.conversations.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'No chats yet',
        message: 'Start a conversation with an @username. No phone numbers needed.',
        actionLabel: 'Start a chat',
        onAction: () => _startNewChat(context, ref),
      );
    }
    return RefreshIndicator(
      color: context.kc.accent,
      onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.conversations.length,
        separatorBuilder: (_, __) => Divider(height: 1, indent: 74, color: context.kc.border),
        itemBuilder: (context, i) => _ChatRow(conversation: state.conversations[i]),
      ),
    );
  }

  Future<void> _startNewChat(BuildContext context, WidgetRef ref) async {
    final handle = TextEditingController();
    await showKwikSheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New chat', style: TextStyle(color: context.kc.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Enter the @username of the person you want to reach.',
              style: TextStyle(color: context.kc.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: handle,
              autofocus: true,
              style: TextStyle(color: context.kc.text, fontFamily: 'monospace', fontSize: 15),
              decoration: const InputDecoration(prefixText: '@', hintText: 'username'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                final raw = handle.text.trim().replaceFirst('@', '').toLowerCase();
                if (raw.isEmpty) return;
                final navigator = Navigator.of(context);
                try {
                  final conversationId = await ref.read(chatListProvider.notifier).startWith(raw);
                  navigator.pop();
                  if (conversationId != null && context.mounted) {
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => ThreadScreen(conversationId: conversationId, title: '@$raw'),
                      ),
                    );
                  }
                } on KwikError catch (e) {
                  if (context.mounted) showKwikSnack(context, e.message, error: true);
                } catch (e) {
                  if (context.mounted) showKwikSnack(context, '$e', error: true);
                }
              },
              child: const Text('Open chat'),
            ),
          ],
        ),
      ),
    );
    handle.dispose();
  }
}

class _YarnRoomsStrip extends ConsumerWidget {
  const _YarnRoomsStrip({required this.rooms});
  final AsyncValue<List<YarnRoom>> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    return rooms.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final room = list[i];
              return GestureDetector(
                onTap: () => _openRoom(context, room),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kc.surface,
                    borderRadius: BorderRadius.circular(KwikRadius.pill),
                    border: Border.all(color: kc.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: Color(0xFFFF5C5C), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        room.title,
                        style: TextStyle(color: kc.text, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Text('· ${room.listenerCount}', style: TextStyle(color: kc.muted, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openRoom(BuildContext context, YarnRoom room) {
    showKwikSheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, color: context.kc.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(room.title,
                      style: TextStyle(color: context.kc.text, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Hosted by @${room.hostUsername} · ${room.listenerCount} listening',
                style: TextStyle(color: context.kc.muted, fontSize: 12.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.kc.surface2,
                borderRadius: BorderRadius.circular(KwikRadius.control),
                border: Border.all(color: context.kc.border),
              ),
              child: Text(
                'Live audio rooms are wired to LiveKit in v0.2. The room list, host roles and listener counts are already real data.',
                style: TextStyle(color: context.kc.muted, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final hasUnread = conversation.unreadCount > 0;
    return InkWell(
      onTap: () {
        if (!conversation.isGroup && conversation.otherUsername == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ThreadScreen(
              conversationId: conversation.id,
              title: conversation.displayName,
              orderStatus: conversation.orderStatus,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            KwikAvatar(initials: conversation.initials, isGroup: conversation.isGroup),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: kc.text,
                            fontSize: 14.5,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontFamily: conversation.isGroup ? null : 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatTimeAgo(conversation.lastMessageAt),
                        style: TextStyle(
                          color: hasUnread ? kc.accent : kc.muted,
                          fontSize: 10.5,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage?.isNotEmpty == true
                              ? conversation.lastMessage!
                              : 'Say hello 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? kc.text : kc.muted,
                            fontSize: 12.5,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (conversation.isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.notifications_off_outlined, size: 13, color: kc.muted),
                        ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: kc.accent, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: TextStyle(color: kc.accentOn, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  if (conversation.orderStatus != OrderStatus.none) ...[
                    const SizedBox(height: 6),
                    KwikPill(
                      label: orderStatusLabel(conversation.orderStatus),
                      color: conversation.orderStatus == OrderStatus.paid ? kc.accent : kc.info,
                      filled: true,
                      icon: Icons.receipt_long,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
