import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import 'package:mail_checker_app/main.dart';

void main() {
  testWidgets('shows Google Sign-In entry screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Mail Checker'), findsOneWidget);
    expect(
      find.text('Sign in with Google to load your Gmail inbox.'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(
      find.text(
        'Optional: pass --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id> only if your Google Sign-In setup requires a web OAuth client ID.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows signed-in actions and inbox preview', (
    WidgetTester tester,
  ) async {
    final controller = MailCheckerController(
      googleSignInFactory: () =>
          const _FakeSignInClient(account: _FakeMailCheckerAccount()),
      loadInboxAction: (_) async => const [
        InboxEmail(
          subject: 'Subject',
          from: 'sender@example.com',
          snippet: 'Preview',
        ),
      ],
    );

    await controller.signIn();
    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('Refresh inbox'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Inbox Preview'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
  });

  test('controller reports cancelled sign-in', () async {
    final controller = MailCheckerController(
      googleSignInFactory: () => const _FakeSignInClient(),
    );

    await controller.signIn();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(controller.statusMessage, 'Google Sign-In was cancelled.');
  });

  test('controller reports sign-in errors', () async {
    final controller = MailCheckerController(
      googleSignInFactory: () =>
          const _FakeSignInClient(signInError: 'signin failed'),
    );

    await controller.signIn();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(controller.statusMessage, 'Google Sign-In failed.');
    expect(controller.errorMessage, contains('signin failed'));
    expect(controller.errorMessage, contains('README.md'));
  });

  test('controller reports an empty inbox after sign-in', () async {
    final controller = MailCheckerController(
      googleSignInFactory: () =>
          const _FakeSignInClient(account: _FakeMailCheckerAccount()),
      loadInboxAction: (_) async => const <InboxEmail>[],
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Signed in successfully, but the inbox preview is empty.',
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
      googleSignInFactory: () =>
          const _FakeSignInClient(account: _FakeMailCheckerAccount()),
      loadInboxAction: (_) async => emails,
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, emails);
    expect(controller.statusMessage, 'Loaded 1 Gmail preview messages.');
  });

  test('controller default Gmail loader lists ids and parses message metadata', () async {
    final gmailApi = _FakeGmailApi(
      messages: <gmail.Message>[
        gmail.Message()..id = 'message-1',
        gmail.Message(),
        gmail.Message()..id = 'message-2',
      ],
      messagesById: <String, gmail.Message>{
        'message-1': _gmailMessage(
          fromHeaderName: 'from',
          from: 'sender@example.com',
          subjectHeaderName: 'subject',
          subject: 'Subject',
          snippet: 'Preview',
        ),
        'message-2': _gmailMessage(subject: 'Subject only'),
      },
    );
    final controller = MailCheckerController(
      googleSignInFactory: () =>
          const _FakeSignInClient(account: _FakeMailCheckerAccount()),
      gmailApiFactory: (_) => gmailApi,
    );

    await controller.signIn();

    expect(controller.isSignedIn, isTrue);
    expect(controller.emails, const <InboxEmail>[
      InboxEmail(
        subject: 'Subject',
        from: 'sender@example.com',
        snippet: 'Preview',
      ),
      InboxEmail(
        subject: 'Subject only',
        from: '(Unknown sender)',
        snippet: '',
      ),
    ]);
    expect(controller.statusMessage, 'Loaded 2 Gmail preview messages.');
    expect(gmailApi.requestedMaxResults, 3);
    expect(gmailApi.loadedMessageIds, <String>['message-1', 'message-2']);
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
      googleSignInFactory: () =>
          const _FakeSignInClient(account: _FakeMailCheckerAccount()),
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
    final fakeClient = const _FakeSignInClient(
      account: _FakeMailCheckerAccount(),
    );
    final controller = MailCheckerController(
      googleSignInFactory: () => fakeClient,
      loadInboxAction: (_) async => const <InboxEmail>[],
    );

    await controller.signIn();
    await controller.signOut();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Signed out. Sign in again to reload Gmail.',
    );
  });

  test('controller ignores sign-out while already signed out', () async {
    final controller = MailCheckerController(
      googleSignInFactory: () =>
          const _FakeSignInClient(signOutError: 'should not run'),
    );

    await controller.signOut();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(
      controller.statusMessage,
      'Complete the Google Cloud setup in README.md, then sign in.',
    );
    expect(controller.errorMessage, isNull);
  });

  test('controller reports Google sign-out failures', () async {
    final fakeClient = const _FakeSignInClient(
      account: _FakeMailCheckerAccount(),
      signOutError: 'signout failed',
    );
    final controller = MailCheckerController(
      googleSignInFactory: () => fakeClient,
      loadInboxAction: (_) async => const <InboxEmail>[],
    );

    await controller.signIn();
    await controller.signOut();

    expect(controller.isSignedIn, isFalse);
    expect(controller.isBusy, isFalse);
    expect(controller.emails, isEmpty);
    expect(
      controller.statusMessage,
      'Signed out locally, but Google sign-out failed.',
    );
    expect(controller.errorMessage, contains('signout failed'));
  });

  test('controller recreates the sign-in client after sign-out failure', () async {
    var factoryCalls = 0;
    final controller = MailCheckerController(
      googleSignInFactory: () {
        factoryCalls += 1;
        return _FakeSignInClient(
          account: const _FakeMailCheckerAccount(),
          signOutError: factoryCalls == 1 ? 'signout failed' : null,
        );
      },
      loadInboxAction: (_) async => const <InboxEmail>[],
    );

    await controller.signIn();
    await controller.signOut();
    await controller.signIn();

    expect(factoryCalls, 2);
    expect(controller.isSignedIn, isTrue);
    expect(controller.errorMessage, isNull);
  });
}

class _FakeMailCheckerAccount implements MailCheckerAccount {
  const _FakeMailCheckerAccount();

  @override
  Future<Map<String, String>> get authHeaders async => const {};
}

class _FakeSignInClient implements MailCheckerSignInClient {
  const _FakeSignInClient({
    this.account,
    this.signInError,
    this.signOutError,
  });

  final MailCheckerAccount? account;
  final String? signInError;
  final String? signOutError;

  @override
  Future<MailCheckerAccount?> signIn() async {
    if (signInError != null) {
      throw Exception(signInError);
    }
    return account;
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) {
      throw Exception(signOutError);
    }
  }
}

class _FakeGmailApi implements MailCheckerGmailApi {
  _FakeGmailApi({
    required List<gmail.Message> messages,
    required this.messagesById,
  }) : listResponse = gmail.ListMessagesResponse()..messages = messages;

  final gmail.ListMessagesResponse listResponse;
  final Map<String, gmail.Message> messagesById;
  final List<String> loadedMessageIds = <String>[];
  int? requestedMaxResults;

  @override
  Future<gmail.Message> getMessage(String id) async {
    loadedMessageIds.add(id);
    return messagesById[id] ?? (throw ArgumentError.value(id, 'id'));
  }

  @override
  Future<gmail.ListMessagesResponse> listInboxMessages({
    required int maxResults,
  }) async {
    requestedMaxResults = maxResults;
    return listResponse;
  }
}

gmail.Message _gmailMessage({
  String fromHeaderName = 'From',
  String? from,
  String subjectHeaderName = 'Subject',
  String? subject,
  String? snippet,
}) {
  final headers = <gmail.MessagePartHeader>[
    if (from != null)
      gmail.MessagePartHeader()
        ..name = fromHeaderName
        ..value = from,
    if (subject != null)
      gmail.MessagePartHeader()
        ..name = subjectHeaderName
        ..value = subject,
  ];

  return gmail.Message()
    ..snippet = snippet
    ..payload = (gmail.MessagePart()..headers = headers);
}
