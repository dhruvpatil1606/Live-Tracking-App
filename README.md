# Flutter Live Location Tracking Application

A clean, production-grade single-screen Flutter application that implements real-time user location tracking on a Google Map interface. The camera and user marker dynamically follow movement smoothly while strictly managing resources and edge-case exceptions.

---

## 🚀 Features & Acceptance Criteria Met

*   **Smooth Live Tracking:** Listens to a continuous location stream, dynamically shifting the custom map marker and smoothly animating the map camera as coordinates change.
*   **Graceful Permission & Exception Handling:** Built-in validation checks for both runtime permission denial and disabled location services, presenting a polished custom UI fallback instead of application crashes.
*   **Zero Resource Leaks:** Strictly controls stream lifecycles by safely canceling active subscriptions when moving away from the tracking interface.

---

## 📱 Application Preview

### Active Tracking & Fallback States
| Live Tracking Active Image 1 | Live Tracking Active Image 2 | Smooth Camera Movement | Service Disabled Fallback |
| :---: | :---: | :---: | :---: |
| <img width="300" src="https://github.com/user-attachments/assets/e60ba402-19c1-418a-83c5-bf8876dcc233" /> | <img width="300" src="https://github.com/user-attachments/assets/d88c9849-9d2d-4ae0-8ed1-5037fc2594e4" /> | <img width="300" src="https://github.com/user-attachments/assets/01208f88-8184-4419-8804-5045457e1158" /> | <img width="300" src="https://github.com/user-attachments/assets/ec7da4e9-bdb8-4e46-a2a5-3e7bdae08fb5" /> |

### Full Demo Video
*(Real-time marker updates and smooth camera tracking)*

https://github.com/user-attachments/assets/f32aacd9-698b-47bb-b3cd-b459fd3166aa

---

## 🛠️ Technical Implementation Breakdown

### 1. Project Dependencies
Leverages official and community-trusted packages for robust geospatial mapping and tracking capabilities:
*   `google_maps_flutter` — Handles native Map rendering and camera manipulations.
*   `geolocator` — Interface for device-level GPS polling and position event streams.

### 2. Live Geolocation Stream Configuration

The position stream is initialized inside the `TrackingViewModel.startTracking()` method (following the MVVM pattern) using optimal tracking filters to balance battery optimization and tracking accuracy:

```dart
_positionStreamSubscription = Geolocator.getPositionStream(
  locationSettings: locationSettings,
).listen(
  (Position position) {
    _currentPosition = position;
    _status = TrackingStatus.tracking;
    _errorMessage = null;
    notifyListeners();
  },
  onError: (error) { ... },
);
```

### 3. Graceful Lifecycle Cleanup

This ViewModel disposal is triggered by the UI view state's `dispose()` method in `TrackingViewPage`:

```dart
@override
void dispose() {
  _viewModel.removeListener(_onViewModelChanged);
  _viewModel.dispose(); // Dismantling subscriptions inside the ViewModel
  _mapController?.dispose();
  _markerAnimationController?.dispose();
  super.dispose();
}
```

---

## 🏁 Getting Started & Setup

### Prerequisites
*   Flutter SDK installed on your local development machine.
*   A valid **Google Maps API Key** configured with permissions for the Maps SDK (Android/iOS).

### Installation & Run Steps
1. Clone this repository to your workspace:
```bash
   git clone <your-repository-url>
   cd <project-directory-name>
```

2. Fetch dependencies:
```bash
   flutter pub get
```

3. Configure your Google Maps API key:
  * **Android:** Add your API key to `android/secrets.properties` as `MAPS_API_KEY=Your_api_key`
   * **iOS:** Add your API key to `ios/Flutter/Secrets.xcconfig` as `MAPS_API_KEY=Your_api_key`

4. Deploy the application to a connected emulator or real device:
```bash
   flutter run
```
