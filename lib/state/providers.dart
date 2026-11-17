import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../data/api.dart';
import '../data/local_cache.dart';
import '../data/models.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------- primitives

final cacheProvider = Provider<LocalCache>((ref) => LocalCache());

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final apiProvider = Provider<KwikApi>((ref) {
  final client = ref.watch(supabaseProvider);
  return KwikApi(client);
});

final authChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(apiProvider).authChanges;
});

// ------------------------------------------------------------------- profile

final profileProvider = StreamProvider<Profile?>((ref) async* {
  final api = ref.watch(apiProvider);
  final cache = ref.watch(cacheProvider);

  // Emit cached profile immediately (offline-first), then refresh.
  final cached = await cache.loadProfile();
  if (cached != null) yield cached;
  if (!api.hasSession) {
    yield null;
    return;
  }

  Future<Profile?> load() async {
    try {
      final fresh = await api.fetchProfile();
      if (fresh != null) await cache.saveProfile(fresh);
      return fresh;
    } catch (_) {
      return cached;
    }
  }

  yield await load();

  // Re-fetch whenever auth changes (sign-in, refresh, sign-out).
  await for (final _ in api.authChanges) {
    yield await load();
  }
});

// --------------------------------------------------------------- theme prefs

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(cacheProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._cache) : super(ThemeMode.dark) {
    _restore();
  }
  final LocalCache _cache;

  Future<void> _restore() async {
    final stored = await _cache.themeMode();
    if (stored == 'light') state = ThemeMode.light;
    if (stored == 'system') state = ThemeMode.system;
  }

  Future<void> toggle(bool goLight) async {
    state = goLight ? ThemeMode.light : ThemeMode.dark;
    await _cache.setThemeMode(goLight ? 'light' : 'dark');
  }
}

// -------------------------------------------------------------- conversations

class ChatListState {
  const ChatListState({
    this.conversations = const [],
    this.loading = true,
    this.offline = false,
    this.error,
  });
  final List<Conversation> conversations;
  final bool loading;
  final bool offline;
  final String? error;

  ChatListState copyWith({
    List<Conversation>? conversations,
    bool? loading,
    bool? offline,
    String? error,
    bool clearError = false,
  }) =>
      ChatListState(
        conversations: conversations ?? this.conversations,
        loading: loading ?? this.loading,
        offline: offline ?? this.offline,
        error: clearError ? null : (error ?? this.error),
      );
}

final chatListProvider = StateNotifierProvider<ChatListController, ChatListState>((ref) {
  return ChatListController(ref);
});

class ChatListController extends StateNotifier<ChatListState> {
  ChatListController(this._ref) : super(const ChatListState()) {
    _api = _ref.read(apiProvider);
    _boot();
  }

  final Ref _ref;
  late final KwikApi _api;
  RealtimeChannel? _channel;
  Timer? _debounce;

  LocalCache get _cache => _ref.read(cacheProvider);

  Future<void> _boot() async {
    final cached = await _cache.loadConversations();
    if (cached.isNotEmpty) {
      state = state.copyWith(conversations: cached, loading: false);
    }
    await refresh();
    _channel = _api.watchInbox(onChanged: _onInboxChange);
  }

  void _onInboxChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  Future<void> refresh() async {
    try {
      final fresh = await _api.fetchConversations();
      await _cache.saveConversations(fresh);
      if (!mounted) return;
      state = state.copyWith(conversations: fresh, loading: false, offline: false, clearError: true);
    } catch (e) {
      if (!mounted) return;
      final message = e is KwikError ? e.message : 'Could not load chats.';
      state = state.copyWith(
        loading: false,
        offline: state.conversations.isNotEmpty,
        error: state.conversations.isEmpty ? message : null,
      );
    }
  }

  Future<String?> startWith(String username) async {
    try {
      final id = await _api.startConversation(username);
      await refresh();
      return id;
    } on KwikError {
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final channel = _channel;
    if (channel != null) {
      _api.removeChannel(channel);
    }
    super.dispose();
  }
}

// -------------------------------------------------------------- thread state

class ThreadState {
  const ThreadState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.offline = false,
    this.error,
  });
  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final bool offline;
  final String? error;

  ThreadState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    bool? offline,
    String? error,
    bool clearError = false,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        offline: offline ?? this.offline,
        error: clearError ? null : (error ?? this.error),
      );
}

final threadProvider = StateNotifierProvider.family<ThreadController, ThreadState, String>((ref, conversationId) {
  return ThreadController(ref, conversationId);
});

class ThreadController extends StateNotifier<ThreadState> {
  ThreadController(this._ref, this.conversationId) : super(const ThreadState()) {
    _api = _ref.read(apiProvider);
    _boot();
  }

  final Ref _ref;
  final String conversationId;
  late final KwikApi _api;
  RealtimeChannel? _channel;

  LocalCache get _cache => _ref.read(cacheProvider);

