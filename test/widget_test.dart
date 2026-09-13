import 'package:flutter_test/flutter_test.dart';

import 'package:mail_checker_app/main.dart';

void main() {
  testWidgets('shows Google Sign-In entry screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

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

  test('controller reports an empty inbox after sign-in', () async {
    final controller = MailCheckerController(
      signInAction: () async => const _FakeMailCheckerAccount(),
      loadInboxAction: (_) async => const <InboxEmail>[],
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Signed in successfully, but the inbox is empty.',
    );
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
      signInAction: () async => const _FakeMailCheckerAccount(),
      loadInboxAction: (_) async => emails,
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, emails);
    expect(controller.statusMessage, 'Loaded 1 Gmail messages.');
  });

  test('InboxEmail compares by value', () {
    const first = InboxEmail(
      subject: 'Subject',
      from: 'sender@example.com',
      snippet: 'Preview',
    );
    const second = InboxEmail(
      subject: 'Subject',
      from: 'sender@example.com',
      snippet: 'Preview',
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('controller reports Gmail loading errors after sign-in', () async {
    final controller = MailCheckerController(
      signInAction: () async => const _FakeMailCheckerAccount(),
      loadInboxAction: (_) async => throw Exception('boom'),
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Signed in, but Gmail loading failed.',
    );
    expect(controller.errorMessage, contains('boom'));
  });

  test('controller signs out successfully', () async {
    final controller = MailCheckerController(
      signInAction: () async => const _FakeMailCheckerAccount(),
      loadInboxAction: (_) async => const <InboxEmail>[],
      signOutAction: () async {},
    );

    await controller.signIn();
    await controller.signOut();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(controller.statusMessage, 'Signed out. Sign in again to reload Gmail.');
  });

  test('controller reports Google sign-out failures', () async {
    final controller = MailCheckerController(
      signInAction: () async => const _FakeMailCheckerAccount(),
      loadInboxAction: (_) async => const <InboxEmail>[],
      signOutAction: () async => throw Exception('signout failed'),
    );

    await controller.signIn();
    await controller.signOut();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Google sign-out failed. Try again.',
    );
    expect(controller.errorMessage, contains('signout failed'));
  });
}

class _FakeMailCheckerAccount implements MailCheckerAccount {
  const _FakeMailCheckerAccount();

  @override
  Future<Map<String, String>> get authHeaders async => const {};
}
