import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Offline-first cache.
///
/// Deliberate deviation from the original PRD (Isar): this build targets
/// web + Android + iOS + desktop from one codebase, so the local store must
/// work on IndexedDB *and* native. shared_preferences does, with zero codegen
/// and zero native build steps. Swap in Drift later behind this same interface
/// when message volume needs real SQL (documented in docs/CORRECTIONS.md).
class LocalCache {
  static const _kConversations = 'kwik.cache.conversations.v1';
  static const _kMessages = 'kwik.cache.messages.v1.';
  static const _kProfile = 'kwik.cache.profile.v1';
  static const _kThemeMode = 'kwik.pref.themeMode';
  static const _kDataSaver = 'kwik.pref.dataSaver';
  static const _kReelsSaver = 'kwik.pref.reelsDataSaver';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await _prefs;
    await prefs.setString(
      _kConversations,
      jsonEncode(conversations.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<Conversation>> loadConversations() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kConversations);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Conversation.fromMap)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Keeps only the most recent [keep] messages per thread to respect the
  /// "zero-bloat local storage" promise on 32GB devices.
  Future<void> saveMessages(String conversationId, List<ChatMessage> messages, {int keep = 80}) async {
    final prefs = await _prefs;
    final trimmed = messages.length > keep ? messages.sublist(messages.length - keep) : messages;
    await prefs.setString(
      '$_kMessages$conversationId',
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kMessages$conversationId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearMessages(String conversationId) async {
    final prefs = await _prefs;
    await prefs.remove('$_kMessages$conversationId');
  }

  Future<void> saveProfile(Profile profile) async {
    final prefs = await _prefs;
    await prefs.setString(_kProfile, jsonEncode(profile.toJson()));
  }

  Future<Profile?> loadProfile() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Profile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await _prefs;
    await prefs.setString(_kThemeMode, mode);
  }

  Future<String?> themeMode() async {
    final prefs = await _prefs;
    return prefs.getString(_kThemeMode);
  }

  Future<void> setDataSaver(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_kDataSaver, enabled);
  }

  Future<bool> dataSaver() async {
    final prefs = await _prefs;
    return prefs.getBool(_kDataSaver) ?? true;
  }

  Future<void> setReelsDataSaver(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_kReelsSaver, enabled);
  }

  Future<bool> reelsDataSaver() async {
    final prefs = await _prefs;
    return prefs.getBool(_kReelsSaver) ?? true;
  }

  Future<void> wipe() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((k) => k.startsWith('kwik.')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
