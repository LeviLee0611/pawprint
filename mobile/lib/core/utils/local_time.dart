import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// 기기 IANA 시간대를 명시적으로 읽어 로컬 날짜/시간을 계산한다.
/// main()에서 initialize()를 먼저 호출해야 한다.
class LocalTime {
  static late tz.Location _location;

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      _location = tz.getLocation(name);
    } catch (_) {
      _location = tz.UTC;
    }
  }

  /// 현재 로컬 날짜+시간 (일반 DateTime 반환)
  static DateTime get now {
    final t = tz.TZDateTime.now(_location);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  /// 오늘 날짜만 (시간 00:00:00)
  static DateTime get today {
    final t = tz.TZDateTime.now(_location);
    return DateTime(t.year, t.month, t.day);
  }

  /// UTC DateTime → 로컬 DateTime 변환
  static DateTime toLocal(DateTime utc) {
    final t = tz.TZDateTime.from(utc, _location);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }
}
