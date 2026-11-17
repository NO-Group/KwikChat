import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import '../widgets/common.dart';
import 'post_screen.dart';

class JointsScreen extends ConsumerWidget {
  const JointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final joints = ref.watch(jointsProvider);

    return Scaffold(
      backgroundColor: kc.bg,
      appBar: AppBar(
        title: Text(
          '+ Joints',
          style: TextStyle(color: kc.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: kc.muted, size: 20),
            onPressed: () => ref.invalidate(jointsProvider),
          ),
        ],
      ),
      body: joints.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e is KwikError ? e.message : 'Could not load communities.',
          onRetry: () => ref.invalidate(jointsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.grid_view_rounded,
              title: 'No Joints yet',
              message: 'Communities appear here once they are created. Seed the starter set from supabase/seed.sql.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: kc.border),
            itemBuilder: (context, i) {
              final joint = list[i];
              return ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => JointFeedScreen(joint: joint)),
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kc.accentDim,
                    borderRadius: BorderRadius.circular(KwikRadius.control),
                    border: Border.all(color: kc.accent.withValues(alpha: 0.35)),
                  ),
                  child: Text('+', style: TextStyle(color: kc.accent, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                title: Text(
                  joint.tag,
                  style: TextStyle(color: kc.text, fontSize: 14.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                ),
                subtitle: Text(
                  joint.description.isEmpty ? '${joint.membersCount} members' : '${joint.description} · ${joint.membersCount} members',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kc.muted, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: kc.muted, size: 18),
              );
            },
          );
        },
      ),
    );
  }
}

class JointFeedScreen extends ConsumerStatefulWidget {
  const JointFeedScreen({super.key, required this.joint});
  final Joint joint;

  @override
  ConsumerState<JointFeedScreen> createState() => _JointFeedScreenState();
}

class _JointFeedScreenState extends ConsumerState<JointFeedScreen> {
  String _sort = 'hot';

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final feed = ref.watch(jointFeedProvider(widget.joint.id));

    return Scaffold(
      backgroundColor: kc.bg,
      appBar: AppBar(
        title: Text(
          widget.joint.tag,
          style: TextStyle(color: kc.text, fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
        ),
        actions: [
          IconButton(
            tooltip: 'New post',
            icon: Icon(Icons.add_comment_outlined, color: kc.muted, size: 20),
            onPressed: () => _compose(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                for (final option in const ['hot', 'new', 'top'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _sort = option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _sort == option ? kc.accentDim : Colors.transparent,
                          borderRadius: BorderRadius.circular(KwikRadius.pill),
                          border: Border.all(color: _sort == option ? kc.accent : kc.border),
                        ),
                        child: Text(
                          option.toUpperCase(),
                          style: TextStyle(
                            color: _sort == option ? kc.accent : kc.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e is KwikError ? e.message : 'Could not load posts.',
          onRetry: () => ref.invalidate(jointFeedProvider(widget.joint.id)),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return EmptyState(
              icon: Icons.article_outlined,
              title: 'Nothing posted yet',
              message: 'Be the first to post in ${widget.joint.tag}.',
              actionLabel: 'Write a post',
              onAction: () => _compose(context),
            );
          }
          final sorted = List<JointPost>.from(posts);
          if (_sort == 'new') {
            sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else if (_sort == 'top') {
            sorted.sort((a, b) => b.score.compareTo(a.score));
          }
          return RefreshIndicator(
            color: kc.accent,
            onRefresh: () async => ref.invalidate(jointFeedProvider(widget.joint.id)),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 20),
              itemCount: sorted.length,
              itemBuilder: (context, i) => _PostCard(post: sorted[i], jointTag: widget.joint.tag),
            ),
          );
        },
      ),
    );
  }

  Future<void> _compose(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.kc.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Post in ${widget.joint.tag}',
                style: TextStyle(color: context.kc.text, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              style: TextStyle(color: context.kc.text, fontSize: 15),
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(color: context.kc.text, fontSize: 14),
              decoration: const InputDecoration(hintText: 'What is the gist?'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().length < 3) return;
                final navigator = Navigator.of(context);
                try {
                  await ref.read(apiProvider).createPost(
                        jointId: widget.joint.id,
                        title: title.text.trim(),
                        body: body.text.trim(),
                      );
                  navigator.pop();
                  ref.invalidate(jointFeedProvider(widget.joint.id));
                } on KwikError catch (e) {
                  if (context.mounted) showKwikSnack(context, e.message, error: true);
                }
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post, required this.jointTag});
  final JointPost post;
  final String jointTag;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late String? _vote = widget.post.myVote;

  Future<void> _cast(bool hype) async {
    final next = hype ? 'hype' : 'fade';
    setState(() => _vote = _vote == next ? null : next);
    try {
      await ref.read(apiProvider).vote(postId: widget.post.id, hype: hype);
      ref.invalidate(jointFeedProvider);
    } on KwikError catch (e) {
      if (mounted) {
        setState(() => _vote = widget.post.myVote);
        showKwikSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final post = widget.post;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: KwikCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostScreen(post: post, jointTag: widget.jointTag),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('@${post.authorUsername}',
                    style: TextStyle(color: kc.muted, fontSize: 11.5, fontFamily: 'monospace')),
                const SizedBox(width: 6),
                Text('· ${formatTimeAgo(post.createdAt)}', style: TextStyle(color: kc.muted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 7),
            Text(post.title, style: TextStyle(color: kc.text, fontSize: 15, fontWeight: FontWeight.w700)),
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(post.body, style: TextStyle(color: kc.muted, fontSize: 13, height: 1.45)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _VoteChip(
                  icon: Icons.local_fire_department,
                  label: '${post.hypeCount}',
                  active: _vote == 'hype',
                  activeColor: kc.accent,
                  onTap: () => _cast(true),
                ),
                const SizedBox(width: 8),
                _VoteChip(
                  icon: Icons.arrow_downward_rounded,
                  label: '${post.fadeCount}',
                  active: _vote == 'fade',
                  activeColor: kc.danger,
                  onTap: () => _cast(false),
                ),
                const SizedBox(width: 12),
                Icon(Icons.mode_comment_outlined, size: 14, color: kc.muted),
                const SizedBox(width: 4),
                Text(
                  post.commentCount == 0 ? 'Comment' : '${post.commentCount}',
                  style: TextStyle(color: kc.muted, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final color = active ? activeColor : kc.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(KwikRadius.pill),
          border: Border.all(color: active ? activeColor : kc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
