import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum TrackingStatus {
  loading,
  permissionDenied,
  serviceDisabled,
  tracking,
  error
}

class TrackingViewModel extends ChangeNotifier {
  Position? _currentPosition;
  TrackingStatus _status = TrackingStatus.loading;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  // Getters
  Position? get currentPosition => _currentPosition;
  TrackingStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == TrackingStatus.loading;
  bool get hasError => _status == TrackingStatus.error || _status == TrackingStatus.permissionDenied || _status == TrackingStatus.serviceDisabled;

  /// Starts the tracking workflow: requests/checks permissions, checks service,
  /// and subscribes to the live location stream.
  Future<void> startTracking() async {
    _status = TrackingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check and request location permissions first
      var permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = TrackingStatus.permissionDenied;
          _errorMessage = 'Location permission was denied. We need this permission to show your live location on the map.';
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _status = TrackingStatus.permissionDenied;
        _errorMessage = 'Location permission is permanently denied. Please enable location access in system settings to use live tracking.';
        notifyListeners();
        return;
      }

      // 2. Continuous monitoring of Location Services (GPS) state changes
      _serviceStatusSubscription?.cancel();
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        if (status == ServiceStatus.disabled) {
          _currentPosition = null;
          _status = TrackingStatus.serviceDisabled;
          _errorMessage = 'Location services are disabled. Please enable them in your device settings.';
          notifyListeners();
        } else if (status == ServiceStatus.enabled) {
          startTracking(); // Automatically resume tracking when GPS is turned back on
        }
      });

      // 3. Check if location services (GPS) are enabled right now
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _status = TrackingStatus.serviceDisabled;
        _errorMessage = 'Location services are disabled. Please enable them in your device settings.';
        notifyListeners();
        return;
      }

      // 4. Permissions and services are active, start subscribing to the position stream
      _status = TrackingStatus.tracking;
      _errorMessage = null;
      notifyListeners();

      // Cancel any existing subscription before starting a new one
      await _positionStreamSubscription?.cancel();

      // Configure location settings (high accuracy, updates every 10 meters)
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          _status = TrackingStatus.tracking;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          _status = TrackingStatus.error;
          _errorMessage = 'Error receiving location updates: ${error.toString()}';
          notifyListeners();
        },
      );
    } catch (e) {
      _status = TrackingStatus.error;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Opens the device settings for location services or app settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Manually stops tracking and cancels the subscription
  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    await _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    _currentPosition = null;
    _status = TrackingStatus.loading;
    notifyListeners();
  }

  @override
  void dispose() {
    // Crucial: Cancel all active subscriptions to prevent memory and stream leaks
    _positionStreamSubscription?.cancel();
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }
}
