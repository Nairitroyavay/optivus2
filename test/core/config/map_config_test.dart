import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/core/config/map_config.dart';
import 'package:optivus2/models/map_style_model.dart';

void main() {
  group('MapboxClientConfig', () {
    test('normalizedAccessToken trims whitespace', () {
      const config = MapboxClientConfig(accessToken: '  pk.abc123  ');
      expect(config.normalizedAccessToken, equals('pk.abc123'));
    });

    test('hasAccessToken is false when token is empty', () {
      const config = MapboxClientConfig(accessToken: '');
      expect(config.hasAccessToken, isFalse);
    });

    test('hasAccessToken is false when token is whitespace-only', () {
      const config = MapboxClientConfig(accessToken: '   ');
      expect(config.hasAccessToken, isFalse);
    });

    test('hasAccessToken is true when token is present', () {
      const config = MapboxClientConfig(accessToken: 'pk.test_token');
      expect(config.hasAccessToken, isTrue);
    });

    test('tileUrl contains the access token', () {
      const config = MapboxClientConfig(accessToken: 'pk.mytoken');
      expect(config.tileUrl, contains('access_token=pk.mytoken'));
    });

    test('tileUrl uses the normalized access token', () {
      const config = MapboxClientConfig(accessToken: '  pk.trimmed  ');
      expect(config.tileUrl, contains('access_token=pk.trimmed'));
      expect(config.tileUrl, isNot(contains('  pk.trimmed  ')));
    });

    test('tileUrl defaults to Coral style', () {
      const config = MapboxClientConfig(accessToken: 'pk.test');
      expect(config.tileUrl, contains('nairitroy'));
      expect(config.tileUrl, contains('cmozyqm88000c01r14o8h7bn0'));
    });

    test('tileUrl contains mapbox API host', () {
      const config = MapboxClientConfig(accessToken: 'pk.test');
      expect(config.tileUrl, contains('api.mapbox.com'));
    });

    test('tileUrl has z/x/y template placeholders', () {
      const config = MapboxClientConfig(accessToken: 'pk.test');
      expect(config.tileUrl, contains('{z}'));
      expect(config.tileUrl, contains('{x}'));
      expect(config.tileUrl, contains('{y}'));
    });

    test('tileUrl ends with empty token param when token is absent', () {
      const config = MapboxClientConfig(accessToken: '');
      expect(config.tileUrl, endsWith('access_token='));
    });

    test('style tile URL remains buildable when token is absent', () {
      const config = MapboxClientConfig(accessToken: '');
      expect(
        config.tileUrlForStyleUri(MapboxStyles.satellite.styleUri),
        endsWith('access_token='),
      );
    });

    test('tileUrlForStyleUri converts Mapbox style URI to raster tiles', () {
      const config = MapboxClientConfig(accessToken: 'pk.test');
      expect(
        config.tileUrlForStyleUri(
          'mapbox://styles/nairitroy/cmp00db5a000r01pe3pea1r0k',
        ),
        equals(
          'https://api.mapbox.com/styles/v1/nairitroy/cmp00db5a000r01pe3pea1r0k/tiles/256/{z}/{x}/{y}@2x?access_token=pk.test',
        ),
      );
    });

    test('tileUrlForStyleUri rejects non-Mapbox style URIs', () {
      const config = MapboxClientConfig(accessToken: 'pk.test');
      expect(
        () => config.tileUrlForStyleUri('https://example.com/style'),
        throwsArgumentError,
      );
    });
  });

  group('MapConfig', () {
    test('userAgentPackageName is non-empty', () {
      expect(MapConfig.userAgentPackageName, isNotEmpty);
    });

    test('userAgentPackageName matches expected format', () {
      // Package names follow reverse-DNS notation
      expect(MapConfig.userAgentPackageName, contains('.'));
    });

    test('userAgentPackageName matches the current Android applicationId', () {
      expect(MapConfig.userAgentPackageName, equals('com.example.optivus'));
    });

    test('hasMapboxAccessToken reflects compile-time token state', () {
      // In test environment, MAPBOX_ACCESS_TOKEN is not set via dart-define,
      // so hasMapboxAccessToken should be false.
      expect(MapConfig.hasMapboxAccessToken, isFalse);
    });

    test('mapboxAccessToken is empty when no dart-define is set', () {
      // In test environment, no MAPBOX_ACCESS_TOKEN is passed.
      expect(MapConfig.mapboxAccessToken, isEmpty);
    });
  });

  group('MapboxStyles', () {
    test('Coral is the default style', () {
      expect(MapboxStyles.defaultStyle.id, MapboxStyleId.coral);
      expect(MapboxStyles.defaultStyle.displayName, 'Coral');
    });

    test('contains the four allowed style ids', () {
      expect(
        MapboxStyles.values.map((style) => style.storageId),
        ['coral', 'monoLight', 'satellite', 'energy'],
      );
    });

    test('invalid style id falls back to Coral', () {
      expect(MapboxStyles.byStorageId('unknown').id, MapboxStyleId.coral);
    });

    test('preference map stores no Mapbox token', () {
      final data = MapboxStyles.energy.toPreferenceMap(updatedAt: 'now');
      expect(data['selectedStyleId'], 'energy');
      expect(data['selectedStyleUri'], MapboxStyles.energy.styleUri);
      expect(data.keys, isNot(contains('accessToken')));
      expect(data.toString(), isNot(contains('pk.')));
    });

    test('no forbidden map dependency or path exists', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('google_' 'maps_flutter')));
      expect(pubspec, isNot(contains('Google ' 'Maps API')));
    });
  });
}
