import 'package:flutter/services.dart';

void playAlarmAudio() {
  SystemSound.play(SystemSoundType.alert);
  HapticFeedback.heavyImpact();
}

void stopAlarmAudio() {}
