import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;

// This stays optional for the current Android sign-in flow. Only provide it
// when your Google Cloud setup specifically requires a web OAuth client ID.
const _defaultServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
);
// Keep the preview fixed at three messages for now; at this size, fetching the
// per-message metadata concurrently keeps the code simple without meaningful
// Gmail API overhead.
const _inboxPreviewLimit = 3;
const _signedOutPrompt = 'Complete the Google Cloud setup in README.md, then sign in.';

typedef LoadInboxAction = Future<List<InboxEmail>> Function(
  MailCheckerAccount account,
);
typedef GoogleSignInFactory = MailCheckerSignInClient Function();
typedef GmailApiFactory = MailCheckerGmailApi Function(http.Client client);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.controller});

  final MailCheckerController? controller;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final MailCheckerController _controller =
      widget.controller ?? MailCheckerController();

  bool get _ownsController => widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail Checker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: MailCheckerHomePage(controller: _controller),
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
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (controller.emails.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Inbox Preview',
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

abstract interface class MailCheckerAccount {
  Future<Map<String, String>> get authHeaders;
}

abstract interface class MailCheckerSignInClient {
  Future<MailCheckerAccount?> signIn();

  Future<void> signOut();
}

abstract interface class MailCheckerGmailApi {
  Future<gmail.ListMessagesResponse> listInboxMessages({
    required int maxResults,
  });

  Future<gmail.Message> getMessage(String id);
}

class GoogleMailCheckerAccount implements MailCheckerAccount {
  GoogleMailCheckerAccount(this._account);

  final GoogleSignInAccount _account;

  @override
  Future<Map<String, String>> get authHeaders => _account.authHeaders;
}

class GoogleMailCheckerSignInClient implements MailCheckerSignInClient {
  GoogleMailCheckerSignInClient({required String serverClientId})
      : _googleSignIn = GoogleSignIn(
          scopes: <String>[gmail.GmailApi.gmailReadonlyScope],
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
        );

  final GoogleSignIn _googleSignIn;

  @override
  Future<MailCheckerAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      return null;
    }
    return GoogleMailCheckerAccount(account);
  }

  @override
  Future<void> signOut() {
    return _googleSignIn.signOut();
  }
}

class GoogleMailCheckerGmailApi implements MailCheckerGmailApi {
  GoogleMailCheckerGmailApi(http.Client client)
    : _api = gmail.GmailApi(client);

  final gmail.GmailApi _api;

  @override
  Future<gmail.ListMessagesResponse> listInboxMessages({
    required int maxResults,
  }) {
    return _api.users.messages.list('me', maxResults: maxResults);
  }

  @override
  Future<gmail.Message> getMessage(String id) {
    return _api.users.messages.get(
      'me',
      id,
      format: 'metadata',
      metadataHeaders: <String>['From', 'Subject'],
    );
  }
}

class MailCheckerController extends ChangeNotifier {
  MailCheckerController({
    LoadInboxAction? loadInboxAction,
    GoogleSignInFactory? googleSignInFactory,
    GmailApiFactory? gmailApiFactory,
    String serverClientId = _defaultServerClientId,
  })  : _loadInboxAction = loadInboxAction,
        _serverClientId = serverClientId,
        _googleSignInFactory = googleSignInFactory ??
            (() => GoogleMailCheckerSignInClient(
                  serverClientId: serverClientId,
                )),
        _gmailApiFactory =
            gmailApiFactory ??
            ((client) => GoogleMailCheckerGmailApi(client));

  final LoadInboxAction? _loadInboxAction;
  final GoogleSignInFactory _googleSignInFactory;
  final GmailApiFactory _gmailApiFactory;
  final String _serverClientId;

  MailCheckerSignInClient? _signInClient;
  bool _isDisposed = false;
  bool _isBusy = false;
  String _statusMessage = _signedOutPrompt;
  String? _errorMessage;
  List<InboxEmail> _emails = const <InboxEmail>[];
  MailCheckerAccount? _account;

  bool get isBusy => _isBusy;
  bool get isSignedIn => _account != null;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  List<InboxEmail> get emails => _emails;
  String get configurationSummary => _serverClientId.isEmpty
      ? 'Optional: pass --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id> '
          'only if your Google Sign-In setup requires a web OAuth client ID.'
      : 'Using a configured optional Google server client ID.';

  MailCheckerSignInClient get _client =>
      _signInClient ??= _googleSignInFactory();

