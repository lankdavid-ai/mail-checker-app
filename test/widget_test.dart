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

  test('controller reports cancelled sign-in', () async {
    final controller = MailCheckerController(
      signInAction: () async => null,
    );

    await controller.signIn();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(controller.statusMessage, 'Google Sign-In was cancelled.');
  });

  test('controller loads inbox after successful sign-in', () async {
    final emails = [
      const InboxEmail(
        subject: 'Subject',
        from: 'sender@example.com',
        snippet: 'Preview',
      ),
    ];
    final controller = MailCheckerController(
      signInAction: () async => Object(),
      loadInboxAction: (_) async => emails,
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, emails);
    expect(controller.statusMessage, 'Loaded 1 Gmail messages.');
  });

  test('controller reports Gmail loading errors', () async {
    final controller = MailCheckerController(
      signInAction: () async => Object(),
      loadInboxAction: (_) async => throw Exception('boom'),
    );

    await controller.signIn();

    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Google Sign-In or Gmail loading failed.',
    );
    expect(controller.errorMessage, contains('boom'));
  });
}
