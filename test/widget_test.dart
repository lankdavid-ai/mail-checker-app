// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

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

  testWidgets('shows signed-in empty inbox state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const TestApp(
        child: MailCheckerHomePage(
          isSignedIn: true,
          isLoading: false,
          displayName: 'Flutter Tester',
          emails: <MailMessageSummary>[],
          onRefresh: _noop,
          onSignIn: _noop,
          onSignOut: _noop,
        ),
      ),
    );

    expect(find.text('Signed in as Flutter Tester'), findsOneWidget);
    expect(find.text('No recent emails were found in your inbox.'), findsOneWidget);
  });

  testWidgets('shows fallback inbox title when display name is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: MailCheckerHomePage(
          isSignedIn: true,
          isLoading: false,
          emails: <MailMessageSummary>[],
          onRefresh: _noop,
          onSignIn: _noop,
          onSignOut: _noop,
        ),
      ),
    );

    expect(find.text('Recent inbox messages'), findsOneWidget);
  });

  testWidgets('shows signed-in Gmail access error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const TestApp(
        child: MailCheckerHomePage(
          isSignedIn: true,
          isLoading: false,
          displayName: 'Flutter Tester',
          emails: <MailMessageSummary>[],
          errorMessage: 'Unable to access Gmail right now.',
          onRefresh: _noop,
          onSignIn: _noop,
          onSignOut: _noop,
        ),
      ),
    );

    expect(find.text('Unable to access Gmail right now.'), findsOneWidget);
    expect(find.byTooltip('Refresh emails'), findsOneWidget);
  });

  testWidgets('shows loading indicator and disables signed-in actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: MailCheckerHomePage(
          isSignedIn: true,
          isLoading: true,
          displayName: 'Flutter Tester',
          emails: <MailMessageSummary>[],
          onRefresh: _noop,
          onSignIn: _noop,
          onSignOut: _noop,
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final IconButton logoutButton = tester.widget<IconButton>(
      find.byTooltip('Logout'),
    );
    final IconButton refreshButton = tester.widget<IconButton>(
      find.byTooltip('Refresh emails'),
    );

    expect(logoutButton.onPressed, isNull);
    expect(refreshButton.onPressed, isNull);
  });

  test('controller syncs silent sign-in state across initialize calls', () async {
    final FakeGoogleUserSession user = FakeGoogleUserSession(
      email: 'alice@example.com',
      displayName: 'Alice',
    );
    final FakeGoogleAuthProvider authProvider = FakeGoogleAuthProvider(
      silentUser: user,
    );
    final FakeGmailService gmailService = FakeGmailService(
      emails: const <MailMessageSummary>[
        MailMessageSummary(
          sender: 'team@example.com',
          subject: 'Hello',
          preview: 'Welcome to Gmail.',
        ),
      ],
    );
    final MailCheckerController controller = MailCheckerController(
      authProvider: authProvider,
      gmailService: gmailService,
    );

    await controller.initialize();
    expect(controller.isSignedIn, isTrue);
    expect(controller.currentUser?.email, 'alice@example.com');
    expect(controller.emails, hasLength(1));

    authProvider.silentUser = null;
    await controller.initialize();
    expect(controller.isSignedIn, isFalse);
    expect(controller.currentUser, isNull);
    expect(controller.emails, isEmpty);
  });

  test('controller clears existing session when sign-in is cancelled', () async {
    final FakeGoogleUserSession user = FakeGoogleUserSession(
      email: 'alice@example.com',
      displayName: 'Alice',
    );
    final FakeGoogleAuthProvider authProvider = FakeGoogleAuthProvider(
      signInUser: user,
    );
    final MailCheckerController controller = MailCheckerController(
      authProvider: authProvider,
      gmailService: FakeGmailService(
        emails: const <MailMessageSummary>[
          MailMessageSummary(
            sender: 'team@example.com',
            subject: 'Hello',
            preview: 'Welcome to Gmail.',
          ),
        ],
      ),
    );

    await controller.signIn();
    expect(controller.isSignedIn, isTrue);

    authProvider.signInUser = null;
    await controller.signIn();
    expect(controller.isSignedIn, isFalse);
    expect(controller.currentUser, isNull);
    expect(controller.emails, isEmpty);
  });

  test('controller keeps local session and shows generic error on sign-out failure', () async {
    final FakeGoogleAuthProvider authProvider = FakeGoogleAuthProvider(
      signInUser: FakeGoogleUserSession(
        email: 'alice@example.com',
        displayName: 'Alice',
      ),
    );
    final MailCheckerController controller = MailCheckerController(
      authProvider: authProvider,
      gmailService: FakeGmailService(
        emails: const <MailMessageSummary>[
          MailMessageSummary(
            sender: 'team@example.com',
            subject: 'Hello',
            preview: 'Welcome to Gmail.',
          ),
        ],
      ),
    );

    await controller.signIn();
    authProvider.throwOnSignOut = true;

    await controller.signOut();

    expect(controller.isSignedIn, isTrue);
    expect(controller.currentUser?.email, 'alice@example.com');
    expect(controller.emails, hasLength(1));
    expect(
      controller.errorMessage,
      'Unable to access Gmail right now. Please confirm Google Sign-In is configured for this app and try again.',
    );
  });

  test('GoogleSignInAuthProvider keeps Gmail readonly scope and delegates sign out', () async {
    final FakeGoogleSignInGateway gateway = FakeGoogleSignInGateway();
    final GoogleSignInAuthProvider provider = GoogleSignInAuthProvider(
      gateway: gateway,
    );

    expect(gateway.scopes, contains(gmail.GmailApi.gmailReadonlyScope));
    expect(await provider.signIn(), isNull);
    expect(await provider.signInSilently(), isNull);

    await provider.signOut();

    expect(gateway.signOutCalls, 1);
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

class FakeGoogleAuthProvider implements GoogleAuthProvider {
  FakeGoogleAuthProvider({this.silentUser, this.signInUser});

  GoogleUserSession? silentUser;
  GoogleUserSession? signInUser;
  bool throwOnSignOut = false;

  @override
  Future<GoogleUserSession?> signIn() async => signInUser;

  @override
  Future<GoogleUserSession?> signInSilently() async => silentUser;

  @override
  Future<void> signOut() async {
    if (throwOnSignOut) {
      throw Exception('sign out failed');
    }
  }
}

class FakeGoogleUserSession implements GoogleUserSession {
  FakeGoogleUserSession({
    required this.email,
    this.displayName,
    this.headers = const <String, String>{'Authorization': '******'},
  });

  @override
  final String? displayName;

  @override
  final String email;

  final Map<String, String> headers;

  @override
  Future<Map<String, String>> get authHeaders async => headers;
}

class FakeGmailService extends GmailService {
  FakeGmailService({required this.emails});

  final List<MailMessageSummary> emails;

  @override
  Future<List<MailMessageSummary>> fetchRecentEmails(
    GoogleUserSession account,
  ) async {
    return emails;
  }
}

class FakeGoogleSignInGateway implements GoogleSignInGateway {
  @override
  final List<String> scopes = FlutterGoogleSignInGateway.defaultScopes;

  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signIn() async => null;

  @override
  Future<GoogleSignInAccount?> signInSilently() async => null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