  Future<void> signIn() async {
    if (_isDisposed || _isBusy) {
      return;
    }

    if (_account != null) {
      await _refreshInbox(_account!);
      return;
    }

    _isBusy = true;
    _statusMessage = 'Opening Google Sign-In…';
    _errorMessage = null;
    _notifyListeners();
    if (_isDisposed) {
      return;
    }

    MailCheckerAccount? account;
    try {
      account = await _client.signIn();
    } catch (error) {
      _account = null;
      _emails = const <InboxEmail>[];
      _errorMessage =
          '$error\n\nVerify the package name, SHA-1 fingerprint, Gmail API, '
          'and OAuth clients described in README.md.';
      _statusMessage = 'Google Sign-In failed.';
      _isBusy = false;
      _notifyListeners();
      return;
    }

    if (account == null) {
      _account = null;
      _emails = const <InboxEmail>[];
      _statusMessage = 'Google Sign-In was cancelled.';
      _isBusy = false;
      _notifyListeners();
      return;
    }

    _account = account;
    await _refreshInbox(account);
  }

  Future<void> signOut() async {
    if (_isDisposed || _isBusy) {
      return;
    }
    if (_account == null) {
      final hadError = _errorMessage != null;
      final hadEmails = _emails.isNotEmpty;
      final hadCustomStatus = _statusMessage != _signedOutPrompt;
      _errorMessage = null;
      _emails = const <InboxEmail>[];
      _statusMessage = _signedOutPrompt;
      if (hadError || hadEmails || hadCustomStatus) {
        _notifyListeners();
      }
      return;
    }

    _isBusy = true;
    _errorMessage = null;
    _statusMessage = 'Signing out…';
    _notifyListeners();
    if (_isDisposed) {
      return;
    }

    Object? signOutError;
    try {
      await _client.signOut();
    } catch (error) {
      signOutError = error;
    }
    if (_isDisposed) {
      return;
    }

    _account = null;
    _emails = const <InboxEmail>[];
    _signInClient = null;
    if (signOutError == null) {
      _statusMessage = 'Signed out. Sign in again to reload Gmail.';
    } else {
      _errorMessage = '$signOutError';
      _statusMessage = 'Signed out locally, but Google sign-out failed.';
    }
    _isBusy = false;
    _notifyListeners();
  }

  Future<void> _refreshInbox(MailCheckerAccount account) async {
    if (_isDisposed) {
      return;
    }

    _isBusy = true;
    _errorMessage = null;
    _statusMessage = 'Loading Gmail inbox…';
    _notifyListeners();

    try {
      final emails = await (_loadInboxAction?.call(account) ?? _loadInbox(account));
      if (_isDisposed) {
        return;
      }
      _emails = emails;
      _statusMessage = emails.isEmpty
          ? 'Signed in successfully, but the inbox preview is empty.'
          : 'Loaded ${emails.length} Gmail preview messages.';
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _emails = const <InboxEmail>[];
      _errorMessage =
          '$error\n\nVerify the package name, SHA-1 fingerprint, Gmail API, '
          'and OAuth clients described in README.md.';
      _statusMessage = 'Signed in, but Gmail loading failed.';
    }

    _isBusy = false;
    _notifyListeners();
  }

  Future<List<InboxEmail>> _loadInbox(MailCheckerAccount account) async {
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    try {
      final api = _gmailApiFactory(client);
      final response = await api.listInboxMessages(
        maxResults: _inboxPreviewLimit,
      );
      final messageIds = [
        for (final message in response.messages ?? const <gmail.Message>[])
          if (message.id != null) message.id!,
      ];
      return await Future.wait(
        messageIds.map((id) => _loadMessage(api, id)),
        eagerError: false,
      );
    } finally {
      client.close();
    }
  }

  Future<InboxEmail> _loadMessage(MailCheckerGmailApi api, String id) async {
    final message = await api.getMessage(id);
    return _toInboxEmail(message);
  }

  InboxEmail _toInboxEmail(gmail.Message message) {
    String? from;
    String? subject;
    for (final header
        in message.payload?.headers ?? const <gmail.MessagePartHeader>[]) {
      final headerName = header.name?.toLowerCase();
      final headerValue = header.value;
      if (headerName == null || headerValue == null) {
        continue;
      }
      if (headerName == 'from' && from == null) {
        from = headerValue;
      }
      if (headerName == 'subject' && subject == null) {
        subject = headerValue;
      }
    }
    return InboxEmail(
      subject: subject ?? '(No subject)',
      from: from ?? '(Unknown sender)',
      snippet: message.snippet ?? '',
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}

@immutable
class InboxEmail {
  const InboxEmail({
    required this.subject,
    required this.from,
    required this.snippet,
  });

  final String subject;
  final String from;
  final String snippet;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InboxEmail &&
            subject == other.subject &&
            from == other.from &&
            snippet == other.snippet;
  }

  @override
  int get hashCode => Object.hash(subject, from, snippet);
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    for (final entry in _headers.entries) {
      if (_isAuthHeader(entry.key) || !request.headers.containsKey(entry.key)) {
        request.headers[entry.key] = entry.value;
      }
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  bool _isAuthHeader(String headerName) {
    final normalized = headerName.toLowerCase();
    return normalized == 'authorization' || normalized.startsWith('x-goog-');
  }
}
