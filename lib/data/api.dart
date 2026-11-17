import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// A user-facing error with a cause we control.
class KwikError implements Exception {
  KwikError(this.code, [String? detail]) : detail = detail ?? '';
  final String code;
  final String detail;

  String get message {
    switch (code) {
      case 'username_taken':
        return 'That @username is already taken. Try another.';
      case 'invalid_username':
        return 'Use 3–20 characters: lowercase letters, numbers or underscore.';
      case 'not_authenticated':
        return 'Your session expired. Please sign in again.';
      case 'insufficient_cowries':
        return 'Not enough Cowries for that.';
      case 'blocked':
        return 'You cannot message this person.';
      case 'not_found':
        return 'We could not find that @username.';
      case 'rate_limited':
        return 'Too many attempts. Wait a moment and try again.';
      case 'offline':
        return 'No connection. Check your data and try again.';
      case 'invalid_code':
        return 'That code is not correct or has expired.';
      default:
        return detail.isNotEmpty ? detail : 'Something went wrong. Try again.';
    }
  }

  @override
  String toString() => 'KwikError($code): $detail';
}

KwikError _map(Object error) {
  if (error is KwikError) return error;
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('expired') || msg.contains('invalid') || msg.contains('token')) {
      return KwikError('invalid_code', error.message);
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return KwikError('rate_limited', error.message);
    }
    if (msg.contains('fetch') || msg.contains('network') || msg.contains('socket')) {
      return KwikError('offline', error.message);
    }
    return KwikError('auth', error.message);
  }
  if (error is PostgrestException) {
    final raw = error.message;
    for (final code in const [
      'username_taken',
      'invalid_username',
      'not_authenticated',
      'insufficient_cowries',
      'blocked',
      'not_found',
      'invalid_kind',
      'invalid_amount',
    ]) {
      if (raw.contains(code)) return KwikError(code, raw);
    }
    if (error.code == '23505') return KwikError('username_taken', raw);
    return KwikError('server', raw);
  }
  if (error is StorageException) return KwikError('upload', error.message);
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('failed host lookup') || text.contains('network')) {
    return KwikError('offline');
  }
  return KwikError('unknown', error.toString());
}

/// Everything the UI needs from the backend, in one place.
/// No widget ever touches [SupabaseClient] directly.
class KwikApi {
  KwikApi(this._client);

  final SupabaseClient _client;

  // ---------------------------------------------------------------- identity

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  bool get hasSession => _client.auth.currentSession != null;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> sendEmailCode(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email.trim());
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> verifyEmailCode({required String email, required String code}) async {
    try {
      await _client.auth.verifyOtp(email: email.trim(), token: code.trim(), type: OtpType.email);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw _map(e);
    }
  }

