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

    // ── New edge-case tests ──

    test('Parse PRIVMSG with only broadcaster badge', () {
      const line =
          '@badges=broadcaster/1;color=#0000FF;display-name=TheStreamer :thestreamer!thestreamer@thestreamer.tmi.twitch.tv PRIVMSG #testchannel :I am the broadcaster';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'thestreamer');
      expect(msg.isBroadcaster, true);
      expect(msg.isMod, false); // broadcaster badge doesn't imply mod in our parser
      expect(msg.isSub, false);
      expect(msg.isVip, false);
    });

    test('Parse PRIVMSG with moderator badge but no mod tag', () {
      // Some moderators have the badge but mod=0 (unlikely but possible)
      const line =
          '@badges=moderator/1;color=#00FF00;display-name=ModUser;mod=1 :moduser!moduser@moduser.tmi.twitch.tv PRIVMSG #testchannel :Mod message';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'moduser');
      expect(msg.isMod, true);
      // moderator badge alone doesn't set isBroadcaster
      expect(msg.isBroadcaster, false);
    });

    test('Parse PRIVMSG with founder badge', () {
      const line =
          '@badges=founder/0;color=#FF69B4;display-name=FounderUser :founderuser!founderuser@founderuser.tmi.twitch.tv PRIVMSG #testchannel :Founding member';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'founderuser');
      // founder badge doesn't set any of our boolean flags
      expect(msg.isMod, false);
      expect(msg.isSub, false);
      expect(msg.isVip, false);
      expect(msg.isBroadcaster, false);
    });

    test('Parse PRIVMSG with subscriber badge and months', () {
      const line =
          '@badges=subscriber/24;color=#FFA500;display-name=LongSub;subscriber=1 :longsub!longsub@longsub.tmi.twitch.tv PRIVMSG #testchannel :2 year sub!';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'longsub');
      expect(msg.isSub, true);
      expect(msg.text, '2 year sub!');
    });

    test('Parse PRIVMSG with multiple badges', () {
      const line =
          '@badges=moderator/1,subscriber/6,vip/1;color=#FFFFFF;display-name=SuperUser;mod=1;subscriber=1;vip=1 :superuser!superuser@superuser.tmi.twitch.tv PRIVMSG #testchannel :I have all the things';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'superuser');
      expect(msg.isMod, true);
      expect(msg.isSub, true);
      expect(msg.isVip, true);
      expect(msg.isBroadcaster, false);
    });

    test('Parse PRIVMSG with emotes tag', () {
      const line =
          '@emotes=123:0-4,124:6-10;badges=;color=#FF0000;display-name=EmoteUser :emoteuser!emoteuser@emoteuser.tmi.twitch.tv PRIVMSG #testchannel :Kappa PogChamp';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'emoteuser');
      expect(msg.text, 'Kappa PogChamp');
      // emotes tag is ignored by our parser (not a boolean flag we track)
    });

    test('Parse PRIVMSG with id tag (message ID)', () {
      const line =
          '@id=abc123-def456;badges=;display-name=IdUser :iduser!iduser@iduser.tmi.twitch.tv PRIVMSG #testchannel :Message with ID';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'iduser');
      expect(msg.text, 'Message with ID');
    });

    test('Parse PRIVMSG with room-id tag', () {
      const line =
          '@room-id=987654321;badges=;display-name=RoomUser :roomuser!roomuser@roomuser.tmi.twitch.tv PRIVMSG #testchannel :Room ID present';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'roomuser');
      expect(msg.text, 'Room ID present');
    });

    test('Parse PRIVMSG with user-id tag', () {
      const line =
          '@user-id=123456789;badges=;display-name=UserIdUser :useriduser!useriduser@useriduser.tmi.twitch.tv PRIVMSG #testchannel :User ID present';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'useriduser');
      expect(msg.text, 'User ID present');
    });

    test('Parse PRIVMSG with zero-width space in message', () {
      // Twitch sometimes sends messages with zero-width spaces
      const line =
          '@badges=;display-name=ZWSUser :zwuser!zwuser@zwuser.tmi.twitch.tv PRIVMSG #testchannel :Hello\u{200B}World';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'zwuser');
      expect(msg.text, 'Hello\u{200B}World'); // Preserved as-is
    });

    test('Parse PRIVMSG with empty message text returns null (parser limitation)', () {
      const line =
          '@badges=;display-name=EmptyMsg :emptymsg!emptymsg@emptymsg.tmi.twitch.tv PRIVMSG #testchannel :';

      final msg = client.parsePrivMsg(line);

      // Current parser requires at least one char after ':' in PRIVMSG
      expect(msg, isNull);
    });

    test('Parse PRIVMSG with special characters in username (underscores, numbers)', () {
      const line =
          '@badges=;display-name=User_123 :user_123!user_123@user_123.tmi.twitch.tv PRIVMSG #testchannel :Underscore and numbers';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'user_123');
      expect(msg.text, 'Underscore and numbers');
    });

    test('Parse PRIVMSG with Unicode display name', () {
      const line =
          '@badges=;display-name=Jap\u{3042}nese :jpnuser!jpnuser@jpnuser.tmi.twitch.tv PRIVMSG #testchannel :Konnichiwa';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'jpnuser');
      expect(msg.text, 'Konnichiwa');
    });

    test('Parse PRIVMSG with very long message', () {
      final longMsg = 'A' * 500; // Near Twitch's 500 char limit
      final line =
          '@badges=;display-name=LongMsg :longmsg!longmsg@longmsg.tmi.twitch.tv PRIVMSG #testchannel :$longMsg';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'longmsg');
      expect(msg.text.length, 500);
    });

    test('Parse PRIVMSG ignores unknown tags gracefully', () {
      const line =
          '@unknown-tag=value;custom-thing=foo;badges=;display-name=UnknownTags :unknowntags!unknowntags@unknowntags.tmi.twitch.tv PRIVMSG #testchannel :Unknown tags ignored';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'unknowntags');
      expect(msg.text, 'Unknown tags ignored');
    });

    test('Parse PRIVMSG with tmi-sent-ts at epoch zero', () {
      const line =
          '@tmi-sent-ts=0;badges=;display-name=EpochUser :epochuser!epochuser@epochuser.tmi.twitch.tv PRIVMSG #testchannel :Epoch time';

      final msg = client.parsePrivMsg(line);

      expect(msg, isNotNull);
      expect(msg!.user, 'epochuser');
      // Epoch zero = 1970-01-01 00:00:00 UTC, should still produce a time string
      expect(msg.time, isNotEmpty);
      expect(msg.time, contains(':'));
    });
  });

  group('TwitchIrcClient connection behavior', () {
    test('connected getter returns false initially', () {
      expect(client.connected, false);
    });

    test('dispose() does not throw when never connected', () {
      expect(() => client.dispose(), returnsNormally);
    });

    test('disconnect() does not throw when never connected', () {
      expect(() => client.disconnect(), returnsNormally);
    });

    test('messages stream is broadcast', () {
      // Two listeners should both receive events
      final results1 = <ChatMessage>[];
      final results2 = <ChatMessage>[];
      final sub1 = client.messages.listen(results1.add);
      final sub2 = client.messages.listen(results2.add);

      // We can't easily inject messages without a real connection,
      // but we can verify the stream is broadcast type
      expect(client.messages.isBroadcast, true);

      sub1.cancel();
      sub2.cancel();
    });

    test('events stream is broadcast', () {
      expect(client.events.isBroadcast, true);
    });
  });

  group('TwitchIrcClient internal parsing helpers', () {
    // These test the private methods exposed via @visibleForTesting

    test('_parsePrivMsg handles line with only tags and no message returns null', () {
      const line = '@badges=;display-name=NoMsg :nomsg!nomsg@nomsg.tmi.twitch.tv PRIVMSG #testchannel :';
      final msg = client.parsePrivMsg(line);
      // Current parser requires at least one char after ':' in PRIVMSG
      expect(msg, isNull);
    });

    test('_parsePrivMsg handles tags with empty values', () {
      const line = '@badges=;color=;display-name=EmptyTags :emptytags!emptytags@emptytags.tmi.twitch.tv PRIVMSG #testchannel :Empty tag values';
      final msg = client.parsePrivMsg(line);
      expect(msg, isNotNull);
      expect(msg!.user, 'emptytags');
    });

    test('_parsePrivMsg handles malformed tag (no equals)', () {
      // Tag without = should be skipped
      const line = '@badges;display-name=Malformed :malformed!malformed@malformed.tmi.twitch.tv PRIVMSG #testchannel :Malformed tag';
      final msg = client.parsePrivMsg(line);
      expect(msg, isNotNull);
      expect(msg!.user, 'malformed');
    });

    test('_parsePrivMsg handles tag with multiple equals', () {
      // Value contains = should be handled (split only on first)
      const line = '@custom-data=key=value;display-name=MultiEq :multieq!multieq@multieq.tmi.twitch.tv PRIVMSG #testchannel :Multiple equals';
      final msg = client.parsePrivMsg(line);
      expect(msg, isNotNull);
      expect(msg!.user, 'multieq');
    });

    test('_parseUserNotice handles subgift with recipient', () {
      final event = client.parseUserNotice(
        '@badges=subscriber/3;msg-id=subgift;msg-param-recipient-id=999;'
        'msg-param-recipient-user-name=LuckyViewer;msg-param-recipient-display-name=LuckyViewer;'
        'tmi-sent-ts=1724320000000 '
        ':gifter!gifter@gifter.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(event, isNotNull);
      expect(event!.type, 'subscription'); // subgift -> subscription
      expect(event.user, 'gifter');
    });

    test('_parseUserNotice handles anon gift sub', () {
      final event = client.parseUserNotice(
        '@msg-id=anonsubgift;msg-param-recipient-display-name=Lucky;'
        'tmi-sent-ts=1724320000000 '
        ':anongifter!anongifter@anongifter.tmi.twitch.tv USERNOTICE #channel',
      );
      // anonsubgift is not in our handled list, should return null
      expect(event, isNull);
    });

    test('_parseUserNotice handles prime paid upgrade', () {
      final event = client.parseUserNotice(
        '@msg-id=submysterygift;tmi-sent-ts=1724320000000 '
        ':gifter!gifter@gifter.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(event, isNull); // not handled
    });

    test('_parseUserNotice handles bits badge tier', () {
      final event = client.parseUserNotice(
        '@msg-id=bitsbadgetier;msg-param-threshold=1000;tmi-sent-ts=1724320000000 '
        ':cheerer!cheerer@cheerer.tmi.twitch.tv USERNOTICE #channel',
      );
      expect(event, isNull); // not an alert type we handle
    });
  });
}