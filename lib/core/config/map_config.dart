import 'package:optivus2/core/config/app_config.dart';

class MapConfig {
  const MapConfig._();

  static const _config = AppBuildConfig.current;

  static String get mapboxAccessToken => _config.mapbox.normalizedAccessToken;

  static bool get hasMapboxAccessToken => mapboxAccessToken.isNotEmpty;

  static String get mapboxTileUrl => _config.mapbox.tileUrl;
}
