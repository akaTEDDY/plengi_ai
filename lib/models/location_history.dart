import 'package:hive/hive.dart';

part 'location_history.g.dart';

@HiveType(typeId: 3)
class LocationHistory extends HiveObject {
  @HiveField(0)
  final Map<String, dynamic>? location;

  @HiveField(1)
  final Map<String, dynamic>? place;

  @HiveField(2)
  final Map<String, dynamic>? district;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String formattedTime;

  LocationHistory({
    required this.location,
    this.place,
    this.district,
    required this.timestamp,
    required this.formattedTime,
  });

  factory LocationHistory.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return LocationHistory(
      location: json['location'] as Map<String, dynamic>?,
      place: json['place'] as Map<String, dynamic>?,
      district: json['district'] as Map<String, dynamic>?,
      timestamp: now,
      formattedTime:
          '${now.year}/${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'place': place,
      'district': district,
      'timestamp': timestamp.toIso8601String(),
      'formattedTime': formattedTime,
    };
  }

  String get displayName {
    if (place != null && place!['name'] != null) {
      return '${place!['name']}(${place!['address']}), lat: ${location!['lat']}, lng: ${location!['lng']}';
    }
    if (location != null) {
      return 'lat: ${location!['lat']}, lng: ${location!['lng']}, accuracy: ${location!['accuracy']}';
    }
    if (district != null) {
      final lv2 = district!['lv2_name'];
      final lv3 = district!['lv3_name'];
      if (lv2 != null && lv3 != null) {
        return '$lv2 $lv3';
      }
    }
    return '';
  }
}
