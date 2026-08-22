import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/models/channel_event.dart';
import 'package:streamer_co_pilot/platforms/twitch_irc_client.dart';

void main() {
  late TwitchIrcClient client;

  setUp(() {
    client = TwitchIrcClient(
      username: 'bot',
      oauthToken: 'token',
      channel: 'channel',
    );
  });

  group('USERNOTICE parsing', () {
    test('parses a new subscription', () {
      final event = client.parseUserNotice(
        '@badges=subscriber/0;msg-id=sub;login=newbie;display-name=Newbie;'
        'msg-param-cumulative-months=1;tmi-sent-ts=1724320000000 '
        ':newbie!newbie@newbie.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(event, isNotNull);
      expect(event!.type, 'subscription');
      expect(event.user, 'newbie');
      expect(event.count, 1);
    });

    test('parses a resub with months and personal message', () {
      final event = client.parseUserNotice(
        '@badges=subscriber/12;msg-id=resub;login=veteran;display-name=Veteran;'
        'msg-param-cumulative-months=13;tmi-sent-ts=1724320000000 '
        ':veteran!veteran@veteran.tmi.twitch.tv USERNOTICE #channel :Love the streams!',
      );
      expect(event, isNotNull);
      expect(event!.type, 'resub');
      expect(event.user, 'veteran');
      expect(event.count, 13);
      expect(event.message, 'Love the streams!');
    });

    test('parses a raid with viewer count', () {
      final event = client.parseUserNotice(
        '@msg-id=raid;msg-param-viewerCount=42;tmi-sent-ts=1724320000000 '
        ':raider!raider@raider.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(event, isNotNull);
      expect(event!.type, 'raid');
      expect(event.count, 42);
    });

    test('ignores non-alert notice types (e.g. subgift is kept)', () {
      final gift = client.parseUserNotice(
        '@msg-id=subgift;msg-param-recipient-display-name=Lucky;'
        'tmi-sent-ts=1724320000000 '
        ':gifter!gifter@gifter.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(gift, isNotNull);
      expect(gift!.type, 'subscription');

      final routine = client.parseUserNotice(
        '@msg-id=ritual;tmi-sent-ts=1724320000000 '
        ':user!user@user.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(routine, isNull);
    });

    test('returns null for malformed lines', () {
      expect(client.parseUserNotice('garbage line'), isNull);
      expect(client.parseUserNotice(':x!x@x.tmi.twitch.tv USERNOTICE #c'), isNull);
    });
  });

  group('ChannelEvent JSON round-trip', () {
    test('fromJson/toJson preserves fields', () {
      const json = {
        'type': 'resub',
        'user': 'alice',
        'count': 6,
        'message': 'hi',
        'time': '12:00',
      };
      final event = ChannelEvent.fromJson(json);
      final out = event.toJson();
      expect(out['type'], 'resub');
      expect(out['user'], 'alice');
      expect(out['count'], 6);
      expect(out['message'], 'hi');
      expect(out['time'], '12:00');
    });

    test('omits null optionals in toJson', () {
      final event = ChannelEvent(type: 'raid', user: 'bob', time: '01:00');
      expect(event.toJson().containsKey('count'), isFalse);
      expect(event.toJson().containsKey('message'), isFalse);
    });
  });
}
