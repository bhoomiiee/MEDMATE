// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> requestWebNotificationPermission() async {
  try {
    if (html.Notification.supported) {
      final perm = await html.Notification.requestPermission();
      return perm == 'granted';
    }
  } catch (_) {}
  return false;
}

void showWebNotification(String title, String body) {
  try {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (_) {}
}
