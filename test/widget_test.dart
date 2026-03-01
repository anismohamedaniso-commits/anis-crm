// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:anis_crm/main.dart';
import 'package:anis_crm/state/app_state.dart';

void main() {
  testWidgets('App smoke test – widget builds', (WidgetTester tester) async {
    final appState = AppState();
    await tester.pumpWidget(MyApp(appState: appState));

    // App should render without crashing.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
