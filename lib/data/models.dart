int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _asDate(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
  return null;
}

String _asString(dynamic v, [String fallback = '']) => v is String ? v : fallback;

/// The signed-in user. Cowries live on the server ledger; this is a cached copy.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.cowriesBalance,
    this.bio = '',
    this.avatarPath,
    this.city = 'Jos',
    this.dataSaver = true,
    this.isVendor = false,
    this.isVerified = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarPath;
  final String city;
  final int cowriesBalance;
  final bool dataSaver;
  final bool isVendor;
  final bool isVerified;

  String get handle => '@$username';
  String get initials {
    final source = displayName.trim().isEmpty ? username : displayName.trim();
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: _asString(m['id']),
        username: _asString(m['username']),
        displayName: _asString(m['display_name']),
        bio: _asString(m['bio']),
        avatarPath: m['avatar_path'] as String?,
        city: _asString(m['city'], 'Jos'),
        cowriesBalance: _asInt(m['cowries_balance']),
        dataSaver: m['data_saver_mode'] as bool? ?? true,
        isVendor: m['is_vendor'] as bool? ?? false,
        isVerified: m['is_verified'] as bool? ?? false,
      );

  Profile copyWith({int? cowriesBalance, bool? dataSaver, String? displayName}) => Profile(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        bio: bio,
        avatarPath: avatarPath,
        city: city,
        cowriesBalance: cowriesBalance ?? this.cowriesBalance,
        dataSaver: dataSaver ?? this.dataSaver,
        isVendor: isVendor,
        isVerified: isVerified,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'bio': bio,
        'avatar_path': avatarPath,
        'city': city,
        'cowries_balance': cowriesBalance,
        'data_saver_mode': dataSaver,
        'is_vendor': isVendor,
        'is_verified': isVerified,
      };
}

enum OrderStatus { none, pendingPayment, paid, dispatched, resolved }

OrderStatus orderStatusFrom(String? raw) {
  switch (raw) {
    case 'Pending Payment':
      return OrderStatus.pendingPayment;
    case 'Paid':
      return OrderStatus.paid;
    case 'Dispatched':
      return OrderStatus.dispatched;
    case 'Resolved':
      return OrderStatus.resolved;
    default:
      return OrderStatus.none;
  }
}

String orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.pendingPayment:
      return 'Pending Payment';
    case OrderStatus.paid:
      return 'Paid';
    case OrderStatus.dispatched:
      return 'Dispatched';
    case OrderStatus.resolved:
      return 'Resolved';
    case OrderStatus.none:
      return '';
  }
}

/// One row of `conversation_summaries` (RLS-safe view).
class Conversation {
  const Conversation({
    required this.id,
    required this.isGroup,
    this.title,
    this.otherUsername,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isMuted = false,
    this.orderStatus = OrderStatus.none,
  });

  final String id;
  final bool isGroup;
  final String? title;
  final String? otherUsername;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isMuted;
  final OrderStatus orderStatus;

  String get displayName {
    if (isGroup) return title?.isNotEmpty == true ? title! : 'Group';
    return otherUsername == null ? 'KwikChat' : '@$otherUsername';
  }

  String get initials {
    final name = displayName.replaceFirst('@', '');
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
        id: _asString(m['id']),
        isGroup: m['is_group'] as bool? ?? false,
        title: m['title'] as String?,
        otherUsername: m['other_username'] as String?,
        lastMessage: m['last_message'] as String?,
        lastMessageAt: _asDate(m['last_message_at']),
        unreadCount: _asInt(m['unread_count']),
        isMuted: m['is_muted'] as bool? ?? false,
        orderStatus: orderStatusFrom(m['order_status'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'is_group': isGroup,
        'title': title,
        'other_username': otherUsername,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'unread_count': unreadCount,
        'is_muted': isMuted,
        'order_status': m2s(orderStatus),
      };

  static String m2s(OrderStatus s) => s == OrderStatus.none ? '' : orderStatusLabel(s);
}

enum MessageKind { text, voice, image, video, system }

MessageKind messageKindFrom(String? raw) {
  switch (raw) {
    case 'voice':
      return MessageKind.voice;
    case 'image':
      return MessageKind.image;
    case 'video':
      return MessageKind.video;
    case 'system':
      return MessageKind.system;
    default:
      return MessageKind.text;
  }
}

enum SendState { sent, pending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.createdAt,
    this.clientId,
    this.body = '',
    this.mediaPath,
    this.durationMs = 0,
    this.sendState = SendState.sent,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageKind kind;
  final String body;
  final String? mediaPath;
  final int durationMs;
  final DateTime createdAt;
  final String? clientId;
  final SendState sendState;

  bool get isVoice => kind == MessageKind.voice && durationMs > 0;

  String get preview {
    if (kind == MessageKind.voice) return '🎙 Voice note · ${formatDuration(durationMs)}';
    if (kind == MessageKind.image) return '📷 Photo';
    if (kind == MessageKind.video) return '🎬 Video';
    return body;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: _asString(m['id'], _asString(m['client_id'])),
        conversationId: _asString(m['conversation_id']),
        senderId: _asString(m['sender_id']),
        kind: messageKindFrom(m['kind'] as String?),
        body: _asString(m['body']),
        mediaPath: m['media_path'] as String?,
        durationMs: _asInt(m['duration_ms']),
        createdAt: _asDate(m['created_at']) ?? DateTime.now(),
        clientId: m['client_id'] as String?,
      );

  ChatMessage copyWith({String? id, SendState? sendState}) => ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        kind: kind,
        body: body,
        mediaPath: mediaPath,
        durationMs: durationMs,
        createdAt: createdAt,
        clientId: clientId,
        sendState: sendState ?? this.sendState,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'kind': kind.name,
        'body': body,
        'media_path': mediaPath,
        'duration_ms': durationMs,
        'created_at': createdAt.toIso8601String(),
        'client_id': clientId,
      };

  static ChatMessage fromJson(Map<String, dynamic> m) => ChatMessage.fromMap(m);
}

class Joint {
  const Joint({
    required this.id,
    required this.slug,
    required this.description,
    this.membersCount = 0,
  });
  final String id;
  final String slug;
  final String description;
  final int membersCount;

