import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infrastructure/persistence/sqlite_database_path.dart';
import 'presentation/app_database_holder.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final location = await SqliteDatabasePath.forCurrentPlatform();
  runApp(
    ProviderScope(
      overrides: [
        sqliteDatabasePathProvider.overrideWith((ref) => location),
      ],
      child: const AccordMemoApp(),
    ),
  );
}

class AccordMemoApp extends StatelessWidget {
  const AccordMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AccordMémo',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
