import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MailCheckerScreen(controller: controller),
    );
  }
}

class MailCheckerScreen extends StatefulWidget {
  const MailCheckerScreen({super.key, required this.controller});

  final MailCheckerController controller;

  @override
  State<MailCheckerScreen> createState() => _MailCheckerScreenState();
}

class _MailCheckerScreenState extends State<MailCheckerScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MailCheckerHomePage(
          displayName:
              widget.controller.currentUser?.displayName ??
              widget.controller.currentUser?.email,
          emails: widget.controller.emails,
          errorMessage: widget.controller.errorMessage,
          isLoading: widget.controller.isLoading,
          isSignedIn: widget.controller.isSignedIn,
          onRefresh: widget.controller.refreshEmails,
          onSignIn: widget.controller.signIn,
          onSignOut: widget.controller.signOut,
        );
      },
    );
  }
}

class MailCheckerHomePage extends StatelessWidget {
  const MailCheckerHomePage({
    super.key,
    required this.isSignedIn,
    required this.isLoading,
    required this.emails,
    required this.onSignIn,
    required this.onSignOut,
    required this.onRefresh,
    this.displayName,
    this.errorMessage,
  });

  final String? displayName;
  final List<MailMessageSummary> emails;
  final String? errorMessage;
  final bool isLoading;
  final bool isSignedIn;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Mail Checker'),
        actions: [
          if (isSignedIn)
            IconButton(
              onPressed: isLoading ? null : () => unawaited(onSignOut()),
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isLoading) const LinearProgressIndicator(),
            Expanded(
              child: isSignedIn
                  ? _InboxView(
                      displayName: displayName,
                      emails: emails,
                      errorMessage: errorMessage,
                      isLoading: isLoading,
                      onRefresh: onRefresh,
                    )
                  : _SignedOutView(
                      errorMessage: errorMessage,
                      isLoading: isLoading,
                      onSignIn: onSignIn,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({
    required this.errorMessage,
    required this.isLoading,
    required this.onSignIn,
  });

  final String? errorMessage;
  final bool isLoading;
  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mail_outline, size: 72),
            const SizedBox(height: 16),
            Text(
              'Sign in with Google to load recent emails from your Gmail inbox.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isLoading ? null : () => unawaited(onSignIn()),
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxView extends StatelessWidget {
  const _InboxView({
    required this.displayName,
    required this.emails,
    required this.errorMessage,
    required this.isLoading,
    required this.onRefresh,
  });

  final String? displayName;
  final List<MailMessageSummary> emails;
  final String? errorMessage;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayName == null
                      ? 'Recent inbox messages'
                      : 'Signed in as $displayName',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : () => unawaited(onRefresh()),
                tooltip: 'Refresh emails',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: emails.isEmpty
              ? const Center(
                  child: Text('No recent emails were found in your inbox.'),
                )
              : ListView.separated(
                  itemCount: emails.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final email = emails[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.mail)),
                      title: Text(
                        email.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            email.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class MailCheckerController extends ChangeNotifier {
  MailCheckerController({
    GoogleAuthProvider? authProvider,
    GmailService? gmailService,
  }) : _authProvider = authProvider ?? GoogleSignInAuthProvider(),
       _gmailService = gmailService ?? const GmailService();

  final GoogleAuthProvider _authProvider;
  final GmailService _gmailService;

  List<MailMessageSummary> _emails = const [];
  String? _errorMessage;
  bool _isLoading = false;
  GoogleUserSession? _currentUser;

  List<MailMessageSummary> get emails => List.unmodifiable(_emails);
  String? get errorMessage => _errorMessage;
  GoogleUserSession? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final GoogleUserSession? account = await _authProvider.signInSilently();
      if (account == null) {
        _clearSession();
      } else {
        _currentUser = account;
        _emails = const [];

        try {
          await _loadEmailsFor(account);
        } catch (error, stackTrace) {
          _logError(
            'Loading Gmail messages after silent sign-in failed',
            error,
            stackTrace,
          );
          _errorMessage = _friendlyError();
        }
      }
    } catch (error, stackTrace) {
      _logError('Silent Google sign-in failed', error, stackTrace);
      _clearSession();
      _errorMessage = _friendlyError();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleUserSession? account = await _authProvider.signIn();
      if (account != null) {
        _currentUser = account;
        _emails = const [];
        await _loadEmailsFor(account);
      } else {
        _clearSession();
      }
    } catch (error, stackTrace) {
      _logError('Google sign-in failed', error, stackTrace);
      _errorMessage = _friendlyError();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshEmails() async {
    final GoogleUserSession? account = _currentUser;
    if (account == null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadEmailsFor(account);
    } catch (error, stackTrace) {
      _logError('Refreshing Gmail messages failed', error, stackTrace);
      _errorMessage = _friendlyError();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    String? errorMessage;

    try {
      await _authProvider.signOut();
    } catch (error, stackTrace) {
      _logError('Google sign-out failed', error, stackTrace);
      errorMessage = _friendlyError();
    } finally {
      _clearSession();
      _errorMessage = errorMessage;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEmailsFor(GoogleUserSession account) async {
    _emails = await _gmailService.fetchRecentEmails(account);
    _errorMessage = null;
  }

  void _clearSession() {
    _currentUser = null;
    _emails = const [];
    _errorMessage = null;
  }

  static String _friendlyError() {
    return 'Unable to access Gmail right now. Please confirm Google Sign-In is configured for this app and try again.';
  }

  static void _logError(String context, Object error, StackTrace stackTrace) {
    debugPrint('$context: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class GmailService {
  const GmailService();

  Future<List<MailMessageSummary>> fetchRecentEmails(
    GoogleUserSession account,
  ) async {
    final _GoogleAuthClient client = _GoogleAuthClient(await account.authHeaders);

    try {
      final gmail.GmailApi gmailApi = gmail.GmailApi(client);
      final gmail.ListMessagesResponse response = await gmailApi.users.messages
          .list(
            'me',
            labelIds: <String>['INBOX'],
            maxResults: 5,
          );

      final Iterable<String> messageIds = (response.messages ?? const <gmail.Message>[])
          .map((gmail.Message reference) => reference.id)
          .whereType<String>();
      final List<gmail.Message> messages = await Future.wait(
        messageIds.map(
          (String id) => gmailApi.users.messages.get(
            'me',
            id,
            format: 'metadata',
            metadataHeaders: <String>['From', 'Subject'],
          ),
        ),
      );

      return messages.map(_toSummary).toList(growable: false);
    } finally {
      client.close();
    }
  }

  static MailMessageSummary _toSummary(gmail.Message message) {
    final String sender = _headerValue(message, 'From') ?? 'Unknown sender';
    final String subject = _headerValue(message, 'Subject') ?? 'No subject';
    final String preview = switch (message.snippet?.trim()) {
      final String snippet when snippet.isNotEmpty => snippet,
      _ => 'No preview available',
    };

    return MailMessageSummary(
      sender: sender,
      subject: subject,
      preview: preview,
    );
  }

  static String? _headerValue(gmail.Message message, String name) {
    for (final gmail.MessagePartHeader header in message.payload?.headers ?? const []) {
      if (header.name?.toLowerCase() == name.toLowerCase()) {
        return header.value;
      }
    }
    return null;
  }
}

class MailMessageSummary {
  const MailMessageSummary({
    required this.sender,
    required this.subject,
    required this.preview,
  });

  final String sender;
  final String subject;
  final String preview;
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}

abstract class GoogleAuthProvider {
  Future<GoogleUserSession?> signIn();
  Future<GoogleUserSession?> signInSilently();
  Future<void> signOut();
}

abstract class GoogleUserSession {
  String? get displayName;
  String get email;
  Future<Map<String, String>> get authHeaders;
}

class GoogleSignInAuthProvider implements GoogleAuthProvider {
  GoogleSignInAuthProvider({GoogleSignInGateway? gateway})
    : _gateway = gateway ?? FlutterGoogleSignInGateway();

  final GoogleSignInGateway _gateway;

  @override
  Future<GoogleUserSession?> signIn() async {
    final GoogleSignInAccount? account = await _gateway.signIn();
    if (account == null) {
      return null;
    }
    return GoogleSignInSession(account);
  }

  @override
  Future<GoogleUserSession?> signInSilently() async {
    final GoogleSignInAccount? account = await _gateway.signInSilently();
    if (account == null) {
      return null;
    }
    return GoogleSignInSession(account);
  }

  @override
  Future<void> signOut() async {
    await _gateway.signOut();
  }
}

class GoogleSignInSession implements GoogleUserSession {
  GoogleSignInSession(this._account);

  final GoogleSignInAccount _account;

  @override
  Future<Map<String, String>> get authHeaders => _account.authHeaders;

  @override
  String? get displayName => _account.displayName;

  @override
  String get email => _account.email;
}

abstract class GoogleSignInGateway {
  Future<GoogleSignInAccount?> signIn();
  Future<GoogleSignInAccount?> signInSilently();
  Future<void> signOut();
}

class FlutterGoogleSignInGateway implements GoogleSignInGateway {
  FlutterGoogleSignInGateway({
    GoogleSignIn? googleSignIn,
    List<String> scopes = defaultScopes,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: scopes),
       scopes = List.unmodifiable(scopes);

  static const List<String> defaultScopes = <String>[
    gmail.GmailApi.gmailReadonlyScope,
  ];

  final GoogleSignIn _googleSignIn;

  final List<String> scopes;

  @override
  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  @override
  Future<GoogleSignInAccount?> signInSilently() => _googleSignIn.signInSilently();

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
