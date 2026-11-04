import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'alarm_sound_stub.dart'
    if (dart.library.html) 'alarm_sound_web.dart' as platform_alarm;

class AlarmSoundService {
  static const MethodChannel _channel = MethodChannel('com.medmate.medmate/alarm');

  static void play() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('playAlarm');
        return;
      } catch (e) {
        debugPrint('AlarmSoundService: Native alarm error: $e');
      }
    }
    platform_alarm.playAlarmAudio();
  }

  static void stop() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('stopAlarm');
        return;
      } catch (e) {
        debugPrint('AlarmSoundService: Native alarm stop error: $e');
      }
    }
    platform_alarm.stopAlarmAudio();
  }
}
