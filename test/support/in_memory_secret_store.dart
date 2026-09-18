import 'dart:convert';

import 'package:accord_memo/application/ports/secret_store.dart';

final class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  String toString() => jsonEncode(values.keys.toList());
}
