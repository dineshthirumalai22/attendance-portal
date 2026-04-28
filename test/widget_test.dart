import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/main.dart';

void main() {
  testWidgets('Attendance App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AttendanceApp());

    // Verify that our title is present.
    expect(find.text('Attendance Portal'), findsOneWidget);
  });
}
