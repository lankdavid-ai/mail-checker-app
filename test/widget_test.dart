// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mail_checker_app/main.dart';

void main() {
  testWidgets('shows Google sign-in prompt when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: MailCheckerHomePage(
          isSignedIn: false,
          isLoading: false,
          emails: <MailMessageSummary>[],
          onRefresh: _noop,
          onSignIn: _noop,
          onSignOut: _noop,
        ),
      ),
    );

    expect(find.text('Mail Checker'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(
      find.text('Sign in with Google to load recent emails from your Gmail inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('shows fetched emails and logout action when signed in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: MailCheckerHomePage(
          isSignedIn: true,
          isLoading: false,
          displayName: 'Flutter Tester',
          emails: <MailMessageSummary>[
            MailMessageSummary(
              sender: 'alice@example.com',
              subject: 'Welcome',
              preview: 'Thanks for trying the Gmail integration.',
            ),
          ],
          onRefresh: _noop,
          onSignIn: _noop,
          onSignOut: _noop,
        ),
      ),
    );

    expect(find.text('Signed in as Flutter Tester'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(
      find.text('Thanks for trying the Gmail integration.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Logout'), findsOneWidget);
  });
}

class TestApp extends StatelessWidget {
  const TestApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: child);
  }
}

Future<void> _noop() async {}
