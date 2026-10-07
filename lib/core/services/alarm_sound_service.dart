import 'alarm_sound_stub.dart'
    if (dart.library.html) 'alarm_sound_web.dart' as platform_alarm;

class AlarmSoundService {
  static void play() {
    platform_alarm.playAlarmAudio();
  }

  static void stop() {
    platform_alarm.stopAlarmAudio();
  }
}
