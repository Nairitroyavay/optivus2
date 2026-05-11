import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/controllers/fitness_map_controller.dart';
import 'package:optivus2/models/route_point_model.dart';

void main() {
  late FitnessMapController controller;

  setUp(() {
    controller = FitnessMapController();
  });

  RoutePointModel makePoint({
    double lat = 20.5937,
    double lon = 78.9629,
  }) {
    return RoutePointModel(
      pointId: 'pt_1',
      latitude: lat,
      longitude: lon,
      altitude: 0,
      accuracy: 5,
      speedMps: 3.0,
      timestamp: DateTime(2026, 5, 10, 12, 0),
      sequence: 0,
    );
  }

  group('initial state', () {
    test('followMode defaults to true', () {
      expect(controller.state.followMode, isTrue);
    });

    test('controlsLocked defaults to false', () {
      expect(controller.state.controlsLocked, isFalse);
    });

    test('metricsCollapsed defaults to false', () {
      expect(controller.state.metricsCollapsed, isFalse);
    });

    test('mapZoom defaults to 16', () {
      expect(controller.state.mapZoom, equals(16));
    });

    test('cameraCommandVersion starts at 0', () {
      expect(controller.state.cameraCommandVersion, equals(0));
    });

    test('cameraTarget starts null', () {
      expect(controller.state.cameraTarget, isNull);
    });
  });

  group('zoomIn', () {
    test('increments zoom by 1', () {
      controller.zoomIn();
      expect(controller.state.mapZoom, equals(17));
    });

    test('clamps at 20', () {
      // Set zoom near max
      for (var i = 0; i < 10; i++) {
        controller.zoomIn();
      }
      expect(controller.state.mapZoom, equals(20));
      controller.zoomIn();
      expect(controller.state.mapZoom, equals(20));
    });

    test('increments cameraCommandVersion', () {
      final before = controller.state.cameraCommandVersion;
      controller.zoomIn();
      expect(controller.state.cameraCommandVersion, equals(before + 1));
    });
  });

  group('zoomOut', () {
    test('decrements zoom by 1', () {
      controller.zoomOut();
      expect(controller.state.mapZoom, equals(15));
    });

    test('clamps at 3', () {
      for (var i = 0; i < 20; i++) {
        controller.zoomOut();
      }
      expect(controller.state.mapZoom, equals(3));
      controller.zoomOut();
      expect(controller.state.mapZoom, equals(3));
    });

    test('increments cameraCommandVersion', () {
      final before = controller.state.cameraCommandVersion;
      controller.zoomOut();
      expect(controller.state.cameraCommandVersion, equals(before + 1));
    });
  });

  group('recenter', () {
    test('sets followMode true and zoom to 17', () {
      controller.handleCameraMoveStarted(); // set followMode false
      expect(controller.state.followMode, isFalse);

      final point = makePoint();
      controller.recenter(point);
      expect(controller.state.followMode, isTrue);
      expect(controller.state.mapZoom, equals(17));
    });

    test('sets cameraTarget to the given point', () {
      final point = makePoint(lat: 12.9716, lon: 77.5946);
      controller.recenter(point);
      expect(controller.state.cameraTarget, equals(point));
    });

    test('increments cameraCommandVersion', () {
      final before = controller.state.cameraCommandVersion;
      controller.recenter(makePoint());
      expect(controller.state.cameraCommandVersion, equals(before + 1));
    });

    test('null point is a no-op', () {
      final before = controller.state;
      controller.recenter(null);
      expect(controller.state.cameraCommandVersion,
          equals(before.cameraCommandVersion));
    });
  });

  group('handleCameraMoveStarted', () {
    test('sets followMode to false', () {
      expect(controller.state.followMode, isTrue);
      controller.handleCameraMoveStarted();
      expect(controller.state.followMode, isFalse);
    });
  });

  group('follow', () {
    test('moves camera when followMode is true', () {
      final point = makePoint(lat: 28.6139, lon: 77.2090);
      final before = controller.state.cameraCommandVersion;
      controller.follow(point);
      expect(controller.state.cameraTarget, equals(point));
      expect(controller.state.cameraCommandVersion, equals(before + 1));
    });

    test('is no-op when followMode is false', () {
      controller.handleCameraMoveStarted();
      final before = controller.state.cameraCommandVersion;
      controller.follow(makePoint());
      expect(controller.state.cameraCommandVersion, equals(before));
    });

    test('is no-op when point is null', () {
      final before = controller.state.cameraCommandVersion;
      controller.follow(null);
      expect(controller.state.cameraCommandVersion, equals(before));
    });
  });

  group('toggleControlsLocked', () {
    test('toggles from false to true', () {
      expect(controller.state.controlsLocked, isFalse);
      controller.toggleControlsLocked();
      expect(controller.state.controlsLocked, isTrue);
    });

    test('toggles from true to false', () {
      controller.toggleControlsLocked();
      controller.toggleControlsLocked();
      expect(controller.state.controlsLocked, isFalse);
    });
  });

  group('toggleMetricsCollapsed', () {
    test('toggles from false to true', () {
      expect(controller.state.metricsCollapsed, isFalse);
      controller.toggleMetricsCollapsed();
      expect(controller.state.metricsCollapsed, isTrue);
    });

    test('toggles from true to false', () {
      controller.toggleMetricsCollapsed();
      controller.toggleMetricsCollapsed();
      expect(controller.state.metricsCollapsed, isFalse);
    });
  });

  group('toggleFollowMode', () {
    test('toggles from true to false', () {
      expect(controller.state.followMode, isTrue);
      controller.toggleFollowMode();
      expect(controller.state.followMode, isFalse);
    });

    test('toggles from false to true', () {
      controller.toggleFollowMode();
      controller.toggleFollowMode();
      expect(controller.state.followMode, isTrue);
    });
  });

  group('cycleMapType', () {
    test('is a no-op stub (does not crash)', () {
      // cycleMapType is a placeholder — verify it does not throw.
      expect(() => controller.cycleMapType(), returnsNormally);
    });
  });

  group('FitnessMapState.copyWith', () {
    test('preserves unchanged fields', () {
      const original = FitnessMapState(
        followMode: true,
        controlsLocked: true,
        metricsCollapsed: true,
        mapZoom: 14,
        cameraCommandVersion: 5,
      );
      final copy = original.copyWith(mapZoom: 18);
      expect(copy.followMode, isTrue);
      expect(copy.controlsLocked, isTrue);
      expect(copy.metricsCollapsed, isTrue);
      expect(copy.mapZoom, equals(18));
      expect(copy.cameraCommandVersion, equals(5));
    });
  });
}
