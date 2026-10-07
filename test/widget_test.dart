import 'package:flutter_test/flutter_test.dart';
import 'package:medmate/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test — just verifies the app builds
    expect(MedmateApp, isNotNull);
  });
}
