/// Un document sélectionné, présenté au service comme un fichier local.
/// L'adaptateur conserve la responsabilité du transfert et du nettoyage.
abstract interface class BackupFileAccess {
  Future<BackupFileSelection?> selectSave({required String suggestedFileName});
  Future<BackupFileSelection?> selectOpen();
}

abstract interface class BackupFileSelection {
  /// Fichier privé de travail, utilisable par les outils de sauvegarde existants.
  String get localPath;

  /// Publie l'export terminé vers le document choisi. Ne s'appelle pas à l'import.
  Future<void> commit();

  /// Libère la copie privée, sans supprimer le document source ou l'export réussi.
  Future<void> dispose();
}
