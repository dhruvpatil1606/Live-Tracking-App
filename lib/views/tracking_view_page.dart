import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../viewmodels/tracking_viewmodel.dart';

class TrackingViewPage extends StatefulWidget {
  const TrackingViewPage({super.key});

  @override
  State<TrackingViewPage> createState() => _TrackingViewPageState();
}

class _TrackingViewPageState extends State<TrackingViewPage> with TickerProviderStateMixin {
  late final TrackingViewModel _viewModel;
  GoogleMapController? _mapController;
  AnimationController? _markerAnimationController;
  Animation<double>? _markerAnimation;
  LatLng? _animatedLatLng;
  LatLng? _targetLatLng;

  @override
  void initState() {
    super.initState();
    _viewModel = TrackingViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.startTracking();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _mapController?.dispose();
    _markerAnimationController?.dispose();
    super.dispose();
  }

  void _onViewModelChanged() async {
    final newPosition = _viewModel.currentPosition;
    if (newPosition != null) {
      final newLatLng = LatLng(newPosition.latitude, newPosition.longitude);
      
      if (newLatLng != _targetLatLng) {
        final isFirstLocation = _targetLatLng == null;
        final startLatLng = _animatedLatLng ?? _targetLatLng ?? newLatLng;
        _targetLatLng = newLatLng;
        
        if (isFirstLocation) {
          setState(() {
            _animatedLatLng = newLatLng;
          });
        } else {
          _animateMarker(startLatLng, _targetLatLng!);
        }
        
        // Fetch current camera zoom dynamically, defaulting to 16.5
        double currentZoom = 16.5;
        if (_mapController != null) {
          try {
            currentZoom = await _mapController!.getZoomLevel();
          } catch (_) {
            // Keep default zoom if map is not ready
          }
        }
        
        // Smoothly animate the camera to the new location while preserving user's zoom
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newLatLng,
              zoom: currentZoom,
            ),
          ),
        );
      }
    }
  }

  void _animateMarker(LatLng from, LatLng to) {
    _markerAnimationController?.stop();
    _markerAnimationController?.dispose();
    
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800), // Smooth 800ms transition
      vsync: this,
    );
    
    _markerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _markerAnimationController!,
        curve: Curves.easeInOut,
      ),
    )..addListener(() {
        if (!mounted) return;
        final value = _markerAnimation!.value;
        final lat = from.latitude + (to.latitude - from.latitude) * value;
        final lng = from.longitude + (to.longitude - from.longitude) * value;
        
        setState(() {
          _animatedLatLng = LatLng(lat, lng);
        });
      });
      
    _markerAnimationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.status != TrackingStatus.tracking) {
            _mapController = null;
            _targetLatLng = null;
            _animatedLatLng = null;
          }
          
          switch (_viewModel.status) {
            case TrackingStatus.loading:
              return _buildLoadingState();
            case TrackingStatus.permissionDenied:
            case TrackingStatus.serviceDisabled:
            case TrackingStatus.error:
              return _buildFallbackState();
            case TrackingStatus.tracking:
              if (_viewModel.currentPosition == null) {
                return _buildLoadingState();
              }
              return _buildMapState();
          }
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
          ),
          SizedBox(height: 16),
          Text(
            'Initializing location tracking...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackState() {
    IconData errorIcon = Icons.error_outline;
    bool showSettingsButton = false;
    bool isPermissionDenied = _viewModel.status == TrackingStatus.permissionDenied;
    
    if (isPermissionDenied) {
      errorIcon = Icons.location_off_outlined;
      showSettingsButton = true;
    } else if (_viewModel.status == TrackingStatus.serviceDisabled) {
      errorIcon = Icons.gps_off_outlined;
      showSettingsButton = true;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              errorIcon,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'Action Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _viewModel.errorMessage ?? 'Something went wrong while fetching location.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showSettingsButton) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (isPermissionDenied) {
                        await Geolocator.openAppSettings();
                      } else {
                        await _viewModel.openLocationSettings();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Settings'),
                  ),
                  const SizedBox(width: 16),
                ],
                ElevatedButton.icon(
                  onPressed: () => _viewModel.startTracking(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapState() {
    final position = _viewModel.currentPosition!;
    final latLng = LatLng(position.latitude, position.longitude);
    final markerLatLng = _animatedLatLng ?? latLng;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: latLng,
            zoom: 16.5,
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          markers: {
            Marker(
              markerId: const MarkerId('current_user_marker'),
              position: markerLatLng,
              infoWindow: const InfoWindow(title: 'My Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          },
          myLocationEnabled: false, // Custom blue marker is used
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false, // Disable navigation toolbar when marker is selected
        ),
        // Overlay showing location details
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.navigation, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Tracking Active',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
