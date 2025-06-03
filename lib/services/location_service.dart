import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class LocationService {
  Future<bool> checkLocationPermission() async {
    // print('LocationService: 권한 체크 시작'); // 디버깅 로그 주석 처리
    if (Platform.isIOS) {
      // print('LocationService: iOS 권한 체크'); // 디버깅 로그 주석 처리
      return _checkIOSPermissions();
    } else {
      // print('LocationService: Android 권한 체크'); // 디버깅 로그 주석 처리
      return _checkAndroidPermissions();
    }
  }

  Future<bool> _checkIOSPermissions() async {
    // print('LocationService: iOS 권한 상세 체크'); // 디버깅 로그 주석 처리
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    // print('LocationService: iOS 위치 서비스 상태: $serviceEnabled'); // 디버깅 로그 주석 처리
    if (!serviceEnabled) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    // print('LocationService: iOS 위치 권한 상태: $permission'); // 디버깅 로그 주석 처리
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<bool> _checkAndroidPermissions() async {
    // print('LocationService: Android 권한 상세 체크'); // 디버깅 로그 주석 처리
    final locationStatus = await Permission.location.status;
    final backgroundStatus = await Permission.locationAlways.status;
    final notificationStatus = await Permission.notification.status;
    // print(
    //   'LocationService: Android 권한 상태 - 위치: $locationStatus, 백그라운드: $backgroundStatus, 알림: $notificationStatus',
    // ); // 디버깅 로그 주석 처리

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    // print('LocationService: Android 위치 서비스 상태: $serviceEnabled'); // 디버깅 로그 주석 처리
    if (!serviceEnabled) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    // print('LocationService: Android 위치 권한 상태: $permission'); // 디버깅 로그 주석 처리
    final hasLocationPermission =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (Platform.isAndroid && await _isAndroid10OrHigher()) {
      // print('LocationService: Android 10 이상 - 백그라운드 권한 필요'); // 디버깅 로그 주석 처리
      return hasLocationPermission && backgroundStatus.isGranted;
    }

    return hasLocationPermission;
  }

  Future<bool> requestLocationPermission() async {
    // print('LocationService: 권한 요청 시작'); // 디버깅 로그 주석 처리
    if (Platform.isIOS) {
      // print('LocationService: iOS 권한 요청'); // 디버깅 로그 주석 처리
      return _requestIOSPermissions();
    } else {
      // print('LocationService: Android 권한 요청'); // 디버깅 로그 주석 처리
      return _requestAndroidPermissions();
    }
  }

  Future<bool> _requestIOSPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> _requestAndroidPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 1. 기본 위치 권한 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // 2. Notification 권한 요청
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      // Notification 권한이 거부되어도 위치 기능은 동작하므로 계속 진행
    }

    // 3. Android 10 이상에서 백그라운드 위치 권한 요청
    if (await _isAndroid10OrHigher()) {
      if (permission == LocationPermission.whileInUse) {
        // 잠시 대기하여 사용자가 기본 권한 요청을 처리할 시간을 줌
        await Future.delayed(const Duration(seconds: 1));

        final backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          // 백그라운드 권한이 거부되어도 기본 위치 권한은 있으므로 true 반환
          return true;
        }
      }
    }

    return true;
  }

  Future<bool> _isAndroid10OrHigher() async {
    if (Platform.isAndroid) {
      // Android 10은 API 레벨 29
      return await Permission.locationAlways.status.isGranted;
    }
    return false;
  }

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }
}
