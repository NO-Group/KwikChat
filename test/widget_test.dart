import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwikchat/data/models.dart';
import 'package:kwikchat/theme/kwik_theme.dart';
import 'package:kwikchat/ui/screens/gate_screen.dart';

void main() {
  testWidgets('an unconfigured build explains itself instead of crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KwikTheme.dark(),
        home: const ConfigMissingScreen(),
      ),
    );
    expect(find.text('Backend not configured'), findsOneWidget);
  });

  test('conversation summaries parse the shape the view returns', () {
    final conversation = Conversation.fromMap({
      'id': 'c1',
      'is_group': false,
      'other_username': 'amina_kd',
      'last_message': 'I don send am',
      'last_message_at': '2026-11-17T09:30:00Z',
      'unread_count': 3,
      'order_status': 'Paid',
    });
    expect(conversation.displayName, '@amina_kd');
    expect(conversation.unreadCount, 3);
    expect(conversation.orderStatus, OrderStatus.paid);
    expect(conversation.initials, 'A');
  });

  test('voice preview survives a round-trip through the cache', () {
    final message = ChatMessage.fromMap({
      'id': 'm1',
      'conversation_id': 'c1',
      'sender_id': 'u1',
      'kind': 'voice',
      'duration_ms': 8400,
      'created_at': '2026-11-17T09:30:00Z',
      'client_id': 'abc',
    });
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.isVoice, isTrue);
    expect(restored.preview, contains('0:08'));
  });

  test('bundle totals include the bonus', () {
    final hustler = kCowrieBundles.firstWhere((b) => b.name == 'Hustler Bag');
    expect(hustler.total, 550);
    expect(hustler.naira, '₦2,500');
  });
}
