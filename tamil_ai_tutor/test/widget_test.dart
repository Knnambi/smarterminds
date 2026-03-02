// Basic smoke test — verifies the app boots without crashing.
import 'package:flutter_test/flutter_test.dart';
import 'package:tamil_ai_tutor/main.dart';

void main() {
  testWidgets('App launches and shows app bar', (WidgetTester tester) async {
    await tester.pumpWidget(const TamilAITutorApp());
    expect(find.text('Tamil AI Tutor'), findsOneWidget);
  });
}
