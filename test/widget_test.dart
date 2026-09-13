import 'package:flutter_test/flutter_test.dart';

import 'package:mail_checker_app/main.dart';

void main() {
  testWidgets('shows Google Sign-In entry screen', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.text('Mail Checker'), findsOneWidget);
    expect(
      find.text('Sign in with Google to load your Gmail inbox.'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(
      find.text('Complete the Google Cloud setup in README.md, then sign in.'),
      findsOneWidget,
    );
  });
}
