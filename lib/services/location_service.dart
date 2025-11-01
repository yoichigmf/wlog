import 'package:geolocator/geolocator.dart';

class LocationService {
  // 位置情報のパーミッションを確認・リクエスト
  static Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 位置情報サービスが有効か確認
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 位置情報サービスが無効の場合
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // パーミッションが拒否された
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // パーミッションが永続的に拒否された
      return false;
    }

    // パーミッションが許可された
    return true;
  }

  // 現在の位置情報を取得
  static Future<Position?> getCurrentLocation() async {
    try {
      // パーミッションを確認
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }

      // 現在位置を取得
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      return position;
    } catch (e) {
      // エラーが発生した場合はnullを返す
      return null;
    }
  }

  // 位置情報を取得（緯度・経度のペアで返す）
  static Future<LocationData?> getLocationData() async {
    final position = await getCurrentLocation();
    if (position != null) {
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
    return null;
  }

  // 位置情報サービスが有効かチェック
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // パーミッションステータスを取得
  static Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}

// 位置情報データクラス
class LocationData {
  final double latitude;
  final double longitude;

  LocationData({
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() {
    return '緯度: ${latitude.toStringAsFixed(6)}, 経度: ${longitude.toStringAsFixed(6)}';
  }

  // Google Mapsへのリンクを生成
  String toGoogleMapsUrl() {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
}
