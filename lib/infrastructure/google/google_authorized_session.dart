import 'package:http/http.dart';

import '../../application/ports/google_auth_session.dart';

/// Contrat technique partagé par les sessions natives et le transport Gmail.
abstract interface class GoogleAuthorizedSession implements GoogleAuthSession {
  Future<String> senderAddress();
  Future<Client> authorizedClient();
}
