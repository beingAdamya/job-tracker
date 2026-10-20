import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:job_tracker/main.dart';

void main() {
  testWidgets('App shows title and both tabs', (WidgetTester tester) async {
    // Pretend the phone's storage is empty, and the battery question
    // was already answered (so no dialog appears)
    SharedPreferences.setMockInitialValues({'battery_prompt_shown': true});

    await tester.pumpWidget(const JobTrackerApp());
    await tester.pump(); // let the first frame finish

    expect(find.text('Job Tracker'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Companies'), findsOneWidget);
  });
}