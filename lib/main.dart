import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;

const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

typedef SignInAction = Future<Object?> Function();
typedef SignOutAction = Future<void> Function();
typedef LoadInboxAction = Future<List<InboxEmail>> Function(Object account);

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key, MailCheckerController? controller})
      : controller = controller ?? MailCheckerController();

  final MailCheckerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail Checker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: MailCheckerHomePage(controller: controller),
    );
  }
}

class MailCheckerHomePage extends StatelessWidget {
  const MailCheckerHomePage({super.key, required this.controller});

  final MailCheckerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Mail Checker'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Sign in with Google to load your Gmail inbox.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                controller.configurationSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: controller.isBusy ? null : controller.signIn,
                    icon: const Icon(Icons.login),
                    label: Text(
                      controller.isSignedIn
                          ? 'Refresh inbox'
                          : 'Sign in with Google',
                    ),
                  ),
                  if (controller.isSignedIn)
                    OutlinedButton(
                      onPressed: controller.isBusy ? null : controller.signOut,
                      child: const Text('Sign out'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (controller.isBusy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              Text(controller.statusMessage),
              if (controller.errorMessage case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (controller.emails.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Inbox',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final email in controller.emails)
                  Card(
                    child: ListTile(
                      title: Text(email.subject),
                      subtitle: Text('${email.from}\n${email.snippet}'),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class MailCheckerController extends ChangeNotifier {
  MailCheckerController({
    GoogleSignIn? googleSignIn,
    SignInAction? signInAction,
    SignOutAction? signOutAction,
    LoadInboxAction? loadInboxAction,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: <String>[gmail.GmailApi.gmailReadonlyScope],
              serverClientId:
                  _serverClientId.isEmpty ? null : _serverClientId,
            ),
        _signInAction = signInAction,
        _signOutAction = signOutAction,
        _loadInboxAction = loadInboxAction;

  final GoogleSignIn _googleSignIn;
  final SignInAction? _signInAction;
  final SignOutAction? _signOutAction;
  final LoadInboxAction? _loadInboxAction;

  bool _isBusy = false;
  String _statusMessage =
      'Complete the Google Cloud setup in README.md, then sign in.';
  String? _errorMessage;
  List<InboxEmail> _emails = const <InboxEmail>[];
  Object? _account;

  bool get isBusy => _isBusy;
  bool get isSignedIn => _account != null;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  List<InboxEmail> get emails => _emails;
  String get configurationSummary => _serverClientId.isEmpty
      ? 'Optional: pass --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id> '
          'after you create your OAuth web client.'
      : 'Using the Google server client ID provided through dart-define.';

  Future<void> signIn() async {
    _setBusy(true);
    _statusMessage = 'Opening Google Sign-In…';
    _errorMessage = null;
    notifyListeners();

    try {
      final account = await (_signInAction?.call() ?? _googleSignIn.signIn());
      if (account == null) {
        _account = null;
        _emails = const <InboxEmail>[];
        _statusMessage = 'Google Sign-In was cancelled.';
        return;
      }

      _account = account;
      _statusMessage = 'Loading Gmail inbox…';
      notifyListeners();

      _emails = await (_loadInboxAction?.call(account) ?? _loadInbox(account));
      _statusMessage = _emails.isEmpty
          ? 'Signed in successfully, but the inbox is empty.'
          : 'Loaded ${_emails.length} Gmail messages.';
    } catch (error) {
      _emails = const <InboxEmail>[];
      _errorMessage =
          '$error\n\nVerify the package name, SHA-1 fingerprint, Gmail API, '
          'and OAuth clients described in README.md.';
      _statusMessage = 'Google Sign-In or Gmail loading failed.';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    _errorMessage = null;
    notifyListeners();

    try {
      await (_signOutAction?.call() ?? _googleSignIn.signOut());
      _account = null;
      _emails = const <InboxEmail>[];
      _statusMessage = 'Signed out. Sign in again to reload Gmail.';
    } catch (error) {
      _errorMessage = '$error';
      _statusMessage = 'Sign-out failed.';
    } finally {
      _setBusy(false);
    }
  }

  Future<List<InboxEmail>> _loadInbox(Object account) async {
    final googleAccount = account as GoogleSignInAccount;
    final authHeaders = await googleAccount.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    try {
      final api = gmail.GmailApi(client);
      final response = await api.users.messages.list('me', maxResults: 10);
      final emails = <InboxEmail>[];
      for (final message in response.messages ?? const <gmail.Message>[]) {
        final id = message.id;
        if (id == null) {
          continue;
        }
        emails.add(await _loadMessage(api, id));
      }
      return emails;
    } finally {
      client.close();
    }
  }

  Future<InboxEmail> _loadMessage(gmail.GmailApi api, String id) async {
    final message = await api.users.messages.get(
      'me',
      id,
      format: 'metadata',
      metadataHeaders: <String>['From', 'Subject'],
    );
    final headers = <String, String>{
      for (final header
          in message.payload?.headers ?? const <gmail.MessagePartHeader>[])
        if (header.name != null && header.value != null)
          header.name!: header.value!,
    };
    return InboxEmail(
      subject: headers['Subject'] ?? '(No subject)',
      from: headers['From'] ?? '(Unknown sender)',
      snippet: message.snippet ?? '',
    );
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}

class InboxEmail {
  const InboxEmail({
    required this.subject,
    required this.from,
    required this.snippet,
  });

  final String subject;
  final String from;
  final String snippet;
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