  Future<Profile?> fetchProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
      if (row == null) return null;
      return Profile.fromMap(row);
    } catch (e) {
      throw _map(e);
    }
  }

  /// Claims a unique @handle. Server-side validation; the client never writes
  /// to `profiles` directly (see RLS + column grants in migrations).
  Future<void> claimUsername({required String username, required String displayName}) async {
    try {
      await _client.rpc('claim_username', params: {
        'p_username': username.trim().toLowerCase(),
        'p_display_name': displayName.trim(),
      });
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> setDataSaver(bool enabled) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.from('profiles').update({'data_saver_mode': enabled}).eq('id', uid);
    } catch (e) {
      throw _map(e);
    }
  }

  // -------------------------------------------------------------------- chat

  Future<List<Conversation>> fetchConversations() async {
    try {
      final rows = await _client
          .from('conversation_summaries')
          .select()
          .order('last_message_at', ascending: false, nullsFirst: false);
      return rows.map(Conversation.fromMap).toList(growable: false);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId, {int limit = 60}) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.reversed.map(ChatMessage.fromMap).toList(growable: false);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<String> startConversation(String username) async {
    try {
      final result = await _client.rpc('start_direct_conversation', params: {
        'p_username': username.trim().toLowerCase().replaceFirst('@', ''),
      });
      return result as String;
    } catch (e) {
      throw _map(e);
    }
  }

  Future<ChatMessage> sendText({
    required String conversationId,
    required String body,
    required String clientId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw KwikError('not_authenticated');
    try {
      final row = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': uid,
            'kind': 'text',
            'body': body,
            'client_id': clientId,
          })
          .select()
          .single();
      return ChatMessage.fromMap(row);
    } catch (e) {
      throw _map(e);
    }
  }

  /// Uploads compressed audio, then writes the message row.
  /// Media never sits in Postgres, and the bucket is private.
  Future<ChatMessage> sendVoice({
    required String conversationId,
    required Uint8List bytes,
    required int durationMs,
    required String clientId,
    String extension = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    final uid = currentUserId;
    if (uid == null) throw KwikError('not_authenticated');
    final path = '$uid/$conversationId/$clientId.$extension';
    try {
      // Content type is inferred from the file extension by the client and
      // validated by the bucket's allowed_mime_types list server-side.
      await _client.storage.from('media').uploadBinary(path, bytes);
      final row = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': uid,
            'kind': 'voice',
            'media_path': path,
            'duration_ms': durationMs,
            'client_id': clientId,
          })
          .select()
          .single();
      return ChatMessage.fromMap(row);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<String> signedMediaUrl(String path, {int expiresIn = 3600}) async {
    try {
      return await _client.storage.from('media').createSignedUrl(path, expiresIn);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc('mark_read', params: {'p_conversation_id': conversationId});
    } catch (_) {
      // Read receipts are best-effort; never block the UI on them.
    }
  }

  Future<void> setMuted(String conversationId, bool muted) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client
          .from('conversation_participants')
          .update({'is_muted': muted})
          .eq('conversation_id', conversationId)
          .eq('user_id', uid);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> setOrderStatus(String conversationId, OrderStatus status) async {
    try {
      await _client.rpc('set_order_status', params: {
        'p_conversation_id': conversationId,
        'p_status': orderStatusLabel(status),
      });
    } catch (e) {
      throw _map(e);
    }
  }

  RealtimeChannel watchMessages({
    required String conversationId,
    required void Function(ChatMessage) onInsert,
  }) {
    final channel = _client.channel('kwik:messages:$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record.isEmpty) return;
        onInsert(ChatMessage.fromMap(record));
      },
    ).subscribe();
    return channel;
  }

  RealtimeChannel watchInbox({required void Function() onChanged}) {
    final channel = _client.channel('kwik:inbox');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (_) => onChanged(),
    ).subscribe();
    return channel;
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
    } catch (_) {}
  }

  // ------------------------------------------------------------ safety tools

  Future<void> blockUser(String userId) async {
    final uid = currentUserId;
    if (uid == null) throw KwikError('not_authenticated');
    try {
      await _client.from('blocks').insert({'blocker_id': uid, 'blocked_id': userId});
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> report({
    required String subjectType,
    required String subjectId,
    required String reason,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw KwikError('not_authenticated');
    try {
      await _client.from('reports').insert({
        'reporter_id': uid,
        'subject_type': subjectType,
        'subject_id': subjectId,
        'reason': reason,
      });
    } catch (e) {
      throw _map(e);
    }
  }

  // ------------------------------------------------------------------ joints

  Future<List<Joint>> fetchJoints() async {
    try {
      final rows = await _client
          .from('joints')
          .select()
          .order('members_count', ascending: false)
          .limit(50);
      return rows.map(Joint.fromMap).toList(growable: false);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<List<JointPost>> fetchJointFeed(String jointId, {String sort = 'hot'}) async {
    try {
      final rows = await _client.rpc('joint_feed', params: {
        'p_joint_id': jointId,
        'p_sort': sort,
      });
      if (rows is List) {
        return rows
            .whereType<Map<String, dynamic>>()
            .map(JointPost.fromMap)
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> vote({required String postId, required bool hype}) async {
    final uid = currentUserId;
    if (uid == null) throw KwikError('not_authenticated');
    try {
      await _client.from('joint_votes').upsert(
        {
          'post_id': postId,
          'user_id': uid,
          'vote_type': hype ? 'hype' : 'fade',
        },
        onConflict: 'post_id,user_id',
      );
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> createPost({
    required String jointId,
    required String title,
    required String body,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw KwikError('not_authenticated');
    try {
      await _client.from('joint_posts').insert({
        'joint_id': jointId,
        'author_id': uid,
        'title': title,
        'body': body,
      });
    } catch (e) {
      throw _map(e);
    }
  }

  // ------------------------------------------------------------------- reels

  Future<List<Reel>> fetchReels({String? city}) async {
    try {
      var query = _client.from('reel_feed').select();
      if (city != null && city.isNotEmpty) {
        query = query.eq('city', city);
      }
      final rows = await query.limit(20);
      return rows.map(Reel.fromMap).toList(growable: false);
    } catch (e) {
      throw _map(e);
    }
  }

  // ------------------------------------------------------------------- rooms

  Future<List<YarnRoom>> fetchLiveRooms() async {
    try {
      final rows = await _client
          .from('yarn_rooms')
          .select()
          .eq('is_live', true)
          .order('listener_count', ascending: false)
          .limit(20);
      return rows.map(YarnRoom.fromMap).toList(growable: false);
    } catch (e) {
      throw _map(e);
    }
  }
}
