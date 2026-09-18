abstract interface class FileLocationPicker {
  Future<String?> pickSaveLocation({required String suggestedFileName});

  Future<String?> pickOpenLocation();
}
