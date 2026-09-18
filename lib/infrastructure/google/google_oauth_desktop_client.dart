/// Identifiants OAuth Desktop (non confidentiels). Pas un secret utilisateur.
final class GoogleOAuthDesktopClient {
  const GoogleOAuthDesktopClient({
    required this.clientId,
    required this.clientSecret,
  });

  factory GoogleOAuthDesktopClient.fromEnvironment() {
    return const GoogleOAuthDesktopClient(
      clientId: String.fromEnvironment('ACCORD_MEMO_GOOGLE_OAUTH_CLIENT_ID'),
      clientSecret: String.fromEnvironment(
        'ACCORD_MEMO_GOOGLE_OAUTH_CLIENT_SECRET',
      ),
    );
  }

  final String clientId;
  final String clientSecret;

  bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}
