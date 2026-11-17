import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/kwik_theme.dart';
import '../widgets/common.dart';

/// A +Joint post with its discussion thread.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.post, required this.jointTag});
  final JointPost post;
  final String jointTag;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<JointComment> _comments = const [];
  bool _loading = true;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await ref.read(apiProvider).fetchComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KwikError ? e.message : 'Could not load comments.';
      });
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await ref.read(apiProvider).addComment(postId: widget.post.id, body: body);
      _input.clear();
      await _load();
      ref.invalidate(jointFeedProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    } on KwikError catch (e) {
      if (mounted) showKwikSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final post = widget.post;

    return Scaffold(
      backgroundColor: kc.bg,
      appBar: AppBar(
        title: Text(
          widget.jointTag,
          style: TextStyle(color: kc.text, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                Text(
                  post.title,
                  style: TextStyle(color: kc.text, fontSize: 19, fontWeight: FontWeight.w800, height: 1.3),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('@${post.authorUsername}',
                        style: TextStyle(color: kc.muted, fontSize: 12, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Text('· ${formatTimeAgo(post.createdAt)}',
                        style: TextStyle(color: kc.muted, fontSize: 11.5)),
                    const Spacer(),
                    KwikPill(
                      label: '${post.score} hype',
                      color: post.score >= 0 ? kc.accent : kc.danger,
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
                if (post.body.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(post.body, style: TextStyle(color: kc.text, fontSize: 14.5, height: 1.55)),
                ],
                const SizedBox(height: 22),
                Divider(color: kc.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${_comments.length} comments',
                        style: TextStyle(color: kc.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_loading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: kc.accent),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(_error!, style: TextStyle(color: kc.danger, fontSize: 12.5)),
                  )
                else if (!_loading && _comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                      child: Text(
                        'No comments yet. Start the gist.',
                        style: TextStyle(color: kc.muted, fontSize: 12.5),
                      ),
                    ),
                  )
                else
                  for (final comment in _comments) _CommentTile(comment: comment),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: kc.surface,
              border: Border(top: BorderSide(color: kc.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: kc.text, fontSize: 14),
                        decoration: const InputDecoration(hintText: 'Add a comment…', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _posting ? null : _send,
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _posting ? kc.surface2 : kc.accent,
                          shape: BoxShape.circle,
                        ),
                        child: _posting
                            ? SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 1.8, color: kc.muted),
                              )
                            : Icon(Icons.arrow_upward_rounded, size: 20, color: kc.accentOn),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final JointComment comment;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KwikAvatar(
            initials: comment.authorUsername.isEmpty ? '?' : comment.authorUsername.substring(0, 1).toUpperCase(),
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('@${comment.authorUsername}',
                        style: TextStyle(color: kc.text, fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Text('· ${formatTimeAgo(comment.createdAt)}',
                        style: TextStyle(color: kc.muted, fontSize: 10.5)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.body, style: TextStyle(color: kc.text, fontSize: 13.5, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
