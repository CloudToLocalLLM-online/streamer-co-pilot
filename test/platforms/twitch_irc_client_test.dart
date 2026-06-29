import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/models/chat_message.dart';
import 'package:streamer_co_pilot/platforms/twitch_irc_client.dart';

void main() {
  late TwitchIrcClient client;

  setUp(() {
    client = TwitchIrcClient(
      username: 'testbot',
      oauthToken: 'oauth:testtoken',
      channel: 'testchannel',
    );
  });

  group('TwitchIrcClient message parsing', () {
    test('Parse PRIVMSG with tags (mod, sub, vip, broadcaster)', () {
      const line =
          '@badges=broadcaster/1;color=#FF0000;display-name=TestUser;mod=1;subscriber=1;vip=1 :testuser!testuser@testuser.tmi.twitch.tv PRIVMSG #testchannel :Hello everyone!';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'testuser');
      expect(msg.text, 'Hello everyone!');
      expect(msg.isMod, true);
      expect(msg.isSub, true);
      expect(msg.isVip, true);
      expect(msg.isBroadcaster, true);
    });

    test('Parse PRIVMSG without tags', () {
      const line =
          ':justauser!justauser@justauser.tmi.twitch.tv PRIVMSG #testchannel :Hello without tags';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'justauser');
      expect(msg.text, 'Hello without tags');
      expect(msg.isMod, false);
      expect(msg.isSub, false);
      expect(msg.isVip, false);
      expect(msg.isBroadcaster, false);
      expect(msg.time, '');
    });

    test('Parse PRIVMSG with tmi-sent-ts timestamp', () {
      // 1700000000000 ms since epoch = 2023-11-14 22:13:20 UTC
      const line =
          '@tmi-sent-ts=1700000000000;badges=;color= :timeduser!timeduser@timeduser.tmi.twitch.tv PRIVMSG #testchannel :Timed message';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'timeduser');
      expect(msg.text, 'Timed message');
      // 1700000000000 ms = 2023-11-14 22:13:20 UTC
      // The time is formatted in local timezone, so just check it's non-empty
      // and contains a colon (HH:MM format)
      expect(msg.time, isNotEmpty);
      expect(msg.time, contains(':'));
    });

    test('Handle malformed line gracefully (no crash)', () {
      // Missing username
      const line = 'PRIVMSG #channel :hello';
      final msg = client.parsePrivMsg(line);
      expect(msg, isNull);
    });

    test('Handle empty lines gracefully', () {
      const line = '';
      final msg = client.parsePrivMsg(line);
      expect(msg, isNull);
    });

    test('sendMessage() returns false when not connected', () async {
      final result = await client.sendMessage('test message');
      expect(result, false);
    });
  });
}