  String get tag => '+$slug';

  factory Joint.fromMap(Map<String, dynamic> m) => Joint(
        id: _asString(m['id']),
        slug: _asString(m['slug']),
        description: _asString(m['description']),
        membersCount: _asInt(m['members_count']),
      );
}

class JointPost {
  const JointPost({
    required this.id,
    required this.title,
    required this.body,
    required this.authorUsername,
    required this.hypeCount,
    required this.fadeCount,
    required this.commentCount,
    required this.createdAt,
    this.myVote,
  });
  final String id;
  final String title;
  final String body;
  final String authorUsername;
  final int hypeCount;
  final int fadeCount;
  final int commentCount;
  final DateTime createdAt;
  final String? myVote;

  int get score => hypeCount - fadeCount;

  factory JointPost.fromMap(Map<String, dynamic> m) => JointPost(
        id: _asString(m['id']),
        title: _asString(m['title']),
        body: _asString(m['body']),
        authorUsername: _asString(m['author_username']),
        hypeCount: _asInt(m['hype_count']),
        fadeCount: _asInt(m['fade_count']),
        commentCount: _asInt(m['comment_count']),
        createdAt: _asDate(m['created_at']) ?? DateTime.now(),
        myVote: m['my_vote'] as String?,
      );
}

class Reel {
  const Reel({
    required this.id,
    required this.caption,
    required this.creatorUsername,
    required this.city,
    this.priceNgn,
    this.thumbPath,
    this.videoPath,
    this.durationSec = 30,
  });
  final String id;
  final String caption;
  final String creatorUsername;
  final String city;
  final int? priceNgn;
  final String? thumbPath;
  final String? videoPath;
  final int durationSec;

  factory Reel.fromMap(Map<String, dynamic> m) => Reel(
        id: _asString(m['id']),
        caption: _asString(m['caption']),
        creatorUsername: _asString(m['creator_username']),
        city: _asString(m['city'], 'Lagos'),
        priceNgn: m['price_ngn'] == null ? null : _asInt(m['price_ngn']),
        thumbPath: m['thumb_path'] as String?,
        videoPath: m['video_path'] as String?,
        durationSec: _asInt(m['duration_sec'], 30),
      );
}

class YarnRoom {
  const YarnRoom({
    required this.id,
    required this.title,
    required this.hostUsername,
    this.listenerCount = 0,
  });
  final String id;
  final String title;
  final String hostUsername;
  final int listenerCount;

  factory YarnRoom.fromMap(Map<String, dynamic> m) => YarnRoom(
        id: _asString(m['id']),
        title: _asString(m['title']),
        hostUsername: _asString(m['host_username']),
        listenerCount: _asInt(m['listener_count']),
      );
}

class CowrieBundle {
  const CowrieBundle({
    required this.name,
    required this.cowries,
    required this.bonus,
    required this.priceNgn,
  });
  final String name;
  final int cowries;
  final int bonus;
  final int priceNgn;

  int get total => cowries + bonus;
  String get naira => '₦${_thousands(priceNgn)}';
  String get label => _thousands(total);
}

String _thousands(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

const kCowrieBundles = <CowrieBundle>[
  CowrieBundle(name: 'Starter Pouch', cowries: 100, bonus: 0, priceNgn: 500),
  CowrieBundle(name: 'Hustler Bag', cowries: 500, bonus: 50, priceNgn: 2500),
  CowrieBundle(name: 'Oga Chest', cowries: 1000, bonus: 200, priceNgn: 5000),
  CowrieBundle(name: 'Chief Vault', cowries: 2500, bonus: 500, priceNgn: 10000),
];

String formatDuration(int ms) {
  final totalSeconds = (ms / 1000).round();
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatTimeAgo(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${when.day}/${when.month}';
}

class JointComment {
  const JointComment({
    required this.id,
    required this.body,
    required this.authorUsername,
    required this.createdAt,
    this.hypeCount = 0,
  });

  final String id;
  final String body;
  final String authorUsername;
  final DateTime createdAt;
  final int hypeCount;

  factory JointComment.fromMap(Map<String, dynamic> m) => JointComment(
        id: _asString(m['id']),
        body: _asString(m['body']),
        authorUsername: _asString(m['author_username']),
        hypeCount: _asInt(m['hype_count']),
        createdAt: _asDate(m['created_at']) ?? DateTime.now(),
      );
}
