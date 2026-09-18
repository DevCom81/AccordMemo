/// Stockage de secrets hors SQLite. N’y placer aucun identifiant OAuth desktop.
abstract interface class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
