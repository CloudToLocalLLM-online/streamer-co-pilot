import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'time': '14:30',
        'user': 'testuser',
        'text': 'Hello world!',
        'is_mod': true,
        'is_sub': false,
        'is_vip': true,
        'is_broadcaster': false,
        'id': 'msg-123',
      };

      final msg = ChatMessage.fromJson(json);

      expect(msg.time, '14:30');
      expect(msg.user, 'testuser');
      expect(msg.text, 'Hello world!');
      expect(msg.isMod, true);
      expect(msg.isSub, false);
      expect(msg.isVip, true);
      expect(msg.isBroadcaster, false);
      expect(msg.id, 'msg-123');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final msg = ChatMessage.fromJson(json);

      expect(msg.time, '');
      expect(msg.user, '?');
      expect(msg.text, '');
      expect(msg.isMod, false);
      expect(msg.isSub, false);
      expect(msg.isVip, false);
      expect(msg.isBroadcaster, false);
      expect(msg.id, '');
    });

    test('fromJson handles null fields gracefully', () {
      final json = {
        'time': null,
        'user': null,
        'text': null,
        'is_mod': null,
        'is_sub': null,
        'is_vip': null,
        'is_broadcaster': null,
        'id': null,
      };

      final msg = ChatMessage.fromJson(json);

      expect(msg.time, '');
      expect(msg.user, '?');
      expect(msg.text, '');
      expect(msg.isMod, false);
      expect(msg.isSub, false);
      expect(msg.isVip, false);
      expect(msg.isBroadcaster, false);
      expect(msg.id, '');
    });

    test('toJson produces correct map', () {
      final msg = ChatMessage(
        time: '12:00',
        user: 'streamer',
        text: 'Hey everyone!',
        isMod: false,
        isSub: true,
        isVip: false,
        isBroadcaster: true,
        id: 'abc-456',
      );

      final json = msg.toJson();

      expect(json['time'], '12:00');
      expect(json['user'], 'streamer');
      expect(json['text'], 'Hey everyone!');
      expect(json['is_mod'], false);
      expect(json['is_sub'], true);
      expect(json['is_vip'], false);
      expect(json['is_broadcaster'], true);
      expect(json['id'], 'abc-456');
    });

    test('round-trip toJson -> fromJson preserves all values', () {
      final original = ChatMessage(
        time: '10:15',
        user: 'moderator',
        text: 'Keep chat clean please',
        isMod: true,
        isSub: false,
        isVip: false,
        isBroadcaster: false,
        id: 'roundtrip-1',
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.time, original.time);
      expect(restored.user, original.user);
      expect(restored.text, original.text);
      expect(restored.isMod, original.isMod);
      expect(restored.isSub, original.isSub);
      expect(restored.isVip, original.isVip);
      expect(restored.isBroadcaster, original.isBroadcaster);
      expect(restored.id, original.id);
    });

    test('default constructor sets defaults correctly', () {
      final msg = ChatMessage(
        time: '00:00',
        user: 'anon',
        text: 'test',
      );

      expect(msg.isMod, false);
      expect(msg.isSub, false);
      expect(msg.isVip, false);
      expect(msg.isBroadcaster, false);
      expect(msg.id, '');
    });
  });
}
