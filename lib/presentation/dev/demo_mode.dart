import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` uniquement via l'entrypoint `lib/main_demo.dart`.
final demoModeProvider = Provider<bool>((ref) => false);
