import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/models/map_style_model.dart';

class MapConfig {
  const MapConfig._();

  static const _config = AppBuildConfig.current;

  static String get mapboxAccessToken => _config.mapbox.normalizedAccessToken;

  static bool get hasMapboxAccessToken => mapboxAccessToken.isNotEmpty;

  static String get mapboxTileUrl => _config.mapbox.tileUrl;

  static String tileUrlForStyle(MapboxStyle style) {
    return _config.mapbox.tileUrlForStyleUri(style.styleUri);
  }

  static String tileUrlForStyleUri(String styleUri) {
    return _config.mapbox.tileUrlForStyleUri(styleUri);
  }

  /// The package name sent as the User-Agent for tile requests.
  /// Update this when the final applicationId is set.
  static const String userAgentPackageName = 'com.example.optivus';
}
