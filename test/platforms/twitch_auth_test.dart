import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/platforms/twitch_auth.dart';

void main() {
  late TwitchAuth auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = TwitchAuth();
    auth.configure(
      clientId: 'test-client-id',
      clientSecret: 'test-client-secret',
    );
  });

  group('TwitchAuth', () {
    test('authorizationUrl contains correct base URL', () {
      final url = auth.authorizationUrl;
      expect(url.startsWith('https://id.twitch.tv/oauth2/authorize'), true);
    });

    test('authorizationUrl includes all required scopes', () {
      final url = auth.authorizationUrl;
      // Scopes are URL-encoded in the query string
      expect(url.contains('chat%3Aread'), true);
      expect(url.contains('chat%3Aedit'), true);
      expect(url.contains('channel%3Amoderate'), true);
      expect(url.contains('moderator%3Amanage%3Abanned_users'), true);
    });

    test('authorizationUrl includes client_id and redirect_uri', () {
      final url = auth.authorizationUrl;
      expect(url.contains('client_id=test-client-id'), true);
      expect(url.contains('redirect_uri=http%3A%2F%2Flocalhost%3A8511%2Fauth%2Fcallback'), true);
    });

    test('isAuthenticated returns false before exchange', () {
      expect(auth.isAuthenticated, false);
    });

    test('clearTokens resets all state', () async {
      // Set up some state first
      auth.configure(clientId: 'cid', clientSecret: 'cs');
      // Manually set tokens (simulating what exchangeCode would do)
      // We can't easily call exchangeCode without HTTP, so test clearTokens
      // by first saving then clearing
      SharedPreferences.setMockInitialValues({
        'twitch_access_token': 'test-token',
        'twitch_refresh_token': 'test-refresh',
      });
      await auth.loadTokens();
      expect(auth.isAuthenticated, true);

      await auth.clearTokens();
      expect(auth.isAuthenticated, false);
      expect(auth.accessToken, isNull);
    });

    test('ensureValidToken returns false when no token', () async {
      final valid = await auth.ensureValidToken();
      expect(valid, false);
    });

    test('loadCredentials loads saved client ID and secret', () async {
      SharedPreferences.setMockInitialValues({
        'twitch_client_id': 'saved-cid',
        'twitch_client_secret': 'saved-cs',
      });

      final loaded = await auth.loadCredentials();
      expect(loaded, true);

      // Verify by checking authorizationUrl includes the loaded client ID
      final url = auth.authorizationUrl;
      expect(url.contains('client_id=saved-cid'), true);
    });

    test('loadCredentials returns false when no saved credentials', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await auth.loadCredentials();
      expect(loaded, false);
    });

    test('saveChannelName and loadChannelName round-trip', () async {
      SharedPreferences.setMockInitialValues({});

      await auth.saveChannelName('mystream');
      final loaded = await auth.loadChannelName();

      expect(loaded, 'mystream');
    });

    test('loadChannelName returns null when not saved', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await auth.loadChannelName();
      expect(loaded, isNull);
    });
  });
}