  Future<void> _boot() async {
    final cached = await _cache.loadMessages(conversationId);
    if (cached.isNotEmpty) {
      state = state.copyWith(messages: cached, loading: false);
    }
    _channel = _api.watchMessages(conversationId: conversationId, onInsert: _onRemote);
    _api.markRead(conversationId);
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final fresh = await _api.fetchMessages(conversationId);
      if (!mounted) return;
      state = state.copyWith(messages: fresh, loading: false, offline: false, clearError: true);
      await _cache.saveMessages(conversationId, fresh);
    } catch (e) {
      if (!mounted) return;
      final message = e is KwikError ? e.message : 'Could not load messages.';
      state = state.copyWith(
        loading: false,
        offline: state.messages.isNotEmpty,
        error: state.messages.isEmpty ? message : null,
      );
    }
  }

  void _onRemote(ChatMessage incoming) {
    if (!mounted) return;
    if (state.messages.any((m) => m.id == incoming.id)) return;
    final withoutPending = state.messages
        .where((m) => !(m.sendState == SendState.pending && m.clientId == incoming.clientId))
        .toList();
    final next = [...withoutPending, incoming]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: next);
    _cache.saveMessages(conversationId, next);
    if (incoming.senderId != _api.currentUserId) {
      _api.markRead(conversationId);
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final uid = _api.currentUserId;
    if (uid == null) return;

    final clientId = _uuid.v4();
    final optimistic = ChatMessage(
      id: 'local-$clientId',
      conversationId: conversationId,
      senderId: uid,
      kind: MessageKind.text,
      body: trimmed,
      createdAt: DateTime.now(),
      clientId: clientId,
      sendState: SendState.pending,
    );
    _appendOptimistic(optimistic);

    try {
      final saved = await _api.sendText(
        conversationId: conversationId,
        body: trimmed,
        clientId: clientId,
      );
      _replaceOptimistic(clientId, saved);
      await _cache.saveMessages(conversationId, state.messages);
    } catch (e) {
      _markFailed(clientId);
      if (mounted) {
        state = state.copyWith(error: e is KwikError ? e.message : 'Message not sent.');
      }
    }
  }

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
    String extension = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    final uid = _api.currentUserId;
    if (uid == null) return;

    final clientId = _uuid.v4();
    final optimistic = ChatMessage(
      id: 'local-$clientId',
      conversationId: conversationId,
      senderId: uid,
      kind: MessageKind.voice,
      durationMs: durationMs,
      createdAt: DateTime.now(),
      clientId: clientId,
      sendState: SendState.pending,
    );
    _appendOptimistic(optimistic);

    try {
      final saved = await _api.sendVoice(
        conversationId: conversationId,
        bytes: bytes,
        durationMs: durationMs,
        clientId: clientId,
        extension: extension,
        contentType: contentType,
      );
      _replaceOptimistic(clientId, saved);
      await _cache.saveMessages(conversationId, state.messages);
    } catch (e) {
      _markFailed(clientId);
      if (mounted) {
        state = state.copyWith(error: e is KwikError ? e.message : 'Voice note not sent.');
      }
    }
  }

  void _appendOptimistic(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message], sending: true, clearError: true);
  }

  void _replaceOptimistic(String clientId, ChatMessage saved) {
    if (!mounted) return;
    final next = state.messages
        .map((m) => m.clientId == clientId ? saved : m)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: next, sending: false);
  }

  void _markFailed(String clientId) {
    if (!mounted) return;
    final next = state.messages
        .map((m) => m.clientId == clientId ? m.copyWith(sendState: SendState.failed) : m)
        .toList();
    state = state.copyWith(messages: next, sending: false);
  }

  void clearError() {
    if (mounted) state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _api.removeChannel(channel);
    }
    super.dispose();
  }
}

// ----------------------------------------------------------------- data mode

final dataSaverProvider = StateNotifierProvider<DataSaverController, bool>((ref) {
  return DataSaverController(ref.watch(cacheProvider), ref);
});

class DataSaverController extends StateNotifier<bool> {
  DataSaverController(this._cache, this._ref) : super(true) {
    _restore();
  }
  final LocalCache _cache;
  final Ref _ref;

  Future<void> _restore() async {
    state = await _cache.dataSaver();
  }

  Future<void> toggle(bool enabled) async {
    state = enabled;
    await _cache.setDataSaver(enabled);
    final api = _ref.read(apiProvider);
    if (api.hasSession) {
      try {
        await api.setDataSaver(enabled);
      } catch (_) {}
    }
  }
}

final reelsDataSaverProvider = StateNotifierProvider<ReelsSaverController, bool>((ref) {
  return ReelsSaverController(ref.watch(cacheProvider));
});

class ReelsSaverController extends StateNotifier<bool> {
  ReelsSaverController(this._cache) : super(true) {
    _restore();
  }
  final LocalCache _cache;

  Future<void> _restore() async {
    state = await _cache.reelsDataSaver();
  }

  Future<void> toggle(bool enabled) async {
    state = enabled;
    await _cache.setReelsDataSaver(enabled);
  }
}

// --------------------------------------------------------------------- feeds

final jointsProvider = FutureProvider<List<Joint>>((ref) async {
  return ref.watch(apiProvider).fetchJoints();
});

final jointFeedProvider = FutureProvider.family<List<JointPost>, String>((ref, jointId) async {
  return ref.watch(apiProvider).fetchJointFeed(jointId);
});

final reelsProvider = FutureProvider<List<Reel>>((ref) async {
  return ref.watch(apiProvider).fetchReels();
});

final roomsProvider = FutureProvider<List<YarnRoom>>((ref) async {
  return ref.watch(apiProvider).fetchLiveRooms();
});

final envConfiguredProvider = Provider<bool>((ref) => Env.isConfigured);
